-- Create database trigger and function for message notifications
-- This will call the Edge Function when new messages are inserted

-- First, enable the pg_net extension if not already enabled
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Create a function that will be triggered on message insert
CREATE OR REPLACE FUNCTION notify_on_message_insert()
RETURNS TRIGGER AS $$
DECLARE
    payload json;
BEGIN
    -- Construct the webhook payload
    payload := json_build_object(
        'type', 'INSERT',
        'table', 'messages',
        'record', row_to_json(NEW),
        'schema', 'public'
    );
    
    -- Call the Edge Function using pg_net
    PERFORM net.http_post(
        url := 'https://zvkecwnrisdiuekoimzt.supabase.co/functions/v1/message-notification-webhook',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || current_setting('app.settings.supabase_service_role_key', true)
        ),
        body := payload::jsonb
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger
DROP TRIGGER IF EXISTS on_message_insert_notify ON messages;
CREATE TRIGGER on_message_insert_notify
    AFTER INSERT ON messages
    FOR EACH ROW
    EXECUTE FUNCTION notify_on_message_insert();

-- Add a comment explaining the trigger
COMMENT ON TRIGGER on_message_insert_notify ON messages IS 'Sends push notifications to chat participants when new messages are created';