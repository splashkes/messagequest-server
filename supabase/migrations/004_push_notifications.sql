-- Create push_tokens table
CREATE TABLE IF NOT EXISTS push_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    platform TEXT NOT NULL CHECK (platform IN ('ios', 'android')),
    device_name TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, token)
);

-- Enable RLS
ALTER TABLE push_tokens ENABLE ROW LEVEL SECURITY;

-- Users can only manage their own tokens
CREATE POLICY "Users can manage own push tokens" ON push_tokens
    FOR ALL USING (auth.uid() = user_id);

-- Create function to send push notifications on new messages
CREATE OR REPLACE FUNCTION notify_message_recipients()
RETURNS TRIGGER AS $$
DECLARE
    chat_type TEXT;
    chat_name TEXT;
    sender_name TEXT;
    recipient_tokens RECORD;
BEGIN
    -- Get chat info
    SELECT type, name INTO chat_type, chat_name
    FROM chats WHERE id = NEW.chat_id;
    
    -- Get sender name
    SELECT display_name INTO sender_name
    FROM profiles WHERE id = NEW.sender_id;
    
    -- For each participant in the chat (except sender)
    FOR recipient_tokens IN 
        SELECT DISTINCT pt.user_id, pt.token
        FROM chat_participants cp
        JOIN push_tokens pt ON pt.user_id = cp.user_id
        WHERE cp.chat_id = NEW.chat_id 
        AND cp.user_id != NEW.sender_id
        AND pt.platform = 'ios'
    LOOP
        -- Call Edge Function to send push
        PERFORM net.http_post(
            url := current_setting('app.settings.supabase_url') || '/functions/v1/send-push-notification',
            headers := jsonb_build_object(
                'Authorization', 'Bearer ' || current_setting('app.settings.supabase_service_role_key'),
                'Content-Type', 'application/json'
            ),
            body := jsonb_build_object(
                'userId', recipient_tokens.user_id,
                'title', CASE 
                    WHEN chat_type = 'direct' THEN sender_name
                    ELSE chat_name
                END,
                'body', NEW.content,
                'badge', 1,
                'data', jsonb_build_object(
                    'chatId', NEW.chat_id,
                    'messageId', NEW.id,
                    'senderId', NEW.sender_id
                )
            )
        );
    END LOOP;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for new messages
DROP TRIGGER IF EXISTS on_message_created ON messages;
CREATE TRIGGER on_message_created
    AFTER INSERT ON messages
    FOR EACH ROW
    EXECUTE FUNCTION notify_message_recipients();

-- Create function to store/update push token
CREATE OR REPLACE FUNCTION upsert_push_token(
    p_token TEXT,
    p_platform TEXT DEFAULT 'ios',
    p_device_name TEXT DEFAULT NULL
)
RETURNS void AS $$
BEGIN
    INSERT INTO push_tokens (user_id, token, platform, device_name)
    VALUES (auth.uid(), p_token, p_platform, p_device_name)
    ON CONFLICT (user_id, token) 
    DO UPDATE SET 
        updated_at = NOW(),
        device_name = COALESCE(EXCLUDED.device_name, push_tokens.device_name);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create index for performance
CREATE INDEX idx_push_tokens_user_id ON push_tokens(user_id);
CREATE INDEX idx_push_tokens_platform ON push_tokens(platform);