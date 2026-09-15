-- ============================================
-- IPL Analysis Project — Analysis Queries (14)
-- ============================================
USE ipl_project;

-- ============ TIER 1: BASIC ============

-- Q1: How many matches has each team won overall?
SELECT winner_clean AS team, COUNT(*) AS total_wins
FROM matches_clean
WHERE winner_clean IS NOT NULL
GROUP BY winner_clean
ORDER BY total_wins DESC;

-- Q2: Which venues have hosted the most matches?
SELECT venue, COUNT(*) AS matches_hosted
FROM matches
GROUP BY venue
ORDER BY matches_hosted DESC
LIMIT 10;

-- Q3: How many matches were won batting first vs fielding first?
-- Logic: compare toss_winner/toss_decision against the actual match winner
-- to infer whether the winner batted first or chased.
-- Rows where toss_decision is NULL (or any other unexpected value) are
-- bucketed into 'Unknown' explicitly, rather than silently forming a
-- NULL group in the GROUP BY.
SELECT 
    CASE 
        WHEN toss_winner = winner AND toss_decision = 'bat'    THEN 'Batted First'
        WHEN toss_winner = winner AND toss_decision = 'field'  THEN 'Chased'
        WHEN toss_winner <> winner AND toss_decision = 'bat'   THEN 'Chased'
        WHEN toss_winner <> winner AND toss_decision = 'field' THEN 'Batted First'
        ELSE 'Unknown'
    END AS winning_method,
    COUNT(*) AS total_matches
FROM matches
WHERE winner IS NOT NULL
GROUP BY winning_method;

-- Q4: Which players have won "Player of the Match" the most times?
SELECT player_of_match, COUNT(*) AS awards
FROM matches
GROUP BY player_of_match
ORDER BY awards DESC
LIMIT 10;

-- ============ TIER 2: JOINS (matches + deliveries) ============

-- Q5: Top 10 run scorers of all time
SELECT batter, SUM(batsman_runs) AS total_runs
FROM deliveries
GROUP BY batter
ORDER BY total_runs DESC
LIMIT 10;

-- Q6: Top 10 wicket takers of all time
-- Only dismissal kinds credited to the bowler are counted:
-- bowled, caught, lbw, stumped, caught and bowled, hit wicket.
-- Run outs, retired hurt/out, and obstructing the field are excluded,
-- since those aren't wickets taken by the bowler.
SELECT bowler, COUNT(*) AS total_wickets
FROM deliveries
WHERE is_wicket = 1
  AND dismissal_kind IN ('bowled', 'caught', 'lbw', 'stumped', 'caught and bowled', 'hit wicket')
GROUP BY bowler
ORDER BY total_wickets DESC
LIMIT 10;

-- Q7: Which team has the highest total runs scored across all matches?
SELECT tm.canonical_name AS team, SUM(d.total_runs) AS runs_scored
FROM deliveries d
LEFT JOIN team_name_mapping tm ON d.batting_team = tm.raw_name
GROUP BY tm.canonical_name
ORDER BY runs_scored DESC
LIMIT 10;

-- Q8: What is the average first-innings score per season?
SELECT m.season, AVG(inning_totals.first_innings_score) AS avg_first_innings_score
FROM (
    SELECT match_id, SUM(total_runs) AS first_innings_score
    FROM deliveries
    WHERE inning = 1
    GROUP BY match_id
) AS inning_totals
JOIN matches m ON inning_totals.match_id = m.id
GROUP BY m.season
ORDER BY m.season;

-- ============ TIER 3: ADVANCED (subqueries, CTEs, window functions) ============

-- Q9: Which batsman has the best strike rate (min 500 balls faced)?
-- Strike rate = (total runs / balls faced) * 100.
-- Wides are excluded from "balls faced" since they aren't legal deliveries
-- the batter had a chance to play. Byes/leg byes/no-balls are still counted
-- as balls faced, since the batter did face those deliveries.
WITH batter_stats AS (
    SELECT 
        batter,
        SUM(batsman_runs) AS total_runs,
        COUNT(*) AS balls_faced
    FROM deliveries
    WHERE extras_type IS NULL OR extras_type <> 'wides'
    GROUP BY batter
)
SELECT 
    batter,
    total_runs,
    balls_faced,
    ROUND((total_runs / balls_faced) * 100, 2) AS strike_rate
FROM batter_stats
WHERE balls_faced >= 500
ORDER BY strike_rate DESC
LIMIT 10;

-- Q10: Rank teams by win percentage each season
WITH team_matches AS (
    SELECT season, team1_clean AS team FROM matches_clean
    UNION ALL
    SELECT season, team2_clean AS team FROM matches_clean
),
matches_played AS (
    SELECT season, team, COUNT(*) AS played
    FROM team_matches
    WHERE team IS NOT NULL
    GROUP BY season, team
),
wins AS (
    SELECT season, winner_clean AS team, COUNT(*) AS won
    FROM matches_clean
    WHERE winner_clean IS NOT NULL
    GROUP BY season, winner_clean
)
SELECT 
    mp.season,
    mp.team,
    mp.played,
    COALESCE(w.won, 0) AS won,
    ROUND(COALESCE(w.won, 0) / mp.played * 100, 2) AS win_pct,
    RANK() OVER (PARTITION BY mp.season ORDER BY COALESCE(w.won, 0) / mp.played DESC) AS season_rank
FROM matches_played mp
LEFT JOIN wins w ON mp.season = w.season AND mp.team = w.team
ORDER BY mp.season, season_rank;

-- Q11: Each team's highest individual score by a player in a single match
WITH player_match_scores AS (
    SELECT match_id, batting_team, batter, SUM(batsman_runs) AS runs_in_match
    FROM deliveries
    GROUP BY match_id, batting_team, batter
),
ranked AS (
    SELECT *,
        RANK() OVER (PARTITION BY batting_team ORDER BY runs_in_match DESC) AS rnk
    FROM player_match_scores
)
SELECT batting_team, batter, match_id, runs_in_match
FROM ranked
WHERE rnk = 1
ORDER BY runs_in_match DESC;

-- Q12: Which bowler has the best economy rate in death overs (16-20),
-- minimum 300 balls bowled?
-- Note: over_num in this dataset is 0-indexed (0-19), so "cricket overs
-- 16 to 20" correspond to over_num values 15 to 19.
WITH death_over_stats AS (
    SELECT bowler,
        SUM(total_runs) AS runs_conceded,
        COUNT(*) AS balls_bowled
    FROM deliveries
    WHERE over_num BETWEEN 15 AND 19
    GROUP BY bowler
)
SELECT bowler, runs_conceded, balls_bowled,
    ROUND((runs_conceded / balls_bowled) * 6, 2) AS economy_rate
FROM death_over_stats
WHERE balls_bowled >= 300
ORDER BY economy_rate ASC
LIMIT 10;

-- Q13: Running total of runs scored by a specific team across a season
-- (Example: Mumbai Indians, 2019 season)
SELECT 
    m.date,
    m.id AS match_id,
    match_runs.team_runs,
    SUM(match_runs.team_runs) OVER (ORDER BY m.date, m.id) AS running_total
FROM matches m
JOIN (
    SELECT match_id, batting_team, SUM(total_runs) AS team_runs
    FROM deliveries
    WHERE batting_team = 'Mumbai Indians'
    GROUP BY match_id, batting_team
) AS match_runs ON m.id = match_runs.match_id
WHERE m.season = '2019'
ORDER BY m.date, m.id;

-- Q14: Head-to-head record between two teams
-- (Example: Mumbai Indians vs Chennai Super Kings)
SELECT 
    winner_clean AS winning_team,
    COUNT(*) AS wins
FROM matches_clean
WHERE (team1_clean = 'Mumbai Indians' AND team2_clean = 'Chennai Super Kings')
   OR (team1_clean = 'Chennai Super Kings' AND team2_clean = 'Mumbai Indians')
GROUP BY winner_clean;