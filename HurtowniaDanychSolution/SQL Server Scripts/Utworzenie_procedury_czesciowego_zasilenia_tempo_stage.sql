--procesdura skladowana
--zaladowanie danych
--CZAS_ID|GEOGRAFIA_ID|LICZBA_ZAKAZENIE_OGOLEM|LICZBA ZGONOW OGOLEM|LICZBA_WYLECZONYCH_OGOLEM|LICZBA_ZAKAZONYCH_NA_DZIS
--do stage 
--z wybranego dnia (kolumny)

GO
DROP PROCEDURE IF EXISTS dbo.zasil_tempo_stage_confirmed_recovered_deaths_onthatday
GO

CREATE PROC dbo.zasil_tempo_stage_confirmed_recovered_deaths_onthatday

@data DATE

AS

DECLARE @date nvarchar(10);
SET @date = @data;

DECLARE @sqlText nvarchar(max)
SET @sqlText =
N'INSERT INTO stage_tempo_fact
(CZAS_ID, GEOGRAFIA_ID, LICZBA_ZAKAZENI_OGOLEM, LICZBA_ZGONOW_OGOLEM, LICZBA_WYLECZONYCH_OGOLEM, LICZBA_ZAKAZONYCH_NA_DZIS, NUMER_KOLEJNY_DNIA)
SELECT 
ISNULL(C.CZAS_ID, 0),
ISNULL(G.GEOGRAFIA_ID, 0),
ISNULL(P.CONFIRMED, 0),
ISNULL(P.DEATHS, 0),
ISNULL(P.RECOVERED, 0),
ISNULL(P.INFECTED_ON_THAT_DAY, 0),
NUMER_KOLEJNY_DNIA = 0
FROM 
(SELECT
'''+ @date + ''' AS [DATE],
C.[Country/Region],
CONFIRMED,
DEATHS,
RECOVERED,
(CONFIRMED - (DEATHS + RECOVERED)) AS INFECTED_ON_THAT_DAY
FROM
(SELECT 
[Country/Region],
SUM([' + @date + ']) AS CONFIRMED
FROM csse_covid_19_time_series_confirmed_stage
GROUP BY [Country/Region]) AS C
INNER JOIN 
(SELECT 
[Country/Region],
SUM([' + @date + ']) AS RECOVERED
FROM csse_covid_19_time_series_recovered_stage
GROUP BY [Country/Region]) AS R
ON C.[Country/Region] = R.[Country/Region]
INNER JOIN
(SELECT 
[Country/Region],
SUM([' + @date + ']) AS DEATHS
FROM csse_covid_19_time_series_deaths_stage
GROUP BY [Country/Region]) AS D
ON C.[Country/Region] = D.[Country/Region]) AS P
INNER JOIN CZAS_DIM AS C ON P.[DATE] = C.[DATA]
INNER JOIN GEOGRAFIA_DIM AS G ON P.[Country/Region] = G.KRAJ;'

EXEC sp_executesql @sqlText;
GO