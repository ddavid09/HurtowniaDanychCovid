DECLARE @nazwa_tabeli nvarchar(max)
DECLARE @nazwa_pliku_csv nvarchar(max)

SET @nazwa_tabeli = 'csse_covid_19_time_series_confirmed_stage'
SET @nazwa_pliku_csv = 'covid_19_time_series_confirmed.csv'



BULK INSERT csse_covid_19_time_series_recovered_stage
FROM 'C:\ssis_hd_temp\covid_19_time_series_recovered.csv'
WITH(FIRSTROW = 2,
	CODEPAGE = 'RAW',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR='0x0A',
	ERRORFILE = 'C:\ssis_hd_temp\Errors\recovered-ErrorRows.csv',
    TABLOCK)
GO

IF @@ROWCOUNT = 0
	BULK INSERT csse_covid_19_time_series_recovered_stage
	FROM 'C:\ssis_hd_temp\covid_19_time_series_recovered.csv'
WITH(FIRSTROW = 2,
	CODEPAGE = 'RAW',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR='0x0A',
	ERRORFILE = 'C:\ssis_hd_temp\Errors\recovered-ErrorRows.csv',
    TABLOCK)
GO

EXEC dbo.utworz_tabele_stage @nazwa_tabeli = 'csse_covid_19_time_series_recovered_stage', @nazwa_pliku_csv = 'covid_19_time_series_recovered.csv', @liczba_kolumn_daty = 150

INSERT INTO stage_tempo_fact
(CZAS, GEOGRAFIA, LICZBA_ZAKAZENI_OGOLEM, LICZBA_ZGONOW_OGOLEM, LICZBA_WYLECZONYCH_OGOLEM, LICZBA_ZAKAZONYCH_NA_DZIS, NUMER_KOLEJNY_DNIA)
SELECT
'2020-01-22',
C.[Country/Region],
CONFIRMED,
DEATHS,
RECOVERED,
(CONFIRMED - (DEATHS + RECOVERED)),
0
FROM
(SELECT 
[Country/Region],
SUM([2020-01-22]) AS CONFIRMED
FROM csse_covid_19_time_series_confirmed_stage
GROUP BY ([Country/Region]) AS C
INNER JOIN 
(SELECT 
[Country/Region],
SUM([2020-01-22]) AS RECOVERED
FROM csse_covid_19_time_series_recovered_stage
GROUP BY ([Country/Region]) AS R
ON C.[Country/Region] = R.[Country/Region]
INNER JOIN
(SELECT 
[Country/Region],
SUM([2020-01-22]) AS DEATHS
FROM csse_covid_19_time_series_deaths_stage
GROUP BY [Country/Region]) AS D
ON C.[Country/Region] = D.[Country/Region]