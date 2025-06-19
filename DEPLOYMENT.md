# Supabase Deployment Guide

This guide walks through deploying MessageQuest backend to Supabase.

## Prerequisites

1. **Supabase Account**: Sign up at [supabase.com](https://supabase.com)
2. **Supabase CLI**: Install with `brew install supabase/tap/supabase`
3. **Apple Developer Account**: For push notifications
4. **OpenAI API Key**: For AI response generation

## Step 1: Create Supabase Project

1. Go to [app.supabase.com](https://app.supabase.com)
2. Click "New Project"
3. Configure:
   - **Name**: MessageQuest
   - **Database Password**: Save this securely!
   - **Region**: Choose closest to your users
   - **Pricing Plan**: Free tier works for development

## Step 2: Get Project Credentials

From your project dashboard, get:
- **Project URL**: `https://YOUR_PROJECT_REF.supabase.co`
- **Anon Key**: Under Settings > API
- **Service Role Key**: Under Settings > API (keep secret!)

## Step 3: Link Local Project

```bash
cd mq-server
supabase link --project-ref YOUR_PROJECT_REF
```

## Step 4: Run Migrations

Apply the database schema:

```bash
# Push all migrations to production
supabase db push

# Or apply manually in SQL Editor:
# 1. Go to SQL Editor in dashboard
# 2. Run each file in order:
#    - 001_initial_schema.sql
#    - 002_row_level_security.sql  
#    - 003_realtime_and_functions.sql
```

## Step 5: Configure Edge Function Secrets

In your Supabase dashboard:

1. Go to **Settings** > **Edge Functions**
2. Add these secrets:

```bash
APNS_KEY_ID=YOUR_KEY_ID
APNS_TEAM_ID=YOUR_TEAM_ID
APNS_BUNDLE_ID=com.yourcompany.messagequest
APNS_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----
YOUR_P8_KEY_CONTENTS_HERE
-----END PRIVATE KEY-----
OPENAI_API_KEY=sk-your-openai-key
```

## Step 6: Deploy Edge Functions

```bash
# Deploy all functions
supabase functions deploy

# Or deploy individually
supabase functions deploy send-push-notification
supabase functions deploy generate-ai-responses
```

## Step 7: Enable Realtime

In Supabase dashboard:

1. Go to **Database** > **Replication**
2. Enable replication for:
   - `messages` table
   - `characters` table
   - `chats` table

## Step 8: Update iOS App

Update `MessageQuest/Services/SupabaseClient.swift`:

```swift
let supabaseURL = "https://YOUR_PROJECT_REF.supabase.co"
let supabaseAnonKey = "YOUR_ANON_KEY"
```

## Step 9: Test Deployment

### Test Authentication
```bash
curl -X POST https://YOUR_PROJECT_REF.supabase.co/auth/v1/signup \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com", "password": "testpassword"}'
```

### Test Edge Function
```bash
curl -X POST https://YOUR_PROJECT_REF.supabase.co/functions/v1/generate-ai-responses \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"characterId": "char1", "context": "Hello"}'
```

## Monitoring

Monitor your deployment:
- **Logs**: Dashboard > Logs > Edge Functions
- **Database**: Dashboard > Database > Query Performance
- **API**: Dashboard > API > Logs

## Troubleshooting

### Migration Errors
- Check foreign key constraints
- Ensure proper order of execution
- Use `supabase db reset` for clean slate

### Edge Function Issues
- Check environment variables
- View logs in dashboard
- Test locally with `supabase functions serve`

### Connection Problems
- Verify API keys
- Check Row Level Security policies
- Ensure Realtime is enabled

## Production Checklist

- [ ] All migrations applied successfully
- [ ] Edge Functions deployed and tested
- [ ] Environment variables configured
- [ ] RLS policies verified
- [ ] Realtime subscriptions enabled
- [ ] iOS app updated with credentials
- [ ] Push notifications tested
- [ ] AI responses working