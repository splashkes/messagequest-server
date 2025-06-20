-- Create preset chats for Murder Mystery Test 1 experience
DO $$
DECLARE
    exp_id UUID;
    char_record RECORD;
    group_chat_id UUID;
BEGIN
    -- Get the experience ID
    SELECT id INTO exp_id FROM public.experiences WHERE short_name = 'mmt1';
    
    -- Create the main group chat first
    INSERT INTO public.chats (id, name, type, experience_id, created_at, updated_at)
    VALUES (
        gen_random_uuid(),
        'Manor Investigation - All Guests',
        'group',
        exp_id,
        NOW(),
        NOW()
    )
    ON CONFLICT DO NOTHING
    RETURNING id INTO group_chat_id;
    
    -- Create faction chats
    INSERT INTO public.chats (name, type, experience_id, created_at, updated_at)
    VALUES 
        ('The Estate Staff', 'faction', exp_id, NOW(), NOW()),
        ('Law Enforcement', 'faction', exp_id, NOW(), NOW()),
        ('High Society', 'faction', exp_id, NOW(), NOW())
    ON CONFLICT DO NOTHING;
    
    -- Create individual direct message chats for each character
    FOR char_record IN 
        SELECT id, name FROM public.characters WHERE experience_id = exp_id
    LOOP
        INSERT INTO public.chats (name, type, experience_id, created_at, updated_at)
        VALUES (
            char_record.name,
            'direct',
            exp_id,
            NOW(),
            NOW()
        )
        ON CONFLICT DO NOTHING;
    END LOOP;
    
    -- Note: Chat participants will be added when users join the experience
    -- and select their characters. For now, these are just empty chat rooms.
    
END $$;

-- Add a helper function to get all chats for an experience
CREATE OR REPLACE FUNCTION get_experience_chats(exp_short_name TEXT)
RETURNS TABLE (
    id UUID,
    name TEXT,
    type chat_type,
    participant_count BIGINT,
    last_message_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id,
        c.name,
        c.type,
        COUNT(DISTINCT cp.user_id) as participant_count,
        MAX(m.created_at) as last_message_at
    FROM public.chats c
    JOIN public.experiences e ON e.id = c.experience_id
    LEFT JOIN public.chat_participants cp ON cp.chat_id = c.id
    LEFT JOIN public.messages m ON m.chat_id = c.id
    WHERE e.short_name = exp_short_name
    GROUP BY c.id, c.name, c.type
    ORDER BY 
        CASE c.type 
            WHEN 'group' THEN 1 
            WHEN 'faction' THEN 2 
            WHEN 'direct' THEN 3 
        END,
        c.name;
END;
$$ LANGUAGE plpgsql;

-- Update the chats API endpoint to include experience filtering
CREATE OR REPLACE FUNCTION get_user_chats(user_id UUID)
RETURNS TABLE (
    id UUID,
    name TEXT,
    type chat_type,
    experience_id UUID,
    unread_count BIGINT,
    last_message JSONB
) AS $$
BEGIN
    RETURN QUERY
    WITH user_experience AS (
        -- Get user's current experience based on their character
        SELECT DISTINCT c.experience_id
        FROM public.user_characters uc
        JOIN public.characters c ON c.id = uc.character_id
        WHERE uc.user_id = get_user_chats.user_id
        LIMIT 1
    )
    SELECT 
        c.id,
        c.name,
        c.type,
        c.experience_id,
        COALESCE(
            COUNT(m.id) FILTER (
                WHERE m.id IS NOT NULL 
                AND NOT EXISTS (
                    SELECT 1 FROM public.message_reads mr 
                    WHERE mr.message_id = m.id 
                    AND mr.user_id = get_user_chats.user_id
                )
            ), 
            0
        ) as unread_count,
        CASE 
            WHEN MAX(m.created_at) IS NOT NULL THEN
                jsonb_build_object(
                    'id', (SELECT m2.id FROM public.messages m2 WHERE m2.chat_id = c.id ORDER BY m2.created_at DESC LIMIT 1),
                    'content', (SELECT m2.content FROM public.messages m2 WHERE m2.chat_id = c.id ORDER BY m2.created_at DESC LIMIT 1),
                    'sender_name', (SELECT p.display_name FROM public.messages m2 JOIN public.profiles p ON p.id = m2.sender_id WHERE m2.chat_id = c.id ORDER BY m2.created_at DESC LIMIT 1),
                    'timestamp', (SELECT m2.created_at FROM public.messages m2 WHERE m2.chat_id = c.id ORDER BY m2.created_at DESC LIMIT 1)
                )
            ELSE NULL
        END as last_message
    FROM public.chats c
    JOIN user_experience ue ON ue.experience_id = c.experience_id
    LEFT JOIN public.messages m ON m.chat_id = c.id
    GROUP BY c.id, c.name, c.type, c.experience_id
    ORDER BY 
        CASE c.type 
            WHEN 'group' THEN 1 
            WHEN 'faction' THEN 2 
            WHEN 'direct' THEN 3 
        END,
        c.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;