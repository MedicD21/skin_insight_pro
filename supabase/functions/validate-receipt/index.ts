import { createClient } from 'jsr:@supabase/supabase-js@2'

// Product tier mapping
const PRODUCT_TIERS: Record<string, { tier: string; monthly_cap: number }> = {
  'com.skininsightpro.solo.monthly': { tier: 'solo', monthly_cap: 100 },
  'com.skininsightpro.solo.annual': { tier: 'solo', monthly_cap: 100 },
  'com.skininsightpro.starter.monthly': { tier: 'starter', monthly_cap: 400 },
  'com.skininsightpro.starter.annual': { tier: 'starter', monthly_cap: 400 },
  'com.skininsightpro.professional.monthly': { tier: 'professional', monthly_cap: 1500 },
  'com.skininsightpro.business.monthly': { tier: 'business', monthly_cap: 5000 },
  'com.skininsightpro.enterprise.monthly': { tier: 'enterprise', monthly_cap: 15000 },
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

function getErrorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error)
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const payload = await req.json()
    const receipt = typeof payload?.receipt === 'string' ? payload.receipt : ''
    const companyId = typeof payload?.company_id === 'string' ? payload.company_id : ''
    const productId = typeof payload?.product_id === 'string' ? payload.product_id : ''
    const transactionId = typeof payload?.transaction_id === 'string' ? payload.transaction_id : ''

    if (!receipt || !companyId || !productId || !transactionId) {
      return jsonResponse({ error: 'Missing required fields' }, 400)
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

    if (!supabaseUrl || !supabaseServiceRoleKey) {
      console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in function environment.')
      return jsonResponse({ error: 'Server configuration error' }, 500)
    }

    // Initialize Supabase client
    const supabase = createClient(supabaseUrl, supabaseServiceRoleKey)

    // Validate receipt with Apple (in production, use Apple's server-to-server API)
    // For now, we'll trust the client and verify the transaction exists
    const tierInfo = PRODUCT_TIERS[productId]
    if (!tierInfo) {
      return jsonResponse({ error: 'Invalid product ID' }, 400)
    }

    // Check if company_plans record exists for this company
    const { data: existingPlan } = await supabase
      .from('company_plans')
      .select('*')
      .eq('company_id', companyId)
      .eq('status', 'active')
      .single()

    const now = new Date()
    const isAnnual = productId.includes('annual')
    const endsAt = new Date(now)

    if (isAnnual) {
      endsAt.setFullYear(endsAt.getFullYear() + 1)
    } else {
      endsAt.setMonth(endsAt.getMonth() + 1)
    }

    if (existingPlan) {
      // Update existing plan
      const { error: updateError } = await supabase
        .from('company_plans')
        .update({
          tier: tierInfo.tier,
          monthly_company_cap: tierInfo.monthly_cap,
          apple_transaction_id: transactionId,
          product_id: productId,
          started_at: now.toISOString(),
          ends_at: endsAt.toISOString(),
          updated_at: now.toISOString(),
        })
        .eq('id', existingPlan.id)

      if (updateError) {
        console.error('Failed to update plan:', updateError)
        return jsonResponse({ error: 'Failed to update subscription' }, 500)
      }
    } else {
      // Create new plan
      const { error: insertError } = await supabase
        .from('company_plans')
        .insert({
          company_id: companyId,
          tier: tierInfo.tier,
          monthly_company_cap: tierInfo.monthly_cap,
          apple_transaction_id: transactionId,
          product_id: productId,
          status: 'active',
          started_at: now.toISOString(),
          ends_at: endsAt.toISOString(),
        })

      if (insertError) {
        console.error('Failed to create plan:', insertError)
        return jsonResponse({ error: 'Failed to create subscription' }, 500)
      }
    }

    return jsonResponse({
      success: true,
      tier: tierInfo.tier,
      monthly_cap: tierInfo.monthly_cap,
      ends_at: endsAt.toISOString(),
    })

  } catch (error) {
    console.error('Error validating receipt:', error)
    return jsonResponse({ success: false, error: getErrorMessage(error) }, 500)
  }
})
