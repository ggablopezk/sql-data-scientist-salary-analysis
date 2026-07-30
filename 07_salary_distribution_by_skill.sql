/*
QUESTION 7 — What does the salary DISTRIBUTION look like per skill, not just the average?
Returns the 25th percentile, median and 75th percentile of yearly salary for every
skill backed by more than 50 postings.

TECHNIQUE: PERCENTILE_CONT, an ordered-set aggregate. Unlike LAG() it is not a
window function - it collapses rows like AVG() does, hence the GROUP BY.
HAVING COUNT(...) > 50 filters GROUPS after aggregation (a WHERE could not do this),
which is exactly what question 6 was missing.

WHY IT MATTERS: the average sits above the median for essentially every skill here,
which means the distribution is right-skewed - a few very high salaries pull the
average up. The P25-P75 band shows the range a realistic offer falls into.

KNOWN ARTEFACTS:
  - Percentiles are not rounded, so values inherit float noise from salary_year_avg
    (e.g. 99516.359375). ROUND(..., 0) or a ::numeric cast would clean this up.
  - 'sas' and 'mongodb' each appear twice, with identical figures, because
    skills_dim holds two skill_id values for those names. See README.
*/

SELECT 
    sd.skill_id,
    sd.skills,
    COUNT (sj.job_id) AS demand_count,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY salary_year_avg) AS p25_salary,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY salary_year_avg) AS median_salary,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY salary_year_avg) AS p75_salary
FROM job_postings_fact jpf
        INNER JOIN skills_job_dim sj
                    ON jpf.job_id = sj.job_id
        INNER JOIN skills_dim sd
                    ON sj.skill_id = sd.skill_id
WHERE job_title_short = 'Data Scientist'
      AND salary_year_avg IS NOT NULL
GROUP BY sd.skill_id, sd.skills
HAVING COUNT (sj.job_id) > 50
ORDER BY median_salary DESC
