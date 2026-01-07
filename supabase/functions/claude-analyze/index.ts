import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const claudeApiKey = Deno.env.get("ANTHROPIC_API_KEY") ?? "";

if (!supabaseUrl || !supabaseAnonKey || !claudeApiKey) {
  console.error("Missing SUPABASE_URL, SUPABASE_ANON_KEY, or ANTHROPIC_API_KEY.");
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  }

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const token = authHeader.replace("Bearer ", "");
    if (!token) {
      return new Response(JSON.stringify({ error: "Missing auth token" }), {
        status: 401,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    const payload = decodeJwtPayload(token);
    if (!payload?.sub) {
      return new Response(
        JSON.stringify({ error: "Invalid user token", details: "missing sub claim" }),
        {
          status: 401,
          headers: { "Content-Type": "application/json", ...corsHeaders },
        },
      );
    }

    if (payload.exp && Date.now() / 1000 >= payload.exp) {
      return new Response(
        JSON.stringify({ error: "Invalid user token", details: "token expired" }),
        {
          status: 401,
          headers: { "Content-Type": "application/json", ...corsHeaders },
        },
      );
    }

    const userId = payload.sub as string;

    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: {
        headers: {
          Authorization: authHeader,
        },
      },
    });

    const { data: profile, error: profileError } = await supabase
      .from("users")
      .select("company_id")
      .eq("id", userId)
      .single();

    if (profileError || !profile?.company_id) {
      return new Response(JSON.stringify({ error: "User profile missing company" }), {
        status: 400,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    const body = await req.json();
    const imageBase64 = body.image_base64 ?? body.imageBase64;
    const prompt = body.prompt;
    const model = body.model ?? "claude-sonnet-4-5-20250929";

    if (!imageBase64 || !prompt) {
      return new Response(JSON.stringify({ error: "Missing image or prompt" }), {
        status: 400,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    const { data: usageData, error: usageError } = await supabase.rpc(
      "record_claude_usage",
      {
        p_company_id: profile.company_id,
        p_user_id: userId,
      },
    );

    if (usageError) {
      return new Response(JSON.stringify({ error: "Usage check failed", details: usageError.message }), {
        status: 400,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    const usage = Array.isArray(usageData) ? usageData[0] : usageData;
    if (!usage?.allowed) {
      return new Response(JSON.stringify({ error: "Claude usage limit reached", usage }), {
        status: 402,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    const claudeRequestBody = {
      model,
      max_tokens: 2048,
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

    const claudeResponse = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": claudeApiKey,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify(claudeRequestBody),
    });

    const claudeText = await claudeResponse.text();

    return new Response(claudeText, {
      status: claudeResponse.status,
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: "Unexpected error", details: String(error) }), {
      status: 500,
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  }
});

function decodeJwtPayload(token: string): Record<string, unknown> | null {
  const parts = token.split(".");
  if (parts.length < 2) {
    return null;
  }

  const payload = parts[1];
  try {
    const decoded = atob(payload.replace(/-/g, "+").replace(/_/g, "/"));
    return JSON.parse(decoded);
  } catch {
    return null;
  }
}
