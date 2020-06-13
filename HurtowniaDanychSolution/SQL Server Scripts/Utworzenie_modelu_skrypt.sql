USE [master];
GO

IF EXISTS (SELECT [name]
FROM [master].[sys].[databases]
WHERE [name] = 'CovidHurtowniaDanych')
    DROP DATABASE [CovidHurtowniaDanych];
GO

CREATE DATABASE [CovidHurtowniaDanych];
GO

USE [CovidHurtowniaDanych];
GO

-- ****************************************
-- Tabele
-- ****************************************

CREATE TABLE [dbo].[TEMPO_WIRUSA_SUM]
(
	[FAKT_ID] [int] IDENTITY(1,1) NOT NULL,
	[CZAS_ID] [int] NOT NULL,
	[GEOGRAFIA_ID] [int] NOT NULL,
	[LICZBA_ZAKAZENI_OGOLEM] [int] NOT NULL,
	[LICZBA_ZGONOW_OGOLEM] [int] NOT NULL,
	[LICZBA_WYLECZONYCH_OGOLEM] [int] NOT NULL,
	[LICZBA_NOWYCH_ZAKAZEN_DZIS] [int] NOT NULL,
	[LICZBA_ZAKAZONYCH_NA_DZIS] [int] NOT NULL,
	[DYNAMIKA_ZAKAZEN] [float] NOT NULL,
	[NUMER_KOLEJNY_DNIA] [int] NOT NULL
)
GO

ALTER TABLE [dbo].TEMPO_WIRUSA_SUM
ALTER COLUMN DYNAMIKA_ZAKAZEN decimal(12,4)

CREATE TABLE [dbo].[CZAS_DIM]
(
	[CZAS_ID] [int] IDENTITY(1,1) NOT NULL,
	[DATA] [date] NOT NULL,
	[DZIEN] [tinyint] NOT NULL,
	[MIESIAC] [tinyint] NOT NULL,
	[ROK] [int] NOT NULL
)
GO

CREATE TABLE [dbo].[GEOGRAFIA_DIM]
(
	[GEOGRAFIA_ID] [int] IDENTITY(1,1) NOT NULL,
	[KONTYNENT] [nvarchar](50) NULL,
	[KRAJ] [nvarchar](50) NULL,
	[POPULACJA] [Bigint] NULL,
	[PKB] [Bigint] NULL
)
GO

CREATE TABLE [dbo].[PACJENT_DIM]
(
	[PACJENT_ID] [int] IDENTITY(1,1) NOT NULL,
	[GEOGRAFIA_ID] [int] NOT NULL,
	[WIEK] [int] NOT NULL,
	[PLEC] [int] NOT NULL
)
GO

CREATE TABLE [dbo].[TYP_ZDARZENIA_DIM]
(
	[TYP_ZDARZENIA_ID] [int] IDENTITY(1,1) NOT NULL,
	[NAZWA_ZDARZENIA] [nvarchar](50) NOT NULL
)
GO

CREATE TABLE [dbo].[ZDARZENIE_PACJENT_DET]
(
	[FAKT_ID] [int] IDENTITY(1,1) NOT NULL,
	[PACJENT_ID] [int] NOT NULL,
	[TYP_ZDARZENIA_ID] [int] NOT NULL,
	[CZAS_ID] [int] NOT NULL
)
GO

-- ****************************************
-- Zaladowanie wymiarow daty i typu zdarzenia
-- ****************************************

INSERT INTO [dbo].[TYP_ZDARZENIA_DIM]
	([NAZWA_ZDARZENIA])
VALUES
	('zakazenie');
INSERT INTO [dbo].[TYP_ZDARZENIA_DIM]
	([NAZWA_ZDARZENIA])
VALUES
	('wyzdrowienie');
INSERT INTO [dbo].[TYP_ZDARZENIA_DIM]
	([NAZWA_ZDARZENIA])
VALUES
	('smierc');
GO

DECLARE @startdate DATE = '2020-01-22'
DECLARE @enddaste DATE = '2021-01-22'

WHILE @startdate < @enddaste
BEGIN
	INSERT INTO [dbo].[CZAS_DIM]
		([DATA], [DZIEN], [MIESIAC], [ROK])
	VALUES(
			@startdate,
			DATEPART(day, @startdate),
			DATEPART(month, @startdate),
			DATEPART(year, @startdate))
	SET @startdate = DATEADD(day, 1, @startdate)
END
GO

-- ****************************************
-- Klucze glowne
-- ****************************************

ALTER TABLE [dbo].[TEMPO_WIRUSA_SUM] 
	ADD CONSTRAINT [PK_TEMPO_WIRUSA] PRIMARY KEY CLUSTERED ([FAKT_ID]);
GO

ALTER TABLE [dbo].[CZAS_DIM] 
	ADD CONSTRAINT [PK_CZAS] PRIMARY KEY CLUSTERED ([CZAS_ID]);
GO

ALTER TABLE [dbo].[GEOGRAFIA_DIM] 
	ADD CONSTRAINT [PK_GEOGRAFIA] PRIMARY KEY CLUSTERED ([GEOGRAFIA_ID]);
GO

ALTER TABLE [dbo].[PACJENT_DIM] 
	ADD CONSTRAINT [PK_PACJENT] PRIMARY KEY CLUSTERED ([PACJENT_ID]);
GO

ALTER TABLE [dbo].[TYP_ZDARZENIA_DIM] 
	ADD CONSTRAINT [PK_TYP_ZDARZENIA] PRIMARY KEY CLUSTERED ([TYP_ZDARZENIA_ID]);
GO

ALTER TABLE [dbo].[ZDARZENIE_PACJENT_DET] 
	ADD CONSTRAINT [PK_STAN_PACJENTA] PRIMARY KEY CLUSTERED ([FAKT_ID]);
GO

-- ****************************************
-- Klucze obce
-- ****************************************

ALTER TABLE [dbo].[TEMPO_WIRUSA_SUM] ADD 
	CONSTRAINT [FK_TEMPO_WIRUSA_CZAS] FOREIGN KEY ([CZAS_ID]) REFERENCES [dbo].[CZAS_DIM] ([CZAS_ID]),
	CONSTRAINT [FK_TEMPO_WIRUSA_GEOGRAFIA] FOREIGN KEY ([GEOGRAFIA_ID]) REFERENCES [dbo].[GEOGRAFIA_DIM] ([GEOGRAFIA_ID]);
GO

ALTER TABLE [dbo].[ZDARZENIE_PACJENT_DET] ADD 
	CONSTRAINT [FK_ZDARZENIE_PACJENT_CZAS] FOREIGN KEY ([CZAS_ID]) REFERENCES [dbo].[CZAS_DIM] ([CZAS_ID]),
	CONSTRAINT [FK_ZDARZENIE_PACJENT_TYP_ZDARZENIA] FOREIGN KEY ([TYP_ZDARZENIA_ID]) REFERENCES [dbo].[TYP_ZDARZENIA_DIM] ([TYP_ZDARZENIA_ID]),
	CONSTRAINT [FK_ZDARZENIE_PACJENT_PACJENT] FOREIGN KEY ([PACJENT_ID]) REFERENCES [dbo].[PACJENT_DIM] ([PACJENT_ID]);
GO

ALTER TABLE [dbo].[PACJENT_DIM] ADD
	CONSTRAINT [FK_PACJENT_GEOGRAFIA] FOREIGN KEY ([GEOGRAFIA_ID]) REFERENCES [dbo].[GEOGRAFIA_DIM] ([GEOGRAFIA_ID]);
GO

-- *************************************************************************************************
-- Utworzenie procedury skladowanej do dynamicznego tworzenia tabel stage dla danych z csse z github
-- *************************************************************************************************

GO
DROP PROCEDURE IF EXISTS dbo.utworz_tabele_stage
GO

CREATE PROC dbo.utworz_tabele_stage

@nazwa_tabeli nvarchar(200),
@nazwa_pliku_csv nvarchar(200),
@liczba_kolumn_daty int

AS

DECLARE @createtablesql nvarchar(max);

SET @createtablesql = N'

IF EXISTS (SELECT [name]
	FROM [CovidHurtowniaDanych].[sys].[tables]
	WHERE [name] = '''+ @nazwa_tabeli + ''')
		DROP TABLE [' + @nazwa_tabeli + ']

CREATE TABLE [dbo].[' + @nazwa_tabeli + ']
(
	[Province/State] [nvarchar](50) NULL,
	[Country/Region] [nvarchar](50) NULL,
	[Lat] [decimal](4) NULL,
	[Long] [decimal](4) NULL,
)';

EXEC sys.sp_executesql @createtablesql;

DECLARE @startdate DATE = '2020-01-22';
DECLARE @addcolumnsql nvarchar(max);
DECLARE @i int = 0;

WHILE @i < @liczba_kolumn_daty
BEGIN
	set @addcolumnsql = N'ALTER TABLE [dbo].['+ @nazwa_tabeli +']
						ADD [' + CAST(@startdate AS nvarchar(25)) + '] [int]';
	EXEC sys.sp_executesql @addcolumnsql;
SET @startdate = DATEADD(day, 1, @startdate);
SET @i = @i + 1;
END

DECLARE @bulkinsertsql nvarchar(max);

SET @bulkinsertsql = N'
BULK INSERT ' + @nazwa_tabeli + '
FROM ''C:\ssis_hd_temp\' + @nazwa_pliku_csv + '''
WITH (FIRSTROW = 2,
    FIELDTERMINATOR = '','',
    ROWTERMINATOR=''\n'')'

EXEC sys.sp_executesql @bulkinsertsql
PRINT 'PIERWSZY BULK INSERT ZALADOWAL' + CAST(@@ROWCOUNT AS varchar(50)) + 'WIERSZY'

IF @@ROWCOUNT > 0
	PRINT 'TABELA' + @nazwa_tabeli + 'ZASILONA'
ELSE
	SET @bulkinsertsql = N'
	BULK INSERT ' + @nazwa_tabeli + '
	FROM ''C:\ssis_hd_temp\' + @nazwa_pliku_csv + '''
	WITH (FIRSTROW = 2,
		FIELDTERMINATOR = '','',
		ROWTERMINATOR=''0x0A'')'
	EXEC sys.sp_executesql @bulkinsertsql
	PRINT 'DRUGI BULK INSERT ZALADOWAL' + CAST(@@ROWCOUNT AS varchar(50)) + 'WIERSZY'
	PRINT 'TABELA' + @nazwa_tabeli + 'ZASILONA'
GO

--*********************************************************************************************************************
--utworzenie
--procedura skladowana
--zaladowanie podstawowych danych
--CZAS_ID|GEOGRAFIA_ID|LICZBA_ZAKAZENIE_OGOLEM|LICZBA ZGONOW OGOLEM|LICZBA_WYLECZONYCH_OGOLEM|LICZBA_ZAKAZONYCH_NA_DZIS
--do stage tabeli faktow tempo
--z wybranego dnia (kolumny)
--*********************************************************************************************************************

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

--**************************************************************************************************************************************************
--Procedura skladowana do zasilenia wymiaru geograffii
--**************************************************************************************************************************************************

GO 
DROP PROCEDURE IF EXISTS dbo.zasil_wymiar_geografia
GO

CREATE PROC dbo.zasil_wymiar_geografia

@hurtowniaPath nvarchar(max)

AS

--DECLARE @hurtowniaPath nvarchar(max)
--SET @hurtowniaPath = N'C:\Users\ddawi\Google-cloud\02-Studia\16-Sem6-2020-03-2020-06\HD\Projekt\HurtowniaDanychCovid'

DROP TABLE IF EXISTS [dbo].[data_region_country]
DROP TABLE IF EXISTS [dbo].[data_country_population]
DROP TABLE IF EXISTS [dbo].[data_country_alpha3_gdp]

CREATE TABLE [dbo].[data_region_country]
(
	[Region] [nvarchar](50) NULL,
	[Country] [nvarchar](50) NULL,
)

CREATE TABLE [dbo].[data_country_population]
(
	[Country] [nvarchar](50) NULL,
	[Population] [int] NULL,
)

CREATE TABLE [dbo].[data_country_alpha3_gdp]
(
	[Country] [nvarchar](100) NULL,
	[ALPHA3] [nvarchar](50) NULL,
	[GDP] [nvarchar](50) NULL,
)


DECLARE @sqltext nvarchar(max)
SET @sqltext =
N'BULK INSERT [dbo].[data_region_country]
    FROM ''' + @hurtowniaPath + '\CSVDATA\region-country.csv''
    WITH
    (
    FIRSTROW = 2,
    FIELDTERMINATOR = '','', 
    ROWTERMINATOR = ''\n'',  
    ERRORFILE = ''' + @hurtowniaPath + '\CSVDATA\Errors\region-country-ErrorRows.csv'',
    TABLOCK
    )


BULK INSERT [dbo].[data_country_population]
    FROM ''' + @hurtowniaPath + '\CSVDATA\country-population.csv''
    WITH
    (
    FIRSTROW = 2,
    FIELDTERMINATOR = '';'', 
    ROWTERMINATOR = ''\n'',  
    ERRORFILE = ''' + @hurtowniaPath + '\CSVDATA\Errors\country-population-ErrorRows.csv'',
    TABLOCK
    )

BULK INSERT [dbo].[data_country_alpha3_gdp]
    FROM ''' + @hurtowniaPath + '\CSVDATA\country-alpha3-gdp.csv''
    WITH
    (
    FIRSTROW = 2,
    FIELDTERMINATOR = '';'', 
    ROWTERMINATOR = ''\n'',  
    ERRORFILE = ''' + @hurtowniaPath + '\CSVDATA\Errors\country-alpha3-gdp-ErrorRows.csv'',
    TABLOCK
    )'

--PRINT @sqltext
EXEC sp_executesql @sqltext

--***********************************************
--Utowrzenie przestrzeni stage dla wymiaru data
--***********************************************
DROP TABLE IF EXISTS [dbo].[stage_geografia]


CREATE TABLE [dbo].[stage_geografia]
(
	[GEOGRAFIA_ID] [int] IDENTITY(1,1) NOT NULL,
	[KRAJ] [nvarchar](50) NULL,
	[ALPHA-3_CODE] [nvarchar](3) NULL,
	[PKB] [Bigint] NULL,
	[KONTYNENT] [nvarchar](50) NULL,
	[POPULACJA] [Bigint] NULL,
	
)


--***********************************************
--Wypelnienie przestrzeni stage dla wymiaru data
--***********************************************
INSERT INTO [dbo].[stage_geografia] (KRAJ, [ALPHA-3_CODE], PKB, KONTYNENT, POPULACJA)
SELECT DISTINCT
	[csse].[Country/Region] AS [KRAJ],
	[a].[ALPHA3] AS [ALPHA-3_CODE], 
	CAST([a].[GDP] AS Bigint) AS [PKB],
	[b].[Region] AS [KONTYNENT],
	CAST([c].[Population] AS Bigint) AS [POPULACJA]
FROM [dbo].[csse_covid_19_time_series_confirmed_stage] AS [csse]

LEFT JOIN [dbo].[data_country_alpha3_gdp] AS [a]
ON [csse].[Country/Region]=[a].[Country]

LEFT JOIN [dbo].[data_region_country] AS [b]
ON [csse].[Country/Region]=[b].[Country]

LEFT JOIN [dbo].[data_country_population] AS [c]
ON [csse].[Country/Region]=[c].[Country]

UPDATE [dbo].[stage_geografia] SET KRAJ = 'Taiwan' WHERE KRAJ = 'Taiwan*'

--***********************************************
--Ladowanie do wymiaru GEOGRAFIA_DIM
--***********************************************
INSERT INTO [dbo].[GEOGRAFIA_DIM] (KONTYNENT, KRAJ, POPULACJA, PKB)
SELECT s.KONTYNENT, s.KRAJ, s.POPULACJA, s.PKB
FROM [dbo].[stage_geografia] AS [s]
WHERE NOT EXISTS (SELECT gd.KRAJ FROM
				GEOGRAFIA_DIM gd WHERE 
				gd.KRAJ = s.KRAJ)

--*********************************
--Posprzatanie wykorzystanych tabel
--*********************************
DROP TABLE IF EXISTS [dbo].[data_region_country]
DROP TABLE IF EXISTS [dbo].[data_country_population]
DROP TABLE IF EXISTS [dbo].[data_country_alpha3_gdp]
DROP TABLE IF EXISTS [dbo].[stage_geografia]

--****************************
--Uzupelnienie brakujacych pol
--****************************

UPDATE  GEOGRAFIA_DIM SET
KONTYNENT = (CASE
					WHEN KRAJ = 'Burkina Faso' OR
						KRAJ = 'Cabo Verde' OR
						KRAJ = 'Congo (Brazzaville)' OR
						KRAJ = 'Congo (Kinshasa)' OR
						KRAJ = 'Cote d''Ivoire' OR
						KRAJ = 'Eswatini' OR
						KRAJ = 'Western Sahara' THEN 'Africa'
					WHEN KRAJ = 'Burma' OR
						KRAJ = 'Korea South' OR
						KRAJ = 'Taiwan*' OR
						KRAJ = 'Timor-Leste' OR
						KRAJ = 'West Bank and Gaza' THEN 'Asia'
					WHEN KRAJ = 'Czechia' OR
						KRAJ = 'Diamond Princess' OR
						KRAJ = 'Holy See' OR
						KRAJ = 'Kosovo' OR
						KRAJ = 'MS Zaandam' OR
						KRAJ = 'North Macedonia' OR
						KRAJ = 'Russia'
						THEN 'Europe' else KONTYNENT END)


UPDATE GEOGRAFIA_DIM SET 
POPULACJA = '53710000'
WHERE KRAJ = 'Burma'
UPDATE GEOGRAFIA_DIM SET 
POPULACJA = '5244000'
WHERE KRAJ = 'Congo (Brazzaville)'
UPDATE GEOGRAFIA_DIM SET 
POPULACJA = '84070000'
WHERE KRAJ = 'Congo (Kinshasa)'
UPDATE GEOGRAFIA_DIM SET 
POPULACJA = '25070000'
WHERE KRAJ = 'Cote d''Ivoire'
UPDATE GEOGRAFIA_DIM SET 
POPULACJA = '10690000'
WHERE KRAJ = 'Czechia'
UPDATE GEOGRAFIA_DIM SET 
POPULACJA = '3770'
WHERE KRAJ = 'Diamond Princess'
UPDATE GEOGRAFIA_DIM SET 
POPULACJA = '51640000'
WHERE KRAJ = 'Korea South'
UPDATE GEOGRAFIA_DIM SET 
POPULACJA = '1845000'
WHERE KRAJ = 'Kosovo'
UPDATE GEOGRAFIA_DIM SET 
POPULACJA = '2047'
WHERE KRAJ = 'MS Zaandam'
UPDATE GEOGRAFIA_DIM SET 
POPULACJA = '52441'
WHERE KRAJ = 'Saint Kitts and Nevis'
UPDATE GEOGRAFIA_DIM SET 
POPULACJA = '110210'
WHERE KRAJ = 'Saint Vincent and the Grenadines'
UPDATE GEOGRAFIA_DIM SET 
POPULACJA = '211028'
WHERE KRAJ = 'Sao Tome and Principe'
UPDATE GEOGRAFIA_DIM SET 
POPULACJA = '23780000'
WHERE KRAJ = 'Taiwan'
UPDATE GEOGRAFIA_DIM SET 
POPULACJA = '328200000'
WHERE KRAJ = 'US'
UPDATE GEOGRAFIA_DIM SET 
POPULACJA = '4569000'
WHERE KRAJ = 'West Bank and Gaza'


UPDATE GEOGRAFIA_DIM SET
PKB = '12420000000'
WHERE KRAJ = 'Bahamas'
UPDATE GEOGRAFIA_DIM SET
PKB = '13570000000'
WHERE KRAJ = 'Brunei'
UPDATE GEOGRAFIA_DIM SET
PKB = '71210000000'
WHERE KRAJ = 'Burma'
UPDATE GEOGRAFIA_DIM SET
PKB = '11260000000'
WHERE KRAJ = 'Congo (Brazzaville)'
UPDATE GEOGRAFIA_DIM SET
PKB = '47230000000'
WHERE KRAJ = 'Congo (Kinshasa)'
UPDATE GEOGRAFIA_DIM SET
PKB = '245200000000'
WHERE KRAJ = 'Czechia'
UPDATE GEOGRAFIA_DIM SET
PKB = '0'
WHERE KRAJ = 'Diamond Princess'
UPDATE GEOGRAFIA_DIM SET
PKB = '250900000000'
WHERE KRAJ = 'Egypt'
UPDATE GEOGRAFIA_DIM SET
PKB = '2608000000'
WHERE KRAJ = 'Eritrea'
UPDATE GEOGRAFIA_DIM SET
PKB = '1633000000'
WHERE KRAJ = 'Gambia'
UPDATE GEOGRAFIA_DIM SET
PKB = '315000000'
WHERE KRAJ = 'Holy See'
UPDATE GEOGRAFIA_DIM SET
PKB = '454000000000'
WHERE KRAJ = 'Iran'
UPDATE GEOGRAFIA_DIM SET
PKB = '1619000000000'
WHERE KRAJ = 'Korea South'
UPDATE GEOGRAFIA_DIM SET
PKB = '8093000000'
WHERE KRAJ = 'Kyrgyzstan'
UPDATE GEOGRAFIA_DIM SET
PKB = '17950000000'
WHERE KRAJ = 'Laos'
UPDATE GEOGRAFIA_DIM SET
PKB = '6215000000'
WHERE KRAJ = 'Liechtenstein'
UPDATE GEOGRAFIA_DIM SET
PKB = '0'
WHERE KRAJ = 'MS Zaandam'
UPDATE GEOGRAFIA_DIM SET
PKB = '1658000000000'
WHERE KRAJ = 'Russia'
UPDATE GEOGRAFIA_DIM SET
PKB = '1011000000'
WHERE KRAJ = 'Saint Kitts and Nevis'
UPDATE GEOGRAFIA_DIM SET
PKB = '1922000000'
WHERE KRAJ = 'Saint Lucia'
UPDATE GEOGRAFIA_DIM SET
PKB = '811300000'
WHERE KRAJ = 'Saint Vincent and the Grenadines'
UPDATE GEOGRAFIA_DIM SET
PKB = '1633000000'
WHERE KRAJ = 'San Marino'
UPDATE GEOGRAFIA_DIM SET
PKB = '105900000000'
WHERE KRAJ = 'Slovakia'
UPDATE GEOGRAFIA_DIM SET
PKB = '12000000000'
WHERE KRAJ = 'South Sudan'
UPDATE GEOGRAFIA_DIM SET
PKB = '40410000000'
WHERE KRAJ = 'Syria'
UPDATE GEOGRAFIA_DIM SET
PKB = '586104000000'
WHERE KRAJ = 'Taiwan'
UPDATE GEOGRAFIA_DIM SET
PKB = '20540000000000'
WHERE KRAJ = 'US'
UPDATE GEOGRAFIA_DIM SET
PKB = '482400000000'
WHERE KRAJ = 'Venezuela'
UPDATE GEOGRAFIA_DIM SET
PKB = '908900000'
WHERE KRAJ = 'Western Sahara'
UPDATE GEOGRAFIA_DIM SET
PKB = '26910000000'
WHERE KRAJ = 'Yemen'
GO

--*****************************************************************************************************************************************************************************************