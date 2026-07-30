# Mercado laboral de Data Scientist — Un análisis en SQL

*[Read in English](README.md)*

Una exploración del mercado laboral de datos en 2023, para roles de **Data Scientist**, usando
PostgreSQL: cómo evolucionó la demanda a lo largo del año, qué skills pide realmente el mercado,
cómo se combinan entre sí, y dónde se cruzan la demanda y el salario. En el camino apareció un
problema de calidad de datos que cambió dos de los resultados — está documentado en vez de
escondido, porque encontrarlo fue la parte más interesante del trabajo.

## Preguntas

| # | Pregunta | Técnica |
|---|---|---|
| 1 | ¿La demanda creció o cayó durante 2023? | `DATE_TRUNC` + `LAG()` |
| 2 | ¿Qué skills se piden con más frecuencia? | deduplicación + `GROUP BY` |
| 3 | ¿Qué skills se piden junto a la skill top? | self-join + subquery escalar |
| 4 | ¿Qué publicaciones remotas pagan más? | filtro + `ORDER BY` |
| 5 | ¿Qué skills piden esas publicaciones mejor pagas? | CTE como base filtrada |
| 6 | ¿Cuál es el salario promedio más alto por skill? | `AVG()` — y por qué la respuesta engaña |
| 7 | ¿Cómo es la *distribución* real del salario? | `PERCENTILE_CONT` + `HAVING` |
| 8 | ¿Alta demanda **y** alto salario? | dos CTEs combinadas |

Las preguntas 6 → 7 → 8 están pensadas para leerse en orden: la 6 hace una pregunta ingenua, la 7
la corrige, la 8 combina el resultado con la demanda.

## Datos

Dataset público de ~787.000 publicaciones de empleo, de diciembre de 2022 a fines de 2023,
repartidas en tres tablas:

- `job_postings_fact` — una fila por publicación
- `skills_dim` — catálogo de skills
- `skills_job_dim` — tabla puente (relación muchos a muchos entre publicaciones y skills)

El recorte es `job_title_short = 'Data Scientist'`. Las preguntas de salario usan solo
publicaciones donde `salary_year_avg IS NOT NULL` — más o menos 1 de cada 25.

---

## Hallazgos

### 1. La demanda estuvo estancada o en baja durante 2023

![Tendencia mensual](assets/01_monthly_trend.png)

Enero arranca con ~20.900 publicaciones y diciembre cierra en ~11.900 — una caída del 43% a lo
largo del año. No es una línea recta: febrero solo ya cae 33%, la mitad del año oscila en una
banda de ±20% alrededor de ~13.500/mes, y agosto tiene un pico de +20%.

El salto de 4.882% que aparece entre diciembre 2022 y enero 2023 es un artefacto: diciembre 2022
tiene solo 419 publicaciones, un mes parcial en el borde del scrape. Se excluye de la lectura de
tendencia.

<details>
<summary>Ver SQL — <code>01_market_trend_monthly.sql</code></summary>

```sql
WITH monthly_count AS (
    SELECT 
        DATE_TRUNC('month',job_posted_date)::date AS month_posted,
        COUNT(job_id) AS job_count
    FROM job_postings_fact
    WHERE job_title_short = 'Data Scientist'
    GROUP BY month_posted 
    ORDER BY month_posted ASC
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
```
</details>

### 2. Python, SQL y R son innegociables — AWS le gana a SAS por el puesto #5

![Top skills en demanda](assets/02_top_demand_skills.png)

Python lidera con 114.016 publicaciones, seguido de SQL (79.174) y R (59.754) — casi 4× de
diferencia hasta el puesto #4. Tableau (29.513) y **AWS (26.311)** cierran el top 5.

En un principio parecía que SAS ocupaba el 5° lugar con 29.642 — no es así. Ver
[Calidad de datos](#calidad-de-datos-ids-de-skill-duplicados) más abajo.

<details>
<summary>Ver SQL — <code>02_most_in_demand_skills.sql</code></summary>

```sql
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
```
</details>

### 3. Python es un centro de conexión, no una skill aislada

![Co-ocurrencia con Python](assets/03_python_cooccurrence.png)

66.973 publicaciones que piden Python también piden SQL; 56.128 también piden R. Python casi
siempre se pide en combinación con otras cosas. Aparecen dos clusters: un **stack de analytics**
(SQL, R, Tableau) y un **stack de ingeniería de datos/ML** (AWS, Spark, Azure, TensorFlow, Hadoop)
— ambos anclados a Python.

<details>
<summary>Ver SQL — <code>03_skill_co_occurrence.sql</code></summary>

```sql
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
```
</details>

### 4–5. Las publicaciones mejor pagas dicen muy poco

El salario remoto más alto del recorte es $550.000/año (SQL + Python), seguido de $525.000 — que
pide como única skill requerida a SQL, nada más. Del verdadero top 10, 7 tienen alguna skill
listada (el join descarta el resto). Es una muestra de 10. No alcanza para generalizar — que es
justo por lo que existen las preguntas 6 a 8.

<details>
<summary>Ver SQL — <code>04_top_paying_jobs.sql</code> / <code>05_skills_in_top_paying_jobs.sql</code></summary>

```sql
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
```
</details>

### 6–7. El promedio es ruido; la distribución es la respuesta real

Ordenar skills por salario promedio sin ningún piso de volumen da: asana ($215k), airtable
($201k), redhat ($189k), watson ($187k), elixir ($171k) — ninguna es realmente una skill de data
science, cada una respaldada por un puñado de publicaciones donde un solo salario atípico define
todo el promedio. Este es justo el problema que este proyecto busca mostrar.

<details>
<summary>Ver SQL — <code>06_avg_salary_by_skill.sql</code> (la versión ingenua)</summary>

```sql
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
```
</details>

Con un piso de 50+ publicaciones y mirando la distribución completa en vez de solo el promedio:

![Distribución salarial](assets/04_salary_distribution.png)

- **El promedio está por encima de la mediana en todas las skills revisadas** — Python $138k vs
  $130,5k, R $135k vs $125k, Hadoop $136k vs $126k. Los salarios están sesgados hacia arriba: unas
  pocas ofertas grandes tiran el promedio para arriba. Reportar solo el promedio sobreestima lo
  que es una oferta típica.
- La sobreestimación no es pareja — R y Hadoop se inflan ~8%, PyTorch solo 0,5%. O sea que el
  *ranking* por promedio también queda distorsionado, no solo los niveles.
- Las medianas más altas van para herramientas de infraestructura/ML: Airflow ($157k), BigQuery
  ($150k), Looker ($147,5k), PyTorch ($145k) — todas por encima de la propia mediana de Python
  ($130,5k).
- La dispersión también importa: la mayoría de las skills está en una banda de IQR de $50–60k.
  Express ($82,6k de IQR, n=89) y Shell ($73,5k, n=63) son mucho más anchas — una "mediana alta"
  ahí es mucho menos confiable que el mismo número para Python (n=4.312).

<details>
<summary>Ver SQL — <code>07_salary_distribution_by_skill.sql</code> (la corrección)</summary>

```sql
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
```
</details>

*Nota: esta query agrupa por `skill_id`, así que una skill duplicada (ver más abajo) aparece como
dos filas con números idénticos — acá es cosmético, a diferencia de la pregunta 2.*

### 8. Alto salario y alta demanda son casi independientes

![Skills óptimas](assets/05_optimal_skills.png)

Python lidera la demanda por un orden de magnitud mientras se ubica en la mitad de la tabla en
salario. El cluster realmente atractivo es **Spark, AWS, TensorFlow, PyTorch, scikit-learn** —
entre 400 y 1.000 publicaciones cada una, con promedios de $138k–$146k. Suficiente volumen para
ser un mercado real, suficiente salario para justificar aprenderlas. Excel y Power BI tienen buena
demanda pero salario débil; SAS es la más floja de las skills de alto volumen en ambos ejes.

<details>
<summary>Ver SQL — <code>08_optimal_skills.sql</code></summary>

```sql
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
```
</details>

---

## Calidad de datos: IDs de skill duplicados

Dos filas idénticas en un resultado temprano de co-ocurrencia (mismo par, mismo conteo, dos veces)
llevaron a este chequeo:

```sql
SELECT skills, COUNT(*) AS id_count
FROM skills_dim
GROUP BY skills
HAVING COUNT(*) > 1;
```

**Siete nombres de skill tienen cada uno dos valores distintos de `skill_id`:** `sas`, `mongodb`,
`ruby`, `firebase`, `powerbi`, `sqlserver`, `asp.netcore`. Las publicaciones parecen estar
vinculadas a ambos ids del mismo nombre — se confirma porque agrupar por `skill_id` produce dos
filas con cifras idénticas byte a byte (por ejemplo, `sas` muestra demanda de 615 y mediana de
$118.080 bajo dos ids distintos).

**Corrección:** una CTE `job_skill` que hace `SELECT DISTINCT job_id, skill_name` antes de
cualquier join o agregación, colapsando ambos ids en una sola fila por publicación. Se usa en las
preguntas 2 y 3.

**Resultado:** la demanda real de SAS es ~14.821, no 29.642 — sale del top 5 de skills, reemplazada
por AWS. La co-ocurrencia `python↔sas` baja de 24.478 a 12.239 (exactamente la mitad, como se
esperaba).

---

## Lo que me llevo de esto

La query más difícil de escribir (el self-join de la pregunta 3) fue también la que expuso un bug
que venía inflando la pregunta 2 desde el principio. Algunas cosas para no olvidar:

1. Un agregado sin un piso de volumen es un generador de números aleatorios — `HAVING COUNT(*) >
   50` aportó más a este análisis que cualquier window function.
2. Que el promedio y la mediana no coincidan es información, no un problema — es lo que te dice
   que una distribución está sesgada.
3. Dos filas idénticas siempre merecen que te detengas a mirar.

---

## Estructura del repo

```
sql-project-data-scientist/
├── README.md
├── README.es.md
├── queries/
│   ├── 00_data_quality_checks.sql
│   ├── 01_market_trend_monthly.sql
│   ├── 02_most_in_demand_skills.sql
│   ├── 03_skill_co_occurrence.sql
│   ├── 04_top_paying_jobs.sql
│   ├── 05_skills_in_top_paying_jobs.sql
│   ├── 06_avg_salary_by_skill.sql
│   ├── 07_salary_distribution_by_skill.sql
│   └── 08_optimal_skills.sql
└── assets/
    ├── 01_monthly_trend.png
    ├── 02_top_demand_skills.png
    ├── 03_python_cooccurrence.png
    ├── 04_salary_distribution.png
    └── 05_optimal_skills.png
```
