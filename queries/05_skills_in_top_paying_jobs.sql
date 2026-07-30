/*
QUESTION 5 — What skills do the 10 highest-paying remote postings actually ask for?
Takes the top 10 from the previous question and attaches their skill list.

TECHNIQUE: CTE reused as a filtered base + join through the bridge table.

CAVEAT: the INNER JOIN silently drops any of those 10 postings that list no
skills at all. 7 of the 10 survive — a reminder that a top-10 by pay is a
sample of 10, far too small to generalise from. Questions 6-8 handle this properly.
*/

WITH top_DS_paying_jobs AS (
        SELECT 
            job_id,
            job_title_short,
            ROUND(salary_year_avg,0) AS avg_yearly_salary
        FROM job_postings_fact
        WHERE job_location = 'Anywhere' 
            AND job_title_short = 'Data Scientist'
            AND salary_year_avg IS NOT NULL
        ORDER BY salary_year_avg DESC
        LIMIT 10
        )
SELECT 
        tpj.*,
        sd.skills
FROM top_DS_paying_jobs tpj
INNER JOIN skills_job_dim sj
            ON tpj.job_id = sj.job_id
INNER JOIN skills_dim sd
            ON sj.skill_id = sd.skill_id
