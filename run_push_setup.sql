-- Check if push_tokens table exists before creating
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'push_tokens') THEN
        -- Create push_tokens table
        CREATE TABLE push_tokens (
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

        -- Create indexes
        CREATE INDEX idx_push_tokens_user_id ON push_tokens(user_id);
        CREATE INDEX idx_push_tokens_platform ON push_tokens(platform);
        
        RAISE NOTICE 'Created push_tokens table';
    ELSE
        RAISE NOTICE 'push_tokens table already exists';
    END IF;
END $$;

-- Create or replace the upsert function
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

-- Create or replace the view
CREATE OR REPLACE VIEW chat_participant_tokens AS
SELECT 
    cp.chat_id,
    cp.user_id,
    pt.token,
    pt.platform,
    p.display_name,
    c.name as chat_name,
    c.type as chat_type
FROM chat_participants cp
JOIN push_tokens pt ON pt.user_id = cp.user_id
JOIN profiles p ON p.id = cp.user_id
JOIN chats c ON c.id = cp.chat_id
WHERE pt.platform = 'ios';

-- Grant access to the view
GRANT SELECT ON chat_participant_tokens TO authenticated;

-- Success message
DO $$ 
BEGIN
    RAISE NOTICE 'Push notification setup completed successfully!';
END $$;