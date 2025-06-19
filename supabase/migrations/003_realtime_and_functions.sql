-- Enable realtime for specific tables
ALTER PUBLICATION supabase_realtime ADD TABLE messages;
ALTER PUBLICATION supabase_realtime ADD TABLE chat_participants;
ALTER PUBLICATION supabase_realtime ADD TABLE characters;
ALTER PUBLICATION supabase_realtime ADD TABLE user_characters;

-- Function to get unread message count
CREATE OR REPLACE FUNCTION get_unread_count(p_chat_id UUID, p_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
    last_read TIMESTAMPTZ;
    unread_count INTEGER;
BEGIN
    -- Get user's last read timestamp for this chat
    SELECT last_read_at INTO last_read
    FROM chat_participants
    WHERE chat_id = p_chat_id AND user_id = p_user_id;
    
    -- Count messages created after last read
    SELECT COUNT(*) INTO unread_count
    FROM messages
    WHERE chat_id = p_chat_id
    AND created_at > COALESCE(last_read, '1970-01-01'::timestamptz)
    AND sender_id != p_user_id;
    
    RETURN unread_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to mark character as unavailable when assigned
CREATE OR REPLACE FUNCTION mark_character_unavailable()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE characters 
    SET is_available = false 
    WHERE id = NEW.character_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER after_character_assignment
    AFTER INSERT ON user_characters
    FOR EACH ROW
    EXECUTE FUNCTION mark_character_unavailable();

-- Function to create a direct chat between two users
CREATE OR REPLACE FUNCTION create_direct_chat(other_user_id UUID)
RETURNS UUID AS $$
DECLARE
    chat_id UUID;
    current_user_id UUID;
BEGIN
    current_user_id := auth.uid();
    
    -- Check if direct chat already exists
    SELECT c.id INTO chat_id
    FROM chats c
    WHERE c.type = 'direct'
    AND EXISTS (
        SELECT 1 FROM chat_participants cp1
        WHERE cp1.chat_id = c.id AND cp1.user_id = current_user_id
    )
    AND EXISTS (
        SELECT 1 FROM chat_participants cp2
        WHERE cp2.chat_id = c.id AND cp2.user_id = other_user_id
    );
    
    -- If not exists, create new chat
    IF chat_id IS NULL THEN
        INSERT INTO chats (type, created_by)
        VALUES ('direct', current_user_id)
        RETURNING id INTO chat_id;
        
        -- Add both participants
        INSERT INTO chat_participants (chat_id, user_id)
        VALUES 
            (chat_id, current_user_id),
            (chat_id, other_user_id);
    END IF;
    
    RETURN chat_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get chat with last message and unread count
CREATE OR REPLACE FUNCTION get_chats_with_metadata()
RETURNS TABLE (
    id UUID,
    name TEXT,
    type chat_type,
    last_message JSONB,
    unread_count INTEGER,
    participants JSONB,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id,
        COALESCE(c.name, p2.display_name) as name,
        c.type,
        CASE 
            WHEN m.id IS NOT NULL THEN
                jsonb_build_object(
                    'id', m.id,
                    'content', m.content,
                    'sender_name', p.display_name,
                    'created_at', m.created_at
                )
            ELSE NULL
        END as last_message,
        get_unread_count(c.id, auth.uid()) as unread_count,
        jsonb_agg(
            DISTINCT jsonb_build_object(
                'id', p3.id,
                'display_name', p3.display_name,
                'avatar_url', p3.avatar_url
            )
        ) as participants,
        c.created_at,
        c.updated_at
    FROM chats c
    JOIN chat_participants cp ON cp.chat_id = c.id AND cp.user_id = auth.uid()
    LEFT JOIN LATERAL (
        SELECT * FROM messages 
        WHERE chat_id = c.id 
        ORDER BY created_at DESC 
        LIMIT 1
    ) m ON true
    LEFT JOIN profiles p ON p.id = m.sender_id
    LEFT JOIN chat_participants cp2 ON cp2.chat_id = c.id
    LEFT JOIN profiles p2 ON p2.id = cp2.user_id AND p2.id != auth.uid() AND c.type = 'direct'
    LEFT JOIN chat_participants cp3 ON cp3.chat_id = c.id
    LEFT JOIN profiles p3 ON p3.id = cp3.user_id
    GROUP BY c.id, c.name, c.type, c.created_at, c.updated_at, m.id, m.content, m.created_at, p.display_name, p2.display_name
    ORDER BY COALESCE(m.created_at, c.created_at) DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;