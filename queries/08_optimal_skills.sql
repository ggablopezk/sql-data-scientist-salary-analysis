/*
QUESTION 8 — Which skills are worth learning? "Optimal" = high demand AND high pay.
Brings demand and salary together in a single table, restricted to skills with
more than 10 salaried postings.

TECHNIQUE: two independent CTEs (one for demand, one for pay) joined on skill_id.
Building each metric as its own reusable block keeps the logic readable and avoids
writing the same aggregation twice.

NOTES:
  - GROUP BY sd.skill_id alone is valid here even though sd.skills is selected:
    Postgres allows it because skills is functionally dependent on the primary key
    of skills_dim. Other engines would reject this.
  - 'sas' appears twice for the duplicate-skill_id reason described in the README.
*/

WITH skills_demand AS (
        SELECT 
            sd.skill_id,
            sd.skills,
            COUNT (sj.job_id) AS demand_count
        FROM job_postings_fact jpf
        INNER JOIN skills_job_dim sj
                    ON jpf.job_id = sj.job_id
        INNER JOIN skills_dim sd
                    ON sj.skill_id = sd.skill_id
        WHERE jpf.job_title_short = 'Data Scientist'
            AND salary_year_avg IS NOT NULL
        GROUP BY sd.skill_id
        ), avg_salary AS(
        SELECT 
            sd.skill_id,
            sd.skills,
            ROUND(AVG(salary_year_avg),0) AS avg_salary
        FROM job_postings_fact jpf
        INNER JOIN skills_job_dim sj
                    ON jpf.job_id = sj.job_id
        INNER JOIN skills_dim sd
                    ON sj.skill_id = sd.skill_id
        WHERE jpf.job_title_short = 'Data Scientist' 
            AND salary_year_avg IS NOT NULL
        GROUP BY sd.skill_id
        )

SELECT
    ss.skill_id,
    ss.skills,
    demand_count,
    avg_salary
FROM
    skills_demand ss
INNER JOIN avg_salary a ON ss.skill_id = a.skill_id
WHERE demand_count > 10
ORDER BY demand_count DESC, avg_salary DESC
LIMIT 20;
