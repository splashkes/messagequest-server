# MessageQuest Server

Supabase backend for the MessageQuest immersive role-play messaging app.

## Architecture

MessageQuest uses **Supabase** as a complete backend solution:

- ✅ PostgreSQL database with full schema
- ✅ Real-time subscriptions for live messaging
- ✅ Authentication (Email/Password + Apple Sign In)
- ✅ Row Level Security for data protection
- ✅ Edge Functions for push notifications and AI responses
- ✅ Auto-generated REST APIs
- ✅ Global CDN distribution

## Quick Start

### Prerequisites

1. [Supabase CLI](https://supabase.com/docs/guides/cli) installed
2. A Supabase project at [supabase.com](https://supabase.com)
3. Environment variables (see below)

### Setup Steps

1. **Link to your Supabase project:**
   ```bash
   supabase link --project-ref YOUR_PROJECT_REF
   ```

2. **Run database migrations:**
   ```bash
   supabase db push
   ```

3. **Deploy Edge Functions:**
   ```bash
   supabase functions deploy
   ```

4. **Update your iOS app** with:
   - Supabase URL: `https://YOUR_PROJECT_REF.supabase.co`
   - Anon Key: Found in your Supabase dashboard

## Features

- **Authentication**: Email/Password + Apple Sign In
- **Real-time Messaging**: Instant message delivery with typing indicators
- **Character System**: Dynamic character availability and selection
- **Push Notifications**: iOS push via APNs Edge Function
- **AI Integration**: OpenAI-powered response suggestions
- **Security**: Row Level Security on all tables

## Project Structure

```
mq-server/
├── supabase/
│   ├── config.toml           # Supabase configuration
│   ├── seed.sql             # Sample data for development
│   ├── migrations/          # Database schema
│   │   ├── 001_initial_schema.sql
│   │   ├── 002_row_level_security.sql
│   │   └── 003_realtime_and_functions.sql
│   └── functions/           # Edge Functions
│       ├── send-push-notification/
│       └── generate-ai-responses/
└── README.md
```

## Environment Variables

Set these in your Supabase dashboard under Settings > Edge Functions:

- `APNS_KEY_ID`: Apple Push Notification Service key ID
- `APNS_TEAM_ID`: Your Apple Developer Team ID  
- `APNS_BUNDLE_ID`: Your iOS app bundle identifier
- `APNS_PRIVATE_KEY`: Contents of your .p8 key file
- `OPENAI_API_KEY`: For AI response generation

## Database Schema

The database includes tables for:
- `profiles`: User profiles and metadata
- `characters`: Available characters with traits and objectives
- `chats`: Chat rooms (direct and group)
- `messages`: All messages with read receipts
- `character_objectives`: Character goals and secrets
- `user_characters`: Character assignments
- `chat_participants`: Chat membership

## Development

### Local Development

```bash
# Start local Supabase
supabase start

# Apply migrations
supabase db reset

# Serve functions locally
supabase functions serve
```

### Testing Edge Functions

```bash
# Test push notification
curl -i --location --request POST 'http://localhost:54321/functions/v1/send-push-notification' \
  --header 'Authorization: Bearer YOUR_ANON_KEY' \
  --header 'Content-Type: application/json' \
  --data '{"userId": "user123", "message": "Test notification"}'
```