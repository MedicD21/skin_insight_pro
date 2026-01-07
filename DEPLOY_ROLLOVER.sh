#!/bin/bash

# =============================================================================
# Deploy Monthly Plan Rollover Edge Function
# =============================================================================
# This script deploys the rollover-plans Edge Function to Supabase
# Run from project root: bash DEPLOY_ROLLOVER.sh
# =============================================================================

set -e  # Exit on error

echo "🚀 Deploying Monthly Plan Rollover Edge Function"
echo "================================================="
echo ""

# Check if supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo "❌ Supabase CLI not found. Please install it first:"
    echo "   brew install supabase/tap/supabase"
    exit 1
fi

# Check if logged in
echo "📋 Checking Supabase login status..."
if ! supabase projects list &> /dev/null; then
    echo "❌ Not logged in to Supabase. Please login first:"
    echo "   supabase login"
    exit 1
fi

echo "✅ Supabase CLI ready"
echo ""

# Deploy with retry logic
MAX_RETRIES=3
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    echo "📤 Deploying rollover-plans function (attempt $((RETRY_COUNT + 1))/$MAX_RETRIES)..."

    if supabase functions deploy rollover-plans --project-ref meqrnevrimzvvhmopxrq --no-verify-jwt; then
        echo ""
        echo "✅ Function deployed successfully!"

        # Set up cron secret
        echo ""
        echo "🔐 Setting up CRON_SECRET..."

        # Generate random secret
        CRON_SECRET=$(openssl rand -base64 32)

        if supabase secrets set CRON_SECRET="$CRON_SECRET" --project-ref meqrnevrimzvvhmopxrq; then
            echo ""
            echo "✅ CRON_SECRET configured successfully!"
            echo ""
            echo "📋 IMPORTANT: Save this secret for cron trigger setup:"
            echo "================================================="
            echo "$CRON_SECRET"
            echo "================================================="
            echo ""
            echo "✅ Deployment complete!"
            echo ""
            echo "📚 Next steps:"
            echo "1. Copy the CRON_SECRET above"
            echo "2. Follow PLAN_ROLLOVER_SETUP.md to configure the cron trigger"
            echo "3. Test the function using TEST_ROLLOVER.sql"
            echo ""
            exit 0
        else
            echo "⚠️ Warning: Function deployed but secret setup failed"
            echo "You can set it manually with:"
            echo "  supabase secrets set CRON_SECRET=\"\$(openssl rand -base64 32)\" --project-ref meqrnevrimzvvhmopxrq"
            exit 1
        fi
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            echo "⚠️ Deployment failed, retrying in 5 seconds..."
            sleep 5
        fi
    fi
done

echo ""
echo "❌ Deployment failed after $MAX_RETRIES attempts"
echo ""
echo "💡 Troubleshooting:"
echo "1. Check your internet connection"
echo "2. Verify project ref is correct: meqrnevrimzvvhmopxrq"
echo "3. Try deploying manually:"
echo "   supabase functions deploy rollover-plans --project-ref meqrnevrimzvvhmopxrq --debug"
echo ""
exit 1
