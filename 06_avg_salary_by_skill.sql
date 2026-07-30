/*
QUESTION 6 — Which skills carry the highest average salary?
Averages salary_year_avg per skill and returns the top 20.

TECHNIQUE: AVG() aggregation over a many-to-many join.

THIS QUERY IS KEPT IN THE PROJECT AS A DELIBERATE COUNTER-EXAMPLE.
It has no minimum-volume filter, so the ranking is dominated by skills that
appear in a handful of postings (asana, airtable, redhat, lua...). The numbers
are arithmetically correct and analytically useless. Question 7 is the fix.
*/

SELECT 
    sd.skills,
    ROUND(AVG(salary_year_avg),0) AS avg_salary
FROM job_postings_fact jpf
INNER JOIN skills_job_dim sj
            ON jpf.job_id = sj.job_id
INNER JOIN skills_dim sd
            ON sj.skill_id = sd.skill_id
WHERE jpf.job_title_short = 'Data Scientist' 
      AND salary_year_avg IS NOT NULL
GROUP BY sd.skills
ORDER BY avg_salary DESC
LIMIT 20
