import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const claudeApiKey = Deno.env.get("ANTHROPIC_API_KEY") ?? "";

const DEFAULT_MODEL = "claude-sonnet-4-5-20250929";
const DEFAULT_MAX_TOKENS = 3072;
const MIN_MAX_TOKENS = 256;
const MAX_MAX_TOKENS = 4096;
const DEFAULT_TEMPERATURE = 0.2;
const MAX_PROMPT_CHARS = 40000;
const MAX_IMAGE_BYTES = 12 * 1024 * 1024;
const ANTHROPIC_TIMEOUT_MS = 90_000;
const ANTHROPIC_MAX_RETRIES = 2;

const claudeSystemPrompt = `
You are a clinical skin analysis assistant for licensed esthetic and medspa professionals.
Prioritize objective findings, avoid hallucinations, and keep recommendations conservative when uncertain.
Return only one valid JSON object and no extra text.
`.trim();

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

if (!supabaseUrl || !supabaseAnonKey || !claudeApiKey) {
  console.error("Missing SUPABASE_URL, SUPABASE_ANON_KEY, or ANTHROPIC_API_KEY.");
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  if (!supabaseUrl || !supabaseAnonKey || !claudeApiKey) {
    return jsonResponse({ error: "Server configuration error" }, 500);
  }

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const token = authHeader.replace("Bearer ", "").trim();
    if (!token) {
      return jsonResponse({ error: "Missing auth token" }, 401);
    }

    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: {
        headers: {
          Authorization: authHeader,
        },
      },
    });

    const { data: authData, error: authError } = await supabase.auth.getUser(token);
    const userId = authData?.user?.id;
    if (authError || !userId) {
      return jsonResponse(
        { error: "Invalid user token", details: authError?.message ?? "token validation failed" },
        401,
      );
    }

    const { data: profile, error: profileError } = await supabase
      .from("users")
      .select("company_id")
      .eq("id", userId)
      .single();

    if (profileError || !profile?.company_id) {
      return jsonResponse({ error: "User profile missing company" }, 400);
    }

    const rawBody = await req.json().catch(() => null);
    if (!rawBody || typeof rawBody !== "object") {
      return jsonResponse({ error: "Invalid request body" }, 400);
    }
    const body = rawBody as Record<string, unknown>;

    const imageBase64Raw = (typeof body.image_base64 === "string"
      ? body.image_base64
      : typeof body.imageBase64 === "string"
      ? body.imageBase64
      : "").trim();
    const imageBase64 = imageBase64Raw.replace(/\s+/g, "");
    const prompt = typeof body.prompt === "string" ? body.prompt.trim() : "";

    if (!imageBase64 || !prompt) {
      return jsonResponse({ error: "Missing image or prompt" }, 400);
    }
    if (prompt.length > MAX_PROMPT_CHARS) {
      return jsonResponse(
        { error: "Prompt too large", details: `Max prompt size is ${MAX_PROMPT_CHARS} characters.` },
        400,
      );
    }

    const imageBytes = base64DecodedByteLength(imageBase64);
    if (imageBytes > MAX_IMAGE_BYTES) {
      return jsonResponse(
        { error: "Image too large", details: `Max decoded image size is ${MAX_IMAGE_BYTES} bytes.` },
        413,
      );
    }

    const model = normalizeModel(body.model);
    const maxTokens = Math.round(clampNumber(
      body.max_tokens ?? body.maxTokens,
      MIN_MAX_TOKENS,
      MAX_MAX_TOKENS,
      DEFAULT_MAX_TOKENS,
    ));
    const temperature = clampNumber(body.temperature, 0, 1, DEFAULT_TEMPERATURE);

    const { data: usageData, error: usageError } = await supabase.rpc("record_claude_usage", {
      p_company_id: profile.company_id,
      p_user_id: userId,
    });

    if (usageError) {
      return jsonResponse({ error: "Usage check failed", details: usageError.message }, 400);
    }

    const usage = Array.isArray(usageData) ? usageData[0] : usageData;
    if (!usage?.allowed) {
      return jsonResponse({ error: "Claude usage limit reached", usage }, 402);
    }

    const claudeRequestBody = {
      model,
      max_tokens: maxTokens,
      temperature,
      system: claudeSystemPrompt,
      messages: [
        {
          role: "user",
          content: [
            {
              type: "image",
              source: {
                type: "base64",
                media_type: "image/jpeg",
                data: imageBase64,
              },
            },
            {
              type: "text",
              text: prompt,
            },
          ],
        },
      ],
    };

    const claudeResult = await callAnthropicWithRetry(claudeRequestBody);
    return new Response(claudeResult.bodyText, {
      status: claudeResult.status,
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  } catch (error) {
    const details = error instanceof Error ? error.message : String(error);
    return jsonResponse({ error: "Unexpected error", details }, 500);
  }
});

function jsonResponse(payload: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders },
  });
}

function normalizeModel(value: unknown): string {
  if (typeof value !== "string") return DEFAULT_MODEL;
  const candidate = value.trim();
  if (!candidate.startsWith("claude-")) return DEFAULT_MODEL;
  return candidate;
}

function clampNumber(value: unknown, min: number, max: number, fallback: number): number {
  const parsed = typeof value === "number"
    ? value
    : typeof value === "string"
    ? Number(value)
    : NaN;

  if (Number.isNaN(parsed)) return fallback;
  return Math.min(max, Math.max(min, parsed));
}

function base64DecodedByteLength(base64: string): number {
  const padding = (base64.match(/=*$/)?.[0].length ?? 0);
  return Math.floor((base64.length * 3) / 4) - padding;
}

async function callAnthropicWithRetry(
  requestBody: Record<string, unknown>,
): Promise<{ status: number; bodyText: string }> {
  let lastError: unknown = null;

  for (let attempt = 0; attempt <= ANTHROPIC_MAX_RETRIES; attempt++) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), ANTHROPIC_TIMEOUT_MS);

    try {
      const response = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": claudeApiKey,
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify(requestBody),
        signal: controller.signal,
      });
      const bodyText = await response.text();

      if (isRetriableStatus(response.status) && attempt < ANTHROPIC_MAX_RETRIES) {
        await wait(retryDelayMs(attempt));
        continue;
      }

      return { status: response.status, bodyText };
    } catch (error) {
      lastError = error;
      if (attempt < ANTHROPIC_MAX_RETRIES) {
        await wait(retryDelayMs(attempt));
        continue;
      }
      break;
    } finally {
      clearTimeout(timeout);
    }
  }

  const details = lastError instanceof Error ? lastError.message : String(lastError);
  return {
    status: 502,
    bodyText: JSON.stringify({
      error: "Anthropic request failed",
      details,
    }),
  };
}

function isRetriableStatus(status: number): boolean {
  return status === 429 || status >= 500;
}

function retryDelayMs(attempt: number): number {
  const base = 500 * Math.pow(2, attempt);
  const jitter = Math.floor(Math.random() * 250);
  return base + jitter;
}

function wait(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
