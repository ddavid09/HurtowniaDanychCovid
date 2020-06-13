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
GO

--*********************************************************************************************************************
--utworzenie
--procesdura skladowana
--zaladowanie danych
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
(CZAS, GEOGRAFIA, LICZBA_ZAKAZENI_OGOLEM, LICZBA_ZGONOW_OGOLEM, LICZBA_WYLECZONYCH_OGOLEM, LICZBA_ZAKAZONYCH_NA_DZIS, NUMER_KOLEJNY_DNIA)
SELECT
'''+ @date + ''',
C.[Country/Region],
CONFIRMED,
DEATHS,
RECOVERED,
(CONFIRMED - (DEATHS + RECOVERED)) AS INFECTED_ON_THAT_DAY,
0,
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
ON C.[Country/Region] = D.[Country/Region]) AS P'

BEGIN TRY  
    EXEC sp_executesql @sqlText;  
	PRINT 'DANE PODSTAWOWE DLA DNIA: ' + @date + ' ZA?ADOWANE'
END TRY  
BEGIN CATCH  
    PRINT 'BRAK PODSTAWOWYCH Z DNIA: ' + @date
END CATCH; 
GO

--**************************************************************************************************************************************************


