/*
QUESTION 4 — Which fully-remote Data Scientist postings pay the most?
Filters to remote roles ('Anywhere') that actually disclose a salary,
and ranks them from highest to lowest.

TECHNIQUE: baseline filtering + ORDER BY. The starting point of the pay analysis.

NOTE: uses exact equality (job_title_short = 'Data Scientist'), same scope as
every other query in this project — excludes 'Senior Data Scientist' postings.
There is also no LIMIT, so this returns the full ranked list rather than a top 10.
*/

SELECT 
    job_id,
    job_title_short,
    job_location,
    job_schedule_type,
    ROUND(salary_year_avg,0) AS avg_yearly_salary,
    job_posted_date::date
FROM job_postings_fact
WHERE job_location = 'Anywhere' 
     AND job_title_short = 'Data Scientist'
     AND salary_year_avg IS NOT NULL
ORDER BY salary_year_avg DESC

