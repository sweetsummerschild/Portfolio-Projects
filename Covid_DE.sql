-- DEATHS
-- Deaths by Country
---- Total Deaths
SELECT
	location,
	date,
	population,
	total_cases,
	total_deaths
FROM
	covid..covid_death
ORDER BY
	1,
	2;

---- Death Percentage
SELECT
	location,
	MAX(total_cases) as total_cases,
	MAX(CAST(total_deaths AS INT)) AS total_deaths,
	MAX(CAST(total_deaths AS INT)) / MAX(total_cases) * 100 AS death_percentage
FROM
	covid..covid_death
GROUP BY
	location
/*HAVING
	 location = 'Vietnam'
	 */
ORDER BY
	1;

---- Total Cases vs Population
SELECT
	location,
	date,
	population,
	total_cases,
	ROUND(total_cases / population * 100, 5) AS infection_rate
FROM
	covid..covid_death
ORDER BY
	1,
	2;

---- Highest Infection Rate by Country
SELECT
	location,
	continent,
	population,
	MAX(total_cases) AS highest_infection_count,
	ROUND((MAX(total_cases) / population) * 100, 5) AS infection_rate
FROM
	covid..covid_death
GROUP BY
	location,
	population,
	continent
ORDER BY
	1;

---- Highest Death Count by Country
SELECT
	location,
	MAX(CAST(total_deaths AS INT)) AS highest_death_count
FROM
	covid..covid_death
GROUP BY
	location
ORDER BY
	2 DESC;

-- Deaths by Continent
/*SELECT * FROM covid..death_by_region;
 
 ALTER TABLE covid..death_by_region 
 DROP COLUMN continent;
 */
---- Total Death Count by Continent
SELECT
	location,
	MAX(CAST(total_deaths AS INT)) AS continent_death_count
FROM
	covid..death_by_region
GROUP BY
	location
HAVING
	location NOT IN ('World', 'International', 'European Union')
ORDER BY
	1;

---- Total Cases vs Total Hospitalized Patients in Europe and North America
SELECT
	location,
	population,
	MAX(CAST(total_cases AS INT)) AS total_cases_highest,
	SUM(CAST(hosp_patients AS INT)) AS total_hosp_patients
FROM
	covid..covid_death
GROUP BY
	location,
	population
HAVING
	SUM(CAST(hosp_patients AS INT)) IS NOT NULL
ORDER BY
	1;

---- Hospitalization Percentage in Europe and North America
DROP TABLE IF EXISTS #cases_hosp
CREATE TABLE #cases_hosp
(
	location VARCHAR(250),
	population INT,
	total_cases_highest INT,
	total_hosp_patients INT
)
INSERT INTO
	#cases_hosp
SELECT
	dr.location,
	dr.population,
	MAX(CAST(dr.total_cases AS INT)) AS total_cases_highest,
	SUM(CAST(dr.hosp_patients AS INT)) AS total_hosp_patients
FROM
	covid..covid_death dr
GROUP BY
	dr.location,
	dr.population
HAVING
	SUM(CAST(dr.hosp_patients AS INT)) IS NOT NULL;

SELECT
	location,
	population,
	total_cases_highest,
	total_hosp_patients,
	ROUND(
		CAST(total_hosp_patients AS FLOAT) / total_cases_highest,
		5
	) AS hosp_to_cases,
	ROUND(
		CAST(total_hosp_patients AS FLOAT) / population,
		5
	) AS hosp_to_population
FROM
	#cases_hosp
ORDER BY
	1,
	2;

---- Case Fatality Rolling Average
WITH
	case_death (
		location,
		date,
		avg_cases_weekly,
		avg_death_weekly
	)
	AS
	(
		SELECT
			location,
			date,
			AVG(CAST(total_cases AS INT)) OVER(
			ORDER BY
				date ROWS BETWEEN 6 PRECEDING
				AND CURRENT ROW
		) AS avg_cases_weekly,
			AVG(CAST(total_deaths AS INT)) OVER(
			ORDER BY
				date ROWS BETWEEN 6 PRECEDING
				AND CURRENT ROW
		) AS avg_death_weekly
		FROM
			covid..death_by_region
	WHERE location NOT IN ('World', 'International', 'European Union')
	)
SELECT
	*,
	ROUND(
		CAST(avg_death_weekly AS FLOAT) / avg_cases_weekly * 100,
		5
	) AS case_fatality
FROM
	case_death
ORDER BY
	1,
	2;

-- VACCINATIONS
---- Vaccinations by Country
---- Percentage of People Vaccinated 
SELECT
	d.location,
	d.population,
	MAX(CAST(v.people_vaccinated AS INT)) AS people_vaccinated_newest,
	(
		ROUND(
			MAX(CAST(v.people_vaccinated AS INT)) / d.population * 100,
			5
		)
	) AS people_vaccinated_percentage
FROM
	covid..covid_death d
	JOIN covid..covid_vaccination v ON d.location = v.location
		AND d.date = v.date
GROUP BY
	d.location,
	d.population
HAVING
	MAX(CAST(v.people_vaccinated AS INT)) IS NOT NULL
ORDER BY
	1,
	2;

---- Rolling Count of Vaccine Doses
SELECT
	d.continent,
	d.location,
	d.date,
	d.population,
	v.new_vaccinations,
	SUM(CAST(v.new_vaccinations AS INT)) OVER (
		PARTITION BY d.location
		ORDER BY
			d.location,
			d.date
	) AS doses_rolling
FROM
	covid..covid_death d
	JOIN covid..covid_vaccination v ON d.location = v.location
		AND d.date = v.date
WHERE
	v.new_vaccinations IS NOT NULL
ORDER BY
	2,
	3;

---- Percentage of Doses Administered by Country
WITH
	pop_vs_vac(
		location,
		population,
		new_vaccinations,
		doses_rolling
	)
	AS
	(
		SELECT
			d.location,
			d.population,
			v.new_vaccinations,
			SUM(CAST(v.new_vaccinations AS INT)) OVER (
			PARTITION BY d.location
			ORDER BY
				d.location,
				d.date
		) AS doses_rolling
		FROM
			covid..covid_death d
			JOIN covid..covid_vaccination v ON d.location = v.location
				AND d.date = v.date
	)
SELECT
	p.location,
	p.population,
	MAX(p.doses_rolling) AS total_doses,
	ROUND((MAX(p.doses_rolling) / p.population) * 100, 5) AS doses_per_population
FROM
	pop_vs_vac p
GROUP BY
	p.location,
	p.population
ORDER BY
	4 DESC;

-- Vaccinations by Continent
/*ALTER TABLE covid..vaccination_by_region 
 DROP COLUMN continent;
 */
---- Total Vaccination Doses Count
SELECT
	dr.location,
	dr.population,
	MAX(CAST(vr.total_vaccinations AS BIGINT)) AS total_doses_region
FROM
	covid..vaccination_by_region vr
	JOIN covid..death_by_region dr ON vr.date = dr.date
		AND vr.location = dr.location
GROUP BY
	dr.location,
	dr.population
HAVING
	dr.location NOT IN ('World', 'International', 'European Union')
ORDER BY
	3 DESC;

---- Percentage of People Fully Vaccinated
SELECT
	dr.location,
	dr.population,
	MAX(CAST(vr.people_fully_vaccinated AS BIGINT)) as fully_vaccinated_highest,
	ROUND(
		MAX(CAST(vr.people_fully_vaccinated AS BIGINT)) / dr.population * 100,
		5
	) AS fully_vaccinated_percentage
FROM
	covid..vaccination_by_region vr
	JOIN covid..death_by_region dr ON vr.location = dr.location
GROUP BY
	dr.location,
	dr.population
HAVING
	dr.location NOT IN ('World', 'International', 'European Union')
ORDER BY
	1;
