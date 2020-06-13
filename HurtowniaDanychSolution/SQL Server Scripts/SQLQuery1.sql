SELECT CZAS, GEOGRAFIA, MIN(LICZBA_ZAKAZENI_OGOLEM) as lz,
ROW_NUMBER() OVER (PARTITION BY GEOGRAFIA ORDER BY CZAS) AS nkd
FROM stage_tempo_fact
WHERE LICZBA_ZAKAZENI_OGOLEM > 0
GROUP BY CZAS, GEOGRAFIA) AS pt
ON sf.CZAS = pt.CZAS AND sf.GEOGRAFIA = pt.GEOGRAFIA

--**************************
--LICZBA_NOWYCH_ZAKAZEN_DZIS
--**************************
UPDATE sf
SET sf.LICZBA_NOWYCH_ZAKAZEN_DZIS = pt.lzo - pt.zdp
FROM
stage_tempo_fact AS sf
INNER JOIN 
(SELECT CZAS, GEOGRAFIA, LICZBA_ZAKAZENI_OGOLEM AS lzo, 
LAG(LICZBA_ZAKAZENI_OGOLEM, 1, 0) 
OVER (PARTITION BY GEOGRAFIA ORDER BY CZAS) AS zdp
FROM stage_tempo_fact) AS pt
ON sf.CZAS = pt.CZAS AND sf.GEOGRAFIA = pt.GEOGRAFIA
GO

--**************************
--LICZBA_NOWYCH_ZGONOW_DZIS
--**************************
UPDATE sf
SET sf.LICZBA_NOWYCH_ZGONOW_DZIS = pt.lzgo - pt.zgdp
FROM
stage_tempo_fact AS sf
INNER JOIN 
(SELECT CZAS, GEOGRAFIA, LICZBA_ZGONOW_OGOLEM AS lzgo, 
LAG(LICZBA_ZGONOW_OGOLEM, 1, 0) 
OVER (PARTITION BY GEOGRAFIA ORDER BY CZAS) AS zgdp
FROM stage_tempo_fact) AS pt
ON sf.CZAS = pt.CZAS AND sf.GEOGRAFIA = pt.GEOGRAFIA
GO

--******************************
--LICZBA_NOWYCH_WYLECZONYCH_DZIS
--******************************
UPDATE sf
SET sf.LICZBA_NOWYCH_WYLECZONYCH_DZIS = pt.lwo - pt.wdp
FROM
stage_tempo_fact AS sf
INNER JOIN 
(SELECT CZAS, GEOGRAFIA, LICZBA_WYLECZONYCH_OGOLEM AS lwo, 
LAG(LICZBA_WYLECZONYCH_OGOLEM, 1, 0) 
OVER (PARTITION BY GEOGRAFIA ORDER BY CZAS) AS wdp
FROM stage_tempo_fact) AS pt
ON sf.CZAS = pt.CZAS AND sf.GEOGRAFIA = pt.GEOGRAFIA
GO

--****************
--DYNAMIKA_ZAKAZEN
--****************
ALTER TABLE [dbo].stage_tempo_fact 
ALTER COLUMN DYNAMIKA_ZAKAZEN decimal(12,4)

UPDATE sf
SET sf.DYNAMIKA_ZAKAZEN = CASE WHEN pt.lnzdp <> 0 THEN
CAST(CAST(pt.lnzd AS decimal(12,5))/pt.lnzdp AS decimal(12,4))
ELSE 0 END
FROM
stage_tempo_fact AS sf
INNER JOIN 
(SELECT CZAS, GEOGRAFIA, LICZBA_NOWYCH_ZAKAZEN_DZIS AS lnzd, 
LAG(LICZBA_NOWYCH_ZAKAZEN_DZIS, 1, 0) 
OVER (PARTITION BY GEOGRAFIA ORDER BY CZAS) AS lnzdp
FROM stage_tempo_fact) AS pt
ON sf.CZAS = pt.CZAS AND sf.GEOGRAFIA = pt.GEOGRAFIA
GO




SELECT CZAS, GEOGRAFIA, LICZBA_ZAKAZENI_OGOLEM, 
LAG(LICZBA_ZAKAZENI_OGOLEM, 1, 0) 
OVER (PARTITION BY GEOGRAFIA ORDER BY CZAS) as ZAKAZENI_DZIEN_PRZED
FROM stage_tempo_fact
ORDER BY GEOGRAFIA, CZAS

SELECT
sf.CZAS,
sf.GEOGRAFIA,
pt.lzo,
pt.zdp,
lnzd = pt.lzo - pt.zdp
FROM
stage_tempo_fact AS sf
INNER JOIN 
(SELECT CZAS, GEOGRAFIA, LICZBA_ZAKAZENI_OGOLEM AS lzo, 
LAG(LICZBA_ZAKAZENI_OGOLEM, 1, 0) 
OVER (PARTITION BY GEOGRAFIA ORDER BY CZAS) AS zdp
FROM stage_tempo_fact) AS pt
ON sf.CZAS = pt.CZAS AND sf.GEOGRAFIA = pt.GEOGRAFIA
ORDER BY sf.GEOGRAFIA, sf.CZAS
GO


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