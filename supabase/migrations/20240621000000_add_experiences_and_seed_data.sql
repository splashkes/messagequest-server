-- Add experiences table to support multiple group experiences
CREATE TABLE IF NOT EXISTS public.experiences (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    short_name TEXT NOT NULL UNIQUE,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add experience_id to relevant tables
ALTER TABLE public.characters ADD COLUMN IF NOT EXISTS experience_id UUID REFERENCES experiences(id);
ALTER TABLE public.chats ADD COLUMN IF NOT EXISTS experience_id UUID REFERENCES experiences(id);
ALTER TABLE public.objectives ADD COLUMN IF NOT EXISTS experience_id UUID REFERENCES experiences(id);

-- Create indexes for experience lookups
CREATE INDEX IF NOT EXISTS idx_characters_experience ON public.characters(experience_id);
CREATE INDEX IF NOT EXISTS idx_chats_experience ON public.chats(experience_id);
CREATE INDEX IF NOT EXISTS idx_objectives_experience ON public.objectives(experience_id);

-- Add RLS policies for experiences
ALTER TABLE public.experiences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Experiences are viewable by authenticated users" ON public.experiences
    FOR SELECT TO authenticated USING (true);

-- Insert the first experience
INSERT INTO public.experiences (name, short_name, description)
VALUES ('Murder Mystery Test 1', 'mmt1', 'A thrilling murder mystery experience set in a grand manor')
ON CONFLICT (short_name) DO NOTHING;

-- Get the experience ID for our seed data
DO $$
DECLARE
    exp_id UUID;
BEGIN
    SELECT id INTO exp_id FROM public.experiences WHERE short_name = 'mmt1';

    -- Insert characters for this experience
    INSERT INTO public.characters (name, avatar_url, bio, faction, role, is_available, secrets, experience_id)
    VALUES 
        ('Detective Harris', 'https://api.dicebear.com/7.x/personas/svg?seed=detective', 
         'A seasoned detective with 20 years on the force. Known for her sharp wit and keen observation skills.', 
         'Law Enforcement', 'Detective', true, 
         '[{"id": "1", "content": "Has a personal connection to the victim from a case 10 years ago"}]'::jsonb, 
         exp_id),
        
        ('Lord Pemberton', 'https://api.dicebear.com/7.x/personas/svg?seed=lord', 
         'The wealthy host of tonight''s gathering. A collector of rare artifacts and keeper of many secrets.', 
         'The Estate', 'Host', true, 
         '[{"id": "1", "content": "Is deeply in debt despite appearances"}, {"id": "2", "content": "Was being blackmailed by the victim"}]'::jsonb, 
         exp_id),
        
        ('Dr. Elizabeth Chen', 'https://api.dicebear.com/7.x/personas/svg?seed=doctor', 
         'The victim''s personal physician. Calm under pressure with an analytical mind.', 
         'Medical', 'Doctor', true, 
         '[{"id": "1", "content": "Discovered the victim was terminally ill"}, {"id": "2", "content": "Was asked to falsify medical records"}]'::jsonb, 
         exp_id),
        
        ('Chef Baptiste', 'https://api.dicebear.com/7.x/personas/svg?seed=chef', 
         'Head chef of the estate. Passionate about cuisine but harbors a mysterious past.', 
         'The Estate', 'Chef', true, 
         '[{"id": "1", "content": "Used to work for a rival family"}, {"id": "2", "content": "Poisoned someone accidentally 5 years ago"}]'::jsonb, 
         exp_id),
        
        ('Ms. Victoria Sterling', 'https://api.dicebear.com/7.x/personas/svg?seed=victoria', 
         'A renowned art dealer with connections across high society. Always impeccably dressed.', 
         'High Society', 'Art Dealer', true, 
         '[{"id": "1", "content": "Sold the victim a forged painting last month"}, {"id": "2", "content": "Is actually an undercover insurance investigator"}]'::jsonb, 
         exp_id),
        
        ('James the Butler', 'https://api.dicebear.com/7.x/personas/svg?seed=butler', 
         'The estate''s loyal butler who sees all but says little. Has served the family for 30 years.', 
         'The Estate', 'Butler', true, 
         '[{"id": "1", "content": "Witnessed the victim''s last argument"}, {"id": "2", "content": "Is the illegitimate son of the previous Lord"}]'::jsonb, 
         exp_id);

    -- Create the main group chat for this experience
    INSERT INTO public.chats (name, type, experience_id)
    VALUES ('Manor Investigation', 'group', exp_id)
    ON CONFLICT DO NOTHING;

    -- Add character objectives for this experience
    INSERT INTO public.objectives (character_id, title, description, priority, is_completed, experience_id)
    SELECT 
        c.id,
        CASE c.name
            WHEN 'Detective Harris' THEN 'Solve the Murder'
            WHEN 'Lord Pemberton' THEN 'Protect the Family Name'
            WHEN 'Dr. Elizabeth Chen' THEN 'Preserve Medical Ethics'
            WHEN 'Chef Baptiste' THEN 'Keep Past Hidden'
            WHEN 'Ms. Victoria Sterling' THEN 'Complete the Investigation'
            WHEN 'James the Butler' THEN 'Maintain Order'
        END,
        CASE c.name
            WHEN 'Detective Harris' THEN 'Find the murderer before they strike again'
            WHEN 'Lord Pemberton' THEN 'Ensure the family reputation remains intact'
            WHEN 'Dr. Elizabeth Chen' THEN 'Navigate the ethical dilemmas without compromising integrity'
            WHEN 'Chef Baptiste' THEN 'Prevent anyone from discovering your past mistake'
            WHEN 'Ms. Victoria Sterling' THEN 'Uncover the truth about the estate''s valuable collection'
            WHEN 'James the Butler' THEN 'Keep the household running despite the chaos'
        END,
        'high'::objective_priority,
        false,
        exp_id
    FROM public.characters c
    WHERE c.experience_id = exp_id;

END $$;

-- Update RLS policies to include experience filtering where appropriate
CREATE POLICY "Characters viewable by experience participants" ON public.characters
    FOR SELECT TO authenticated 
    USING (
        -- User can see characters in their experiences
        EXISTS (
            SELECT 1 FROM public.user_characters uc
            WHERE uc.user_id = auth.uid() 
            AND uc.character_id = characters.id
        )
        OR
        -- Or characters in experiences where they have any character
        EXISTS (
            SELECT 1 FROM public.user_characters uc
            JOIN public.characters c ON c.id = uc.character_id
            WHERE uc.user_id = auth.uid() 
            AND c.experience_id = characters.experience_id
        )
    );

-- Function to assign all users to an experience with available characters
CREATE OR REPLACE FUNCTION assign_users_to_experience(exp_short_name TEXT)
RETURNS void AS $$
DECLARE
    exp_id UUID;
    available_char RECORD;
    user_record RECORD;
BEGIN
    -- Get experience ID
    SELECT id INTO exp_id FROM public.experiences WHERE short_name = exp_short_name;
    
    -- For each user, assign an available character from this experience
    FOR user_record IN SELECT id FROM public.profiles LOOP
        -- Find an available character in this experience
        SELECT * INTO available_char 
        FROM public.characters 
        WHERE experience_id = exp_id 
        AND is_available = true
        AND NOT EXISTS (
            SELECT 1 FROM public.user_characters 
            WHERE character_id = characters.id
        )
        LIMIT 1;
        
        -- If found, assign it
        IF available_char.id IS NOT NULL THEN
            INSERT INTO public.user_characters (user_id, character_id)
            VALUES (user_record.id, available_char.id)
            ON CONFLICT DO NOTHING;
            
            -- Mark character as unavailable
            UPDATE public.characters 
            SET is_available = false 
            WHERE id = available_char.id;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updated_at on new tables
CREATE TRIGGER update_experiences_updated_at BEFORE UPDATE ON public.experiences
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();