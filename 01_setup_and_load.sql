-- ============================================
-- IPL Analysis Project — Database Setup & Load
-- ============================================

CREATE DATABASE IF NOT EXISTS ipl_project;
USE ipl_project;

-- Table: matches (one row per IPL match)
CREATE TABLE matches (
    id INT PRIMARY KEY,
    season VARCHAR(20),
    city VARCHAR(100),
    date DATE,
    match_type VARCHAR(20),
    player_of_match VARCHAR(100),
    venue VARCHAR(200),
    team1 VARCHAR(100),
    team2 VARCHAR(100),
    toss_winner VARCHAR(100),
    toss_decision VARCHAR(10),
    winner VARCHAR(100),
    result VARCHAR(20),
    result_margin FLOAT,
    target_runs FLOAT,
    target_overs FLOAT,
    super_over VARCHAR(5),
    method VARCHAR(10),
    umpire1 VARCHAR(50),
    umpire2 VARCHAR(50)
);

-- Table: deliveries (one row per ball bowled)
CREATE TABLE deliveries (
    delivery_id INT AUTO_INCREMENT PRIMARY KEY,
    match_id INT,
    inning INT,
    batting_team VARCHAR(50),
    bowling_team VARCHAR(50),
    over_num INT,
    ball INT,
    batter VARCHAR(50),
    bowler VARCHAR(50),
    non_striker VARCHAR(50),
    batsman_runs INT,
    extra_runs INT,
    total_runs INT,
    extras_type VARCHAR(20),
    is_wicket INT,
    player_dismissed VARCHAR(50),
    dismissal_kind VARCHAR(30),
    fielder VARCHAR(50),
    FOREIGN KEY (match_id) REFERENCES matches(id)
);

-- Indexes to speed up GROUP BY / lookups on batter, bowler, batting_team
-- (used heavily in 03_analysis_queries.sql — Q5, Q6, Q7, Q9, Q11, Q12)
CREATE INDEX idx_deliveries_batter ON deliveries(batter);
CREATE INDEX idx_deliveries_bowler ON deliveries(bowler);
CREATE INDEX idx_deliveries_batting_team ON deliveries(batting_team);

-- Safety net: widen key columns in case an earlier version of the table
-- was created with narrower widths (no-op if already this width)
ALTER TABLE matches MODIFY venue VARCHAR(200);
ALTER TABLE matches MODIFY city VARCHAR(100);
ALTER TABLE matches MODIFY player_of_match VARCHAR(100);
ALTER TABLE matches MODIFY team1 VARCHAR(100);
ALTER TABLE matches MODIFY team2 VARCHAR(100);
ALTER TABLE matches MODIFY toss_winner VARCHAR(100);
ALTER TABLE matches MODIFY winner VARCHAR(100);

-- Load raw CSVs
-- Place matches_cleaned.csv and deliveries_cleaned.csv in the same folder
-- as this script, or update the file paths below to match your machine.
-- Note: requires local_infile enabled on your MySQL client/server
-- (SET GLOBAL local_infile = 1; if needed).

LOAD DATA LOCAL INFILE 'matches_cleaned.csv'
INTO TABLE matches
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(id, season, city, date, match_type, player_of_match, venue, team1, team2,
 toss_winner, toss_decision, winner, result, result_margin, target_runs,
 target_overs, super_over, method, umpire1, umpire2);

LOAD DATA LOCAL INFILE 'deliveries_cleaned.csv'
INTO TABLE deliveries
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(match_id, inning, batting_team, bowling_team, over_num, ball, batter,
 bowler, non_striker, batsman_runs, extra_runs, total_runs, extras_type,
 is_wicket, player_dismissed, dismissal_kind, fielder);

-- Sanity check: row counts after load
SELECT COUNT(*) AS matches_row_count FROM matches;
SELECT COUNT(*) AS deliveries_row_count FROM deliveries;