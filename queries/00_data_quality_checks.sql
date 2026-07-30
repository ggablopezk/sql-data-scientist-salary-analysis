/*
DATA QUALITY CHECKS
Run these before trusting any skill-level aggregation in this project.
They are what surfaced the duplicate-skill issue documented in the README.
*/

-- CHECK 1: does the same skill name exist under more than one skill_id?
SELECT skills, COUNT(*) AS id_count
FROM skills_dim
GROUP BY skills
HAVING COUNT(*) > 1;

-- CHECK 2: which ids exactly, side by side?
SELECT skill_id, skills
FROM skills_dim
WHERE skills IN (
    SELECT skills
    FROM skills_dim
    GROUP BY skills
    HAVING COUNT(*) > 1
)
ORDER BY skills, skill_id;

-- CHECK 3: are duplicated rows present in the bridge table itself?
SELECT job_id, skill_id, COUNT(*) AS repetitions
FROM skills_job_dim
GROUP BY job_id, skill_id
HAVING COUNT(*) > 1;

-- CHECK 4: is a single posting linked to BOTH duplicate ids of the same skill?
-- If this returns a high count, any query grouping by skill NAME double-counts it.
SELECT COUNT(DISTINCT a.job_id) AS jobs_linked_to_both_ids
FROM skills_job_dim a
INNER JOIN skills_job_dim b ON a.job_id = b.job_id
INNER JOIN skills_dim sa ON a.skill_id = sa.skill_id
INNER JOIN skills_dim sb ON b.skill_id = sb.skill_id
WHERE sa.skills = sb.skills
  AND a.skill_id < b.skill_id;
