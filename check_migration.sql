-- Check if the function exists
SELECT EXISTS (
    SELECT 1
    FROM pg_proc
    WHERE proname = 'ensure_character_chats'
);

-- Check if the trigger exists
SELECT EXISTS (
    SELECT 1
    FROM pg_trigger
    WHERE tgname = 'ensure_chats_on_character_assigned'
);

-- List all functions matching our pattern
SELECT proname, prosrc
FROM pg_proc
WHERE proname LIKE '%character_chats%'
   OR proname LIKE '%character_assigned%';

-- List all triggers on user_characters table
SELECT tgname, tgrelid::regclass, tgfoid::regproc
FROM pg_trigger
WHERE tgrelid = 'public.user_characters'::regclass;