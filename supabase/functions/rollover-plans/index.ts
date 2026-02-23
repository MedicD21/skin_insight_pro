import { createClient } from 'jsr:@supabase/supabase-js@2'

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
    const authHeader = req.headers.get('Authorization')
    const cronSecret = Deno.env.get('CRON_SECRET')

    if (cronSecret && authHeader !== `Bearer ${cronSecret}`) {
      return jsonResponse({ error: 'Unauthorized' }, 401)
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    if (!supabaseUrl || !supabaseServiceRoleKey) {
      return jsonResponse({ error: 'Server configuration error' }, 500)
    }

    const supabase = createClient(
      supabaseUrl,
      supabaseServiceRoleKey
    )

    let rolledOver = 0
    let expired = 0

    // Rollover active plans
    const { data: activePlans } = await supabase
      .from('company_plans')
      .select('*')
      .eq('status', 'active')
      .lt('ends_at', new Date().toISOString())

    if (activePlans) {
      for (const plan of activePlans) {
        const newEnd = new Date(plan.ends_at)
        newEnd.setMonth(newEnd.getMonth() + 1)

        await supabase
          .from('company_plans')
          .update({
            started_at: plan.ends_at,
            ends_at: newEnd.toISOString(),
            updated_at: new Date().toISOString()
          })
          .eq('id', plan.id)

        rolledOver++
      }
    }

    // Expire inactive/cancelled plans
    const { data: inactivePlans } = await supabase
      .from('company_plans')
      .update({ status: 'expired', updated_at: new Date().toISOString() })
      .in('status', ['inactive', 'cancelled'])
      .lt('ends_at', new Date().toISOString())
      .select()

    if (inactivePlans) {
      expired = inactivePlans.length
    }

    return jsonResponse({
      success: true,
      rolledOverCount: rolledOver,
      expiredCount: expired,
      timestamp: new Date().toISOString()
    })

  } catch (error) {
    return jsonResponse({ success: false, error: getErrorMessage(error) }, 500)
  }
})
