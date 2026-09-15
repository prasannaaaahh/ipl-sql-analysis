-- ============================================
-- IPL Analysis Project — Team Name Cleaning
-- ============================================
-- Problem: several teams were renamed by their owners over the years
-- (e.g. Delhi Daredevils -> Delhi Capitals), so the same real-world
-- franchise appears under multiple string values in the raw data.
--
-- This is different from a team being shut down and replaced by a new
-- franchise in the same city (e.g. Deccan Chargers -> Sunrisers Hyderabad,
-- Pune Warriors -> Rising Pune Supergiant). Those are different ownership
-- groups and are intentionally kept as separate, distinct teams.

USE ipl_project;

CREATE TABLE team_name_mapping (
    raw_name VARCHAR(100) PRIMARY KEY,
    canonical_name VARCHAR(100)
);

INSERT INTO team_name_mapping (raw_name, canonical_name) VALUES
('Chennai Super Kings',         'Chennai Super Kings'),
('Deccan Chargers',             'Deccan Chargers'),
('Delhi Daredevils',            'Delhi Capitals'),
('Delhi Capitals',              'Delhi Capitals'),
('Gujarat Lions',               'Gujarat Lions'),
('Gujarat Titans',              'Gujarat Titans'),
('Kings XI Punjab',             'Punjab Kings'),
('Kochi Tuskers Kerala',        'Kochi Tuskers Kerala'),
('Kolkata Knight Riders',       'Kolkata Knight Riders'),
('Lucknow Super Giants',        'Lucknow Super Giants'),
('Mumbai Indians',              'Mumbai Indians'),
('Pune Warriros',               'Pune Warriors'),      -- typo variant present in source data
('Pune Warriors',               'Pune Warriors'),
('Punjab Kings',                'Punjab Kings'),
('Rajasthan Royals',            'Rajasthan Royals'),
('Rising Pune Supergiant',      'Rising Pune Supergiants'),
('Rising Pune Supergiants',     'Rising Pune Supergiants'),
('Royal Challengers Bangalore', 'Royal Challengers Bengaluru'),
('Royal Challengers Bengaluru', 'Royal Challengers Bengaluru'),
('Sunrisers Hyderabad',         'Sunrisers Hyderabad');

-- Index for GROUP BY / JOIN on canonical_name (used in matches_clean joins
-- and in 03_analysis_queries.sql — Q1, Q7, Q10, Q14)
CREATE INDEX idx_team_mapping_canonical ON team_name_mapping(canonical_name);

-- Normalize empty-string "no result" winners to real NULLs
-- (raw data used '' instead of NULL for abandoned/no-result matches)
UPDATE matches
SET winner = NULL
WHERE winner = '' OR winner REGEXP '^[[:space:]]*$';

-- View resolving every team-related column to its canonical name
CREATE VIEW matches_clean AS
SELECT 
    m.*,
    tm1.canonical_name AS team1_clean,
    tm2.canonical_name AS team2_clean,
    tm3.canonical_name AS toss_winner_clean,
    tm4.canonical_name AS winner_clean
FROM matches m
LEFT JOIN team_name_mapping tm1 ON m.team1 = tm1.raw_name
LEFT JOIN team_name_mapping tm2 ON m.team2 = tm2.raw_name
LEFT JOIN team_name_mapping tm3 ON m.toss_winner = tm3.raw_name
LEFT JOIN team_name_mapping tm4 ON m.winner = tm4.raw_name;

-- Verification checks
-- Expect: 20 raw_rows, 15 franchises
SELECT COUNT(*) AS raw_rows, COUNT(DISTINCT canonical_name) AS franchises
FROM team_name_mapping;

-- Expect: total_rows and non_null_winner to differ only by true no-result matches
SELECT COUNT(*) AS total_rows, COUNT(winner_clean) AS non_null_winner
FROM matches_clean;

-- Expect: 0 rows (no unmapped team names remaining)
SELECT DISTINCT m.winner
FROM matches m
LEFT JOIN team_name_mapping tm ON m.winner = tm.raw_name
WHERE m.winner IS NOT NULL
  AND tm.raw_name IS NULL;