-- Seed data for MessageQuest

-- Insert test characters
INSERT INTO characters (id, name, avatar_url, bio, faction, role, is_available, secrets) VALUES
('11111111-1111-1111-1111-111111111111', 'Detective Morgan', NULL, 'A seasoned detective with 20 years on the force. Known for unconventional methods and a perfect case-closing record. Has a mysterious past that may be connected to the current investigation.', 'Police Department', 'Lead Investigator', true, '["You were once engaged to the victim", "You''ve been taking bribes from the local crime family"]'),
('22222222-2222-2222-2222-222222222222', 'Dr. Elizabeth Crane', NULL, 'The city''s chief medical examiner. Brilliant but socially awkward. Has access to all forensic evidence and a photographic memory for details.', 'Medical Department', 'Forensic Expert', true, '["You accidentally destroyed key DNA evidence", "You''re being blackmailed by someone in the department"]'),
('33333333-3333-3333-3333-333333333333', 'Marcus Sterling', NULL, 'A wealthy businessman with connections throughout the city. Charming and persuasive, but harbors dark secrets. Was at the scene on the night of the murder.', 'High Society', 'Prime Suspect', true, '["You were having an affair with the victim''s spouse", "You witnessed the murder but can''t reveal it without exposing your illegal activities"]'),
('44444444-4444-4444-4444-444444444444', 'Riley Walsh', NULL, 'An investigative journalist following the case. Has a reputation for uncovering the truth at any cost. May have ulterior motives for being involved.', 'Media', 'Journalist', true, '["You''ve been fabricating sources for your stories", "You''re actually the victim''s illegitimate child"]');

-- Insert objectives for each character
INSERT INTO objectives (character_id, title, description, is_secret, priority) VALUES
-- Detective Morgan
('11111111-1111-1111-1111-111111111111', 'Find the murderer', 'Investigate all suspects and gather conclusive evidence', false, 'high'),
('11111111-1111-1111-1111-111111111111', 'Protect the witness', 'Ensure the key witness remains safe throughout the investigation', false, 'high'),
('11111111-1111-1111-1111-111111111111', 'Hide your connection', 'Keep your past relationship with the victim secret from other players', true, 'medium'),

-- Dr. Elizabeth Crane
('22222222-2222-2222-2222-222222222222', 'Analyze all evidence', 'Perform thorough analysis on all physical evidence', false, 'high'),
('22222222-2222-2222-2222-222222222222', 'Share findings strategically', 'Control information flow to influence the investigation', false, 'medium'),
('22222222-2222-2222-2222-222222222222', 'Cover up the mistake', 'Hide the fact that you contaminated crucial evidence', true, 'high'),

-- Marcus Sterling
('33333333-3333-3333-3333-333333333333', 'Prove your innocence', 'Convince others you''re not the killer', false, 'high'),
('33333333-3333-3333-3333-333333333333', 'Maintain your reputation', 'Keep your business dealings from becoming public', false, 'medium'),
('33333333-3333-3333-3333-333333333333', 'Find the real killer', 'You know who did it - gather proof without revealing how you know', true, 'high'),

-- Riley Walsh
('44444444-4444-4444-4444-444444444444', 'Get the exclusive story', 'Be the first to report the truth about the murder', false, 'high'),
('44444444-4444-4444-4444-444444444444', 'Protect your sources', 'Keep your informants'' identities secret', false, 'medium'),
('44444444-4444-4444-4444-444444444444', 'Frame the corrupt cop', 'You have evidence of police corruption - use it to your advantage', true, 'medium');