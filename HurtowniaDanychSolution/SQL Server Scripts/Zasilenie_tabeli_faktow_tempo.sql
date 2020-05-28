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

--**********************************************************************************************************************
--zagregowane przypadki CONFIRMED|RECOVERED|DEATHS wg krajow dla zadanej daty z policzeniem zainfekowanych na dany dzien
--**********************************************************************************************************************

DECLARE @date nvarchar(10);
SET @date = '2020-05-23';

DECLARE @sqlText nvarchar(max)
SET @sqlText =
N'DROP TABLE IF EXISTS ##process_fact
SELECT '''
+ @date + ''' AS [DATE],
C.[Country/Region],
CONFIRMED,
DEATHS,
RECOVERED,
(CONFIRMED - (DEATHS + RECOVERED)) AS INFECTED_ON_THAT_DAY
INTO ##process_fact
FROM
(SELECT 
[Country/Region],
SUM([' + @date + ']) AS CONFIRMED
FROM #process_confirmed_table
GROUP BY [Country/Region]) AS C
INNER JOIN 
(SELECT 
[Country/Region],
SUM([' + @date + ']) AS RECOVERED
FROM #process_recovered_table
GROUP BY [Country/Region]) AS R
ON C.[Country/Region] = R.[Country/Region]
INNER JOIN
(SELECT 
[Country/Region],
SUM([' + @date + ']) AS DEATHS
FROM #process_deaths_table
GROUP BY [Country/Region]) AS D
ON C.[Country/Region] = D.[Country/Region]
ORDER BY CONFIRMED DESC;'

EXEC sp_executesql @sqlText;
SELECT * FROM ##process_fact

--******************************
--Utworzenie STAGE tabeli faktow 
--******************************

DROP TABLE IF EXISTS [dbo].[stage_tempo_fact]

CREATE TABLE [dbo].[stage_tempo_fact]
(
	[FAKT_ID] [int] IDENTITY(1,1) NOT NULL,
	[CZAS_ID] [int] NULL,
	[GEOGRAFIA_ID] [int] NULL,
	[LICZBA_ZAKAZENI_OGOLEM] [int] NULL,
	[LICZBA_ZGONOW_OGOLEM] [int] NULL,
	[LICZBA_WYLECZONYCH_OGOLEM] [int] NULL,
	[LICZBA_NOWYCH_ZAKAZEN_DZIS] [int] NULL,
	[LICZBA_ZAKAZONYCH_NA_DZIS] [int] NULL,
	[DYNAMIKA_ZAKAZEN] [float] NULL,
	[NUMER_KOLEJNY_DNIA] [int] NULL
)

--***************************************************
--zasilenie STAGE tabeli faktow niekompletnymi danymi
--***************************************************

INSERT INTO stage_tempo_fact
(CZAS_ID, GEOGRAFIA_ID, LICZBA_ZAKAZENI_OGOLEM, LICZBA_ZGONOW_OGOLEM, LICZBA_WYLECZONYCH_OGOLEM, LICZBA_ZAKAZONYCH_NA_DZIS)
SELECT 
ISNULL(C.CZAS_ID, 0),
ISNULL(G.GEOGRAFIA_ID, 0),
ISNULL(P.CONFIRMED, 0),
ISNULL(P.DEATHS, 0),
ISNULL(P.RECOVERED, 0),
ISNULL(P.INFECTED_ON_THAT_DAY, 0)
FROM ##process_fact AS P
INNER JOIN CZAS_DIM AS C ON P.[DATE] = C.[DATA]
INNER JOIN GEOGRAFIA_DIM AS G ON P.[Country/Region] = G.KRAJ

SELECT * FROM stage_tempo_fact

--**********************************************************************************
--Uzupelnienie o dane z o nowych przypadkach na podstawie danych z dnia poprzedniego
--**********************************************************************************

DROP TABLE IF EXISTS #process_fact1

SELECT P.*,
DB.LICZBA_ZAKAZENI_OGOLEM AS CONFIRMED_DAY_BEFORE
INTO #process_fact1
FROM ##process_fact AS P
INNER JOIN
(SELECT K.KRAJ ,F.LICZBA_ZAKAZENI_OGOLEM FROM stage_tempo_fact AS F
INNER JOIN GEOGRAFIA_DIM AS K ON F.GEOGRAFIA_ID = K.GEOGRAFIA_ID
INNER JOIN CZAS_DIM AS C ON F.CZAS_ID = C.CZAS_ID
WHERE C.[DATA] = '2020-05-22') AS DB
ON P.[Country/Region] = DB.KRAJ

ALTER TABLE #process_fact1 ADD NEW_INFECTED AS (CONFIRMED-CONFIRMED_DAY_BEFORE)

SELECT * FROM #process_fact1

--ETL init START
--czesciowe zasilenie tabeli faktow dla wszystkich kolumn

DROP TABLE IF EXISTS [dbo].[stage_tempo_fact]

CREATE TABLE [dbo].[stage_tempo_fact]
(
	[FAKT_ID] [int] IDENTITY(1,1) NOT NULL,
	[CZAS_ID] [int] NULL,
	[GEOGRAFIA_ID] [int] NULL,
	[LICZBA_ZAKAZENI_OGOLEM] [int] NULL,
	[LICZBA_ZGONOW_OGOLEM] [int] NULL,
	[LICZBA_WYLECZONYCH_OGOLEM] [int] NULL,
	[LICZBA_NOWYCH_ZAKAZEN_DZIS] [int] NULL,
	[LICZBA_ZAKAZONYCH_NA_DZIS] [int] NULL,
	[DYNAMIKA_ZAKAZEN] [float] NULL,
	[NUMER_KOLEJNY_DNIA] [int] NULL
)

--Petla po wszystkich kolumnach stage
--Ustalenie liczby kolumn tabeli
DECLARE @numOfCols int;

SELECT @numOfCols = COUNT(COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_CATALOG = 'CovidHurtowniaDanych' AND TABLE_SCHEMA = 'dbo'
AND TABLE_NAME = 'csse_covid_19_time_series_confirmed_stage'   

SET @numOfCols=@numOfCols-4;
DECLARE @startDate DATE = '2020-01-22'

WHILE @numOfCols > 0
BEGIN
	EXEC dbo.zasil_tempo_stage_confirmed_recovered_deaths_onthatday @data = @startDate
	SET @startDate = DATEADD(day, 1, @startDate)
	SET @numOfCols = @numOfCols-1;
END

SELECT * FROM [dbo].stage_tempo_fact

--Nadanie numeru kolejnego dnia zakazenia 
--przejscie po kazdej geografi

DECLARE @i int = 0;
DECLARE @numOfGeo int

SELECT @numOfGeo = COUNT(DISTINCT GEOGRAFIA_ID)
FROM [dbo].stage_tempo_fact

--odnalezienie pierwszego dnia zakazenia w danej geografii
DECLARE @GeoId int = 67;
DECLARE @casesFirstDay int;
DECLARE @RowToUpdateID int;

SELECT @casesFirstDay = MIN(LICZBA_ZAKAZENI_OGOLEM) 
FROM [dbo].stage_tempo_fact
WHERE GEOGRAFIA_ID = @GeoId AND
LICZBA_ZAKAZENI_OGOLEM > 0;

SELECT @RowToUpdateID = FAKT_ID
FROM [dbo].stage_tempo_fact f
INNER JOIN CZAS_DIM c ON f.CZAS_ID = c.CZAS_ID
WHERE GEOGRAFIA_ID = @GeoId AND
LICZBA_ZAKAZENI_OGOLEM = @casesFirstDay
ORDER BY [DATA]

PRINT @RowToUpdateID

SELECT gd.KRAJ, cd.[DATA], sf.* FROM [dbo].stage_tempo_fact sf
INNER JOIN GEOGRAFIA_DIM gd ON sf.GEOGRAFIA_ID = gd.GEOGRAFIA_ID
INNER JOIN CZAS_DIM cd ON sf.CZAS_ID = cd.CZAS_ID
WHERE  FAKT_ID = @RowToUpdateID

--^^Uzyskanie id faktu pierwszego zakazenia w zadanej parametrem geografii
--TODO Update tego wiersza, i dla ka?dego z kolejn? dat? a? do ko?ca update numeru kolejnego dnia 


SELECT FAKT_ID, sf.GEOGRAFIA_ID FROM [dbo].stage_tempo_fact sf
INNER JOIN GEOGRAFIA_DIM gd ON sf.GEOGRAFIA_ID = gd.GEOGRAFIA_ID
WHERE KRAJ = 'Germany'




