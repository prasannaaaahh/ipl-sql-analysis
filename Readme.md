# IPL Data Analysis with SQL


**Dataset:**  [IPL Complete Dataset (2008-2024) - Kaggle](https://www.kaggle.com/datasets/patrickb1912/ipl-complete-dataset-20082020)


A SQL project analyzing 15 seasons of IPL (Indian Premier League) cricket data,
covering team performance, player stats, and match trends - using MySQL,
progressing from basic aggregation to CTEs and window functions. 

## Dataset Explanation

Two raw tables sourced from a public IPL dataset (Kaggle):
- **matches** - one row per match (teams, venue, toss, result, player of the match, etc.)
- **deliveries** - one row per ball bowled (batter, bowler, runs, wicket info, etc.)

## Data Cleaning

The raw data had inconsistent team names. Several IPL franchises were rebranded
over the years (e.g. **Delhi Daredevils → Delhi Capitals**, **Kings XI Punjab →
Punjab Kings**), so the same real-world team appears under multiple string values.
Left un-cleaned, this silently splits one team's stats across several rows and,
worse, causes `NULL`s and dropped rows on any `WHERE ... IS NOT NULL` filter.

To fix this, I built a `team_name_mapping` lookup table (20 raw names → 15
canonical franchises) and a `matches_clean` view that resolves every team-related
column to its current name. Note that this only merges genuine **rebrands**.
Teams that were discontinued and replaced by a new franchise in the same city
(e.g. Deccan Chargers → Sunrisers Hyderabad, Pune Warriors → Rising Pune
Supergiant) are kept as separate teams, since they're different ownership groups,
not the same team renamed.

I also found and fixed a smaller issue: 5 matches had `winner` stored as an
empty string (`''`) instead of `NULL` for no-result games, which `IS NULL`
checks were silently missing.

**Known limitation:** Venue names have similar minor duplicates (e.g. "Wankhede
Stadium" vs "Wankhede Stadium, Mumbai") that were not normalized for this
project. The same mapping-table approach used for teams could be extended
to venues.

## Files

| File | Purpose |
|---|---|
| `01_setup_and_load.sql` | Creates `matches` and `deliveries` tables, adds indexes, loads raw CSVs |
| `02_team_name_cleaning.sql` | Builds the team name mapping table and `matches_clean` view |
| `03_analysis_queries.sql` | All 14 analysis queries, in three tiers of difficulty |


## How to Run

1. Download `matches.csv` and `deliveries.csv` from the Kaggle dataset linked above.
2. Place them in the same folder as `00_data_cleaning.ipynb` and run it. This produces `matches_cleaned.csv` and `deliveries_cleaned.csv`.
3. Move those two cleaned CSVs into the same folder as the SQL scripts.
4. `local_infile` must be enabled on **both** sides, not just the server:
   - Server: `SET GLOBAL local_infile = 1;`
   - Client: connect with `--local-infile=1` (e.g. `mysql --local-infile=1 -u root -p`)
5. Run the scripts in order:


## Analysis Questions

**Tier 1 - Basic (single table, aggregation)**
1. Matches won by each team
2. Venues that hosted the most matches
3. Matches won batting first vs. chasing
4. Most Player of the Match awards

**Tier 2 - Intermediate (joins between matches + deliveries)**

5. Top 10 run scorers of all time
6. Top 10 wicket takers of all time (run-outs excluded - not a bowler's wicket)
7. Team with the highest total runs scored across all matches
8. Average first-innings score per season


**Tier 3 - Advanced (subqueries, CTEs, window functions)**

9. Best strike rate, minimum 500 balls faced
10. Teams ranked by win percentage, per season (`RANK() OVER PARTITION BY`)
11. Each team's highest individual score by a player in a single match
12. Best death-overs (16–20) economy rate, minimum 300 balls bowled
13. Running total of runs for a team across a season (`SUM() OVER`)
14. Head-to-head record between two teams


## Key Findings

- **Mumbai Indians** and **Chennai Super Kings** lead in total match wins, with
  144 and 138 respectively.
- Matches are won more often by the team **chasing** (590) than batting first
  (500) - consistent with IPL's general trend toward favoring the chase.
- **Eden Gardens** is the most-used venue across all seasons (77 matches).
- **AB de Villiers** holds the most Player of the Match awards (25).

## Tools

MySQL 8 / MySQL Workbench