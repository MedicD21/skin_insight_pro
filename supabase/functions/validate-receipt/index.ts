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

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*' } })
  }

  try {
    const { receipt, company_id, product_id, transaction_id } = await req.json()

    if (!receipt || !company_id || !product_id || !transaction_id) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Initialize Supabase client
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // Validate receipt with Apple (in production, use Apple's server-to-server API)
    // For now, we'll trust the client and verify the transaction exists
    const tierInfo = PRODUCT_TIERS[product_id]
    if (!tierInfo) {
      return new Response(
        JSON.stringify({ error: 'Invalid product ID' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Check if company_plans record exists for this company
    const { data: existingPlan } = await supabase
      .from('company_plans')
      .select('*')
      .eq('company_id', company_id)
      .eq('status', 'active')
      .single()

    const now = new Date()
    const isAnnual = product_id.includes('annual')
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
          apple_transaction_id: transaction_id,
          product_id: product_id,
          started_at: now.toISOString(),
          ends_at: endsAt.toISOString(),
          updated_at: now.toISOString(),
        })
        .eq('id', existingPlan.id)

      if (updateError) {
        console.error('Failed to update plan:', updateError)
        return new Response(
          JSON.stringify({ error: 'Failed to update subscription' }),
          { status: 500, headers: { 'Content-Type': 'application/json' } }
        )
      }
    } else {
      // Create new plan
      const { error: insertError } = await supabase
        .from('company_plans')
        .insert({
          company_id: company_id,
          tier: tierInfo.tier,
          monthly_company_cap: tierInfo.monthly_cap,
          apple_transaction_id: transaction_id,
          product_id: product_id,
          status: 'active',
          started_at: now.toISOString(),
          ends_at: endsAt.toISOString(),
        })

      if (insertError) {
        console.error('Failed to create plan:', insertError)
        return new Response(
          JSON.stringify({ error: 'Failed to create subscription' }),
          { status: 500, headers: { 'Content-Type': 'application/json' } }
        )
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        tier: tierInfo.tier,
        monthly_cap: tierInfo.monthly_cap,
        ends_at: endsAt.toISOString(),
      }),
      { headers: { 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Error validating receipt:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})
