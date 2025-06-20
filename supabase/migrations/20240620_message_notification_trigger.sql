-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS http;

-- Create a simpler notification system that stores pending notifications
-- These can be processed by a scheduled Edge Function or external service

-- Create a table for pending push notifications
CREATE TABLE IF NOT EXISTS push_notification_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    device_token TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    data JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    processed_at TIMESTAMPTZ,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'failed')),
    error_message TEXT
);

-- Create index for processing
CREATE INDEX idx_push_queue_pending ON push_notification_queue(status, created_at) WHERE status = 'pending';

-- Create function to queue notifications on new messages
CREATE OR REPLACE FUNCTION queue_message_notifications()
RETURNS TRIGGER AS $$
DECLARE
    sender_name TEXT;
    chat_name TEXT;
    chat_type_val TEXT;
BEGIN
    -- Get sender name
    SELECT display_name INTO sender_name
    FROM profiles WHERE id = NEW.sender_id;
    
    -- Get chat info
    SELECT name, type INTO chat_name, chat_type_val
    FROM chats WHERE id = NEW.chat_id;
    
    -- Queue notifications for all chat participants (except sender)
    INSERT INTO push_notification_queue (user_id, device_token, title, body, data)
    SELECT 
        pt.user_id,
        pt.token,
        CASE 
            WHEN chat_type_val = 'direct' THEN sender_name
            ELSE chat_name
        END,
        NEW.content,
        jsonb_build_object(
            'chatId', NEW.chat_id,
            'messageId', NEW.id,
            'senderId', NEW.sender_id
        )
    FROM chat_participants cp
    JOIN push_tokens pt ON pt.user_id = cp.user_id
    WHERE cp.chat_id = NEW.chat_id 
    AND cp.user_id != NEW.sender_id
    AND pt.platform = 'ios';
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger
DROP TRIGGER IF EXISTS queue_notifications_on_message ON messages;
CREATE TRIGGER queue_notifications_on_message
    AFTER INSERT ON messages
    FOR EACH ROW
    EXECUTE FUNCTION queue_message_notifications();

-- Create a function to process the queue (can be called by Edge Function)
CREATE OR REPLACE FUNCTION process_notification_queue()
RETURNS TABLE (
    notification_id UUID,
    user_id UUID,
    device_token TEXT,
    title TEXT,
    body TEXT,
    data JSONB
) AS $$
BEGIN
    -- Return pending notifications and mark them as being processed
    RETURN QUERY
    UPDATE push_notification_queue
    SET status = 'sent', processed_at = NOW()
    WHERE status = 'pending'
    AND created_at > NOW() - INTERVAL '1 hour' -- Only process recent notifications
    RETURNING id, push_notification_queue.user_id, push_notification_queue.device_token, 
              push_notification_queue.title, push_notification_queue.body, push_notification_queue.data;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant necessary permissions
GRANT SELECT, INSERT, UPDATE ON push_notification_queue TO authenticated;
GRANT EXECUTE ON FUNCTION process_notification_queue() TO authenticated, service_role;