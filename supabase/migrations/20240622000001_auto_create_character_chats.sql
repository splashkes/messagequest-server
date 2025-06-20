-- Function to automatically create direct chats between a user and other active characters in their experience
CREATE OR REPLACE FUNCTION public.ensure_character_chats(p_user_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_character_id UUID;
    v_experience_id UUID;
    v_other_character RECORD;
    v_chat_id UUID;
    v_created_chats JSON[] := '{}';
    v_chat_name TEXT;
BEGIN
    -- Get the user's current character and experience
    SELECT uc.character_id, c.experience_id
    INTO v_user_character_id, v_experience_id
    FROM public.user_characters uc
    JOIN public.characters c ON c.id = uc.character_id
    WHERE uc.user_id = p_user_id
    ORDER BY uc.created_at DESC
    LIMIT 1;

    -- If user has no character, return empty
    IF v_user_character_id IS NULL THEN
        RETURN '[]'::JSON;
    END IF;

    -- Get all other active characters in the same experience
    FOR v_other_character IN
        SELECT c.id, c.name, uc.user_id
        FROM public.characters c
        JOIN public.user_characters uc ON uc.character_id = c.id
        WHERE c.experience_id = v_experience_id
        AND c.id != v_user_character_id
        AND c.is_available = false  -- Character is assigned
    LOOP
        -- Check if a direct chat already exists between these characters
        SELECT cp1.chat_id INTO v_chat_id
        FROM public.chat_participants cp1
        JOIN public.chat_participants cp2 ON cp1.chat_id = cp2.chat_id
        JOIN public.chats ch ON ch.id = cp1.chat_id
        WHERE cp1.user_id = p_user_id
        AND cp2.user_id = v_other_character.user_id
        AND ch.type = 'direct'
        AND ch.experience_id = v_experience_id;

        -- If no chat exists, create one
        IF v_chat_id IS NULL THEN
            -- Create chat name from both character names
            SELECT name INTO v_chat_name 
            FROM public.characters 
            WHERE id = v_user_character_id;
            
            v_chat_name := v_chat_name || ' & ' || v_other_character.name;

            -- Insert new chat
            INSERT INTO public.chats (name, type, experience_id, created_by, created_at, updated_at)
            VALUES (v_chat_name, 'direct', v_experience_id, p_user_id, NOW(), NOW())
            RETURNING id INTO v_chat_id;

            -- Add both participants
            INSERT INTO public.chat_participants (chat_id, user_id, joined_at)
            VALUES 
                (v_chat_id, p_user_id, NOW()),
                (v_chat_id, v_other_character.user_id, NOW());

            -- Send a hidden system message to initialize the chat
            INSERT INTO public.messages (
                chat_id, 
                sender_id, 
                sender_character_id,
                sender_name,
                content, 
                type, 
                status,
                metadata,
                created_at
            ) VALUES (
                v_chat_id,
                '00000000-0000-0000-0000-000000000000', -- System user ID
                NULL,
                'System',
                'Chat initialized',
                'system',
                'delivered',
                jsonb_build_object(
                    'hidden', true,
                    'action', 'chat_initialized',
                    'participants', jsonb_build_array(
                        jsonb_build_object('user_id', p_user_id, 'character_id', v_user_character_id),
                        jsonb_build_object('user_id', v_other_character.user_id, 'character_id', v_other_character.id)
                    )
                ),
                NOW()
            );

            -- Add to created chats array
            v_created_chats := array_append(v_created_chats, 
                json_build_object(
                    'chat_id', v_chat_id,
                    'name', v_chat_name,
                    'with_character', v_other_character.name,
                    'with_user_id', v_other_character.user_id
                )
            );
        END IF;
    END LOOP;

    -- Also ensure user is added to all group and faction chats for their experience
    INSERT INTO public.chat_participants (chat_id, user_id, joined_at)
    SELECT c.id, p_user_id, NOW()
    FROM public.chats c
    WHERE c.experience_id = v_experience_id
    AND c.type IN ('group', 'faction')
    AND NOT EXISTS (
        SELECT 1 FROM public.chat_participants cp 
        WHERE cp.chat_id = c.id AND cp.user_id = p_user_id
    );

    RETURN array_to_json(v_created_chats);
END;
$$;

-- Create RPC endpoint for the function
GRANT EXECUTE ON FUNCTION public.ensure_character_chats TO authenticated;

-- Also create a trigger to automatically create chats when a character is assigned
CREATE OR REPLACE FUNCTION public.on_character_assigned()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- When a user_character is created, ensure all their chats are created
    PERFORM public.ensure_character_chats(NEW.user_id);
    RETURN NEW;
END;
$$;

-- Create trigger on user_characters table
DROP TRIGGER IF EXISTS ensure_chats_on_character_assigned ON public.user_characters;
CREATE TRIGGER ensure_chats_on_character_assigned
    AFTER INSERT ON public.user_characters
    FOR EACH ROW
    EXECUTE FUNCTION public.on_character_assigned();