/*
QUESTION 3 — Skills are never asked for in isolation. When the #1 skill shows up
in a posting, which other skills show up next to it?

TECHNIQUE: self-join of a deduplicated (job_id, skill_name) table against itself
to build skill pairs, then GROUP BY + COUNT to turn those raw pairs into a
frequency ranking.

WHY THE DEDUPLICATION STEP: skills_dim stores some skill names under more than
one skill_id (sas, mongodb, ruby, firebase confirmed so far — see
00_data_quality_checks.sql). A plain self-join over skills_job_dim/skills_dim
would generate more than one row per posting for those skills, inflating their
co-occurrence counts by roughly 2x. Collapsing to (job_id, skill NAME) with
DISTINCT before the join removes the duplication at its source, and also makes
skill names unique per posting again — so a simple <> is enough for both the
"different skill" and (implicitly) the "no reversed duplicate pair" conditions,
without needing an ordering trick like skill_id < skill_id.

The anchor skill is NOT hard-coded: the scalar subquery computes the most
in-demand skill at runtime, from the same deduplicated table, and pins it to
the js1 side.
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
    js1.skills AS skill_a,
    js2.skills AS skill_b,
    COUNT(*) AS co_occurrence_count
FROM job_skill js1
    INNER JOIN job_skill js2 ON js1.job_id = js2.job_id AND js1.skills <> js2.skills
WHERE js1.skills = (
    SELECT js.skills
    FROM job_skill js
    GROUP BY js.skills
    ORDER BY COUNT(*) DESC
    LIMIT 1
)
GROUP BY js1.skills, js2.skills
ORDER BY co_occurrence_count DESC
