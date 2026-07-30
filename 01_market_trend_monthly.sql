/*
QUESTION 1 — Is demand for Data Scientists growing or shrinking over 2023?
Counts postings per month and compares each month against the previous one,
in absolute terms and as a percentage.

TECHNIQUE: DATE_TRUNC to bucket dates into months + the LAG() window function
to read the previous row's value without a self-join.

NOTE: the first row has NULL in previous_month_count / abs_var / relative_var.
That is expected, not a bug: the first month of the series has no prior month
to compare against. It is left as NULL on purpose rather than coerced to 0,
so the absence of data stays visible.
*/

WITH monthly_count AS (
    SELECT 
        DATE_TRUNC('month',job_posted_date)::date AS month_posted,
        COUNT(job_id) AS job_count
    FROM job_postings_fact
    WHERE job_title_short = 'Data Scientist'
    GROUP BY month_posted 
    ), with_lag AS (
    SELECT 
        month_posted,
        job_count,
        LAG(job_count) OVER (ORDER BY month_posted) AS previous_month_count
FROM monthly_count
    )

SELECT
    month_posted,
    job_count,
    previous_month_count,
    (job_count - previous_month_count) AS abs_var,
    ROUND(((job_count - previous_month_count)::NUMERIC/previous_month_count::NUMERIC) * 100,2) AS relative_var
FROM with_lag
ORDER BY month_posted ASC
