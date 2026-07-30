/*
QUESTION 2 — Which skills does the market ask for most often in Data Scientist roles?
Counts how many DISTINCT postings mention each skill, across ALL postings (with
or without a disclosed salary), and keeps the top 5.

TECHNIQUE: many-to-many join through the skills_job_dim bridge table + GROUP BY,
with a DISTINCT step to collapse duplicate skill_ids that share the same name
before counting.

WHY THE DISTINCT: skills_dim stores some skill names under more than one
skill_id (sas, mongodb, ruby, firebase confirmed so far). Grouping by skill
NAME (as this query does) without deduplicating first means a posting linked
to both ids of the same name gets counted twice for that skill. See
00_data_quality_checks.sql and the README's Data Quality section for the
cross-check that surfaced this.
*/

WITH job_skill AS (
    SELECT DISTINCT
        sj.job_id,
        sd.skills
    FROM skills_job_dim sj
    INNER JOIN skills_dim sd ON sj.skill_id = sd.skill_id
    INNER JOIN job_postings_fact jpf ON sj.job_id = jpf.job_id
    WHERE jpf.job_title_short = 'Data Scientist'
)

SELECT
    skills,
    COUNT(*) AS demand_count
FROM job_skill
GROUP BY skills
ORDER BY demand_count DESC
LIMIT 5
