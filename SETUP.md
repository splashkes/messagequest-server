# MessageQuest Server Setup Guide

## Quick Start with Supabase Cloud (Recommended)

### 1. Create Supabase Project

1. Go to [supabase.com](https://supabase.com) and create a new project
2. Save your project URL and anon key

Project URL: https://zvkecwnrisdiuekoimzt.supabase.co
Project API KEY: 

eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp2a2Vjd25yaXNkaXVla29pbXp0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAyNzY3NDQsImV4cCI6MjA2NTg1Mjc0NH0.xySMFv6czh99DJhC2vdLMtbknD-LxN7BaEGa0WTpUZI

### 2. Run Database Migrations

1. Go to SQL Editor in Supabase Dashboard
2. Run each migration file in order:
   - `001_initial_schema.sql`
   - `002_row_level_security.sql`
   - `003_realtime_and_functions.sql`
   - `seed.sql` (for test data)

### 3. Deploy Edge Functions

```bash
# Install Supabase CLI
brew install supabase/tap/supabase

# Link to your project
supabase link --project-ref your-project-ref

# Deploy functions
supabase functions deploy send-push-notification
supabase functions deploy generate-ai-responses
```

### 4. Set Environment Variables

In Supabase Dashboard > Settings > Edge Functions:

```
APNS_KEY_ID=your-key-id
APNS_TEAM_ID=your-team-id
APNS_BUNDLE_ID=com.yourcompany.messagequest
APNS_KEY=contents-of-your-p8-file
APNS_PRODUCTION=false
OPENAI_API_KEY=sk-...
```

### 5. Configure Authentication

In Supabase Dashboard > Authentication > Providers:
- Enable Email/Password
- Configure Apple provider with your Apple credentials

### 6. Update iOS App

Update `APIClient.swift`:
```swift
private let baseURL = "https://your-project.supabase.co"
private let supabaseKey = "your-anon-key"
```

## Apple Push Notifications Setup

### 1. Apple Developer Portal

1. Create an App ID with Push Notifications capability
2. Create a Push Notification Key (.p8 file)
3. Note your Key ID and Team ID

### 2. Configure in Supabase

Add the .p8 file contents as an environment variable:
```bash
APNS_KEY=$(cat AuthKey_XXXXXXXXXX.p8)
```

### 3. iOS App Configuration

1. Enable Push Notifications capability in Xcode
2. Add notification permission request
3. Send device token to backend

## Testing Push Notifications

```bash
# Test sending a push notification
curl -X POST https://your-project.supabase.co/functions/v1/send-push-notification \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "user-uuid",
    "title": "New Message",
    "body": "Detective Morgan: We need to talk...",
    "data": {
      "chatId": "chat-uuid",
      "type": "message"
    }
  }'
```

## Local Development

```bash
# Start Supabase locally
supabase start

# Access services
# - API: http://localhost:54321
# - Database: http://localhost:54322
# - Studio: http://localhost:54323
```

## Production Deployment

For production, consider:
1. Enable RLS on all tables
2. Set up proper backup strategy
3. Configure rate limiting
4. Monitor Edge Function usage
5. Set APNS_PRODUCTION=true

## Troubleshooting

### Push Notifications Not Working
- Verify .p8 key is correctly formatted
- Check device token is being saved
- Ensure app bundle ID matches
- Check Supabase function logs

### Realtime Not Working
- Verify table is added to publication
- Check RLS policies
- Ensure WebSocket connection is established

### Authentication Issues
- Verify redirect URLs are configured
- Check Apple Sign In configuration
- Ensure deep links are set up in iOS app
