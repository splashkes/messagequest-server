-- Enable Row Level Security
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE characters ENABLE ROW LEVEL SECURITY;
ALTER TABLE objectives ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_characters ENABLE ROW LEVEL SECURITY;
ALTER TABLE chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_reads ENABLE ROW LEVEL SECURITY;
ALTER TABLE push_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE character_learnings ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Public profiles are viewable by everyone" 
    ON profiles FOR SELECT 
    USING (true);

CREATE POLICY "Users can update own profile" 
    ON profiles FOR UPDATE 
    USING (auth.uid() = id);

-- Characters policies
CREATE POLICY "Characters are viewable by everyone" 
    ON characters FOR SELECT 
    USING (true);

CREATE POLICY "Only admins can modify characters" 
    ON characters FOR ALL 
    USING (auth.jwt() ->> 'role' = 'admin');

-- Objectives policies
CREATE POLICY "Public objectives are viewable by everyone" 
    ON objectives FOR SELECT 
    USING (NOT is_secret);

CREATE POLICY "Secret objectives viewable by character owner" 
    ON objectives FOR SELECT 
    USING (
        is_secret AND EXISTS (
            SELECT 1 FROM user_characters uc 
            WHERE uc.character_id = objectives.character_id 
            AND uc.user_id = auth.uid()
        )
    );

-- User characters policies
CREATE POLICY "Users can view their own character assignments" 
    ON user_characters FOR SELECT 
    USING (user_id = auth.uid());

CREATE POLICY "Users can assign themselves available characters" 
    ON user_characters FOR INSERT 
    WITH CHECK (
        user_id = auth.uid() AND
        EXISTS (
            SELECT 1 FROM characters c 
            WHERE c.id = character_id 
            AND c.is_available = true
        )
    );

-- Chats policies
CREATE POLICY "Users can view chats they participate in" 
    ON chats FOR SELECT 
    USING (
        EXISTS (
            SELECT 1 FROM chat_participants cp 
            WHERE cp.chat_id = chats.id 
            AND cp.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can create chats" 
    ON chats FOR INSERT 
    WITH CHECK (created_by = auth.uid());

-- Chat participants policies
CREATE POLICY "Users can view participants of their chats" 
    ON chat_participants FOR SELECT 
    USING (
        EXISTS (
            SELECT 1 FROM chat_participants cp2 
            WHERE cp2.chat_id = chat_participants.chat_id 
            AND cp2.user_id = auth.uid()
        )
    );

-- Messages policies
CREATE POLICY "Users can view messages in their chats" 
    ON messages FOR SELECT 
    USING (
        EXISTS (
            SELECT 1 FROM chat_participants cp 
            WHERE cp.chat_id = messages.chat_id 
            AND cp.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can send messages to their chats" 
    ON messages FOR INSERT 
    WITH CHECK (
        sender_id = auth.uid() AND
        EXISTS (
            SELECT 1 FROM chat_participants cp 
            WHERE cp.chat_id = chat_id 
            AND cp.user_id = auth.uid()
        )
    );

-- Message reads policies
CREATE POLICY "Users can view read receipts for their chats" 
    ON message_reads FOR SELECT 
    USING (
        EXISTS (
            SELECT 1 FROM messages m
            JOIN chat_participants cp ON cp.chat_id = m.chat_id
            WHERE m.id = message_reads.message_id 
            AND cp.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can mark messages as read" 
    ON message_reads FOR INSERT 
    WITH CHECK (user_id = auth.uid());

-- Push tokens policies
CREATE POLICY "Users can manage their own push tokens" 
    ON push_tokens FOR ALL 
    USING (user_id = auth.uid());

-- Character learnings policies
CREATE POLICY "Users can view their own learnings" 
    ON character_learnings FOR SELECT 
    USING (user_id = auth.uid());

CREATE POLICY "Users can add their own learnings" 
    ON character_learnings FOR INSERT 
    WITH CHECK (user_id = auth.uid());