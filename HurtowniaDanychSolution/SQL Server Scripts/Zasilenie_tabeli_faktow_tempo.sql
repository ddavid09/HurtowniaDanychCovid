USE CovidHurtowniaDanych
GO

DROP TABLE IF EXISTS #process_confirmed_table
SELECT * INTO #process_confirmed_table FROM dbo.csse_covid_19_time_series_confirmed_stage 
ALTER TABLE #process_confirmed_table DROP COLUMN [Province/State]
ALTER TABLE #process_confirmed_table DROP COLUMN [Lat]
ALTER TABLE #process_confirmed_table DROP COLUMN [Long]

DROP TABLE IF EXISTS #process_recovered_table
SELECT * INTO #process_recovered_table FROM dbo.csse_covid_19_time_series_recovered_stage 
ALTER TABLE #process_recovered_table DROP COLUMN [Province/State]
ALTER TABLE #process_recovered_table DROP COLUMN [Lat]
ALTER TABLE #process_recovered_table DROP COLUMN [Long]

DROP TABLE IF EXISTS #process_deaths_table
SELECT * INTO #process_deaths_table FROM dbo.csse_covid_19_time_series_deaths_stage 
ALTER TABLE #process_deaths_table DROP COLUMN [Province/State]
ALTER TABLE #process_deaths_table DROP COLUMN [Lat]
ALTER TABLE #process_deaths_table DROP COLUMN [Long]

--zagregowane przypadki CONFIRMED|RECOVERED|DEATHS wg krajow dla zadanej daty
SELECT
C.[Country/Region],
CONFIRMED,
DEATHS,
RECOVERED
INTO #process_fact
FROM
(SELECT 
[Country/Region],
SUM([2020-05-23]) AS CONFIRMED
FROM #process_confirmed_table
GROUP BY [Country/Region]) AS C
INNER JOIN 
(SELECT 
[Country/Region],
SUM([2020-05-23]) AS RECOVERED
FROM #process_recovered_table
GROUP BY [Country/Region]) AS R
ON C.[Country/Region] = R.[Country/Region]
INNER JOIN
(SELECT 
[Country/Region],
SUM([2020-05-23]) AS DEATHS
FROM #process_deaths_table
GROUP BY [Country/Region]) AS D
ON C.[Country/Region] = D.[Country/Region]
ORDER BY CONFIRMED DESC

--miary
--liczba zakazonych na dany dzien
ALTER TABLE #process_fact ADD INFECTED_ON_THAT_DAY AS (CONFIRMED - (DEATHS + RECOVERED))


SELECT * FROM #process_fact

--Utworzenie tymczasowej tabeli faktow
DROP TABLE IF EXISTS #fact_tempo
SELECT * INTO #fact_tempo FROM dbo.TEMPO_WIRUSA_SUM WHERE 1 = 0

--data jako parametr procedury i procedura przechodzi po kazdym wierszu tabeli zagregowanej
SELECT * FROM #fact_tempo






