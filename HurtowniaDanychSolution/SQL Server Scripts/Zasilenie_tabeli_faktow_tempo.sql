--*******************************************************
--ETL init START
--czesciowe zasilenie tabeli faktow dla wszystkich kolumn
--********************************************************

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

--***********************************
--Ustalenie liczby kolumn tabeli
--************************************
DECLARE @numOfCols int;
DECLARE @lastDate DATE;

SELECT @numOfCols = COUNT(COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_CATALOG = 'CovidHurtowniaDanych' AND TABLE_SCHEMA = 'dbo'
AND TABLE_NAME = 'csse_covid_19_time_series_confirmed_stage'   

SET @numOfCols=@numOfCols-4;
DECLARE @startDate DATE = '2020-01-22'
SET @lastDate = DATEADD(day, @numOfCols, @startDate)

--****************************************************************
--Petla po wszystkich (datach) kolumnach stage
--Czesciowe zasilenie tabeli stage za pomoca procedury skladowanej
--****************************************************************
WHILE @numOfCols > 0
BEGIN
	EXEC dbo.zasil_tempo_stage_confirmed_recovered_deaths_onthatday @data = @startDate
	SET @startDate = DATEADD(day, 1, @startDate)
	SET @numOfCols = @numOfCols-1;
END

--***************************************
--Nadanie numeru kolejnego dnia zakazenia 
--przejscie po kazdej geografi
--****************************************

DECLARE @numOfGeo int

SELECT @numOfGeo = COUNT(DISTINCT GEOGRAFIA_ID)
FROM [dbo].stage_tempo_fact

DECLARE @GeoId int = 0
DECLARE @casesFirstDay int;
DECLARE @RowToUpdateID int;
DECLARE @dateOfFirstCase DATE;
DECLARE @numOfDay int;
DECLARE @cursorDate DATE;

WHILE @GeoId <= @numOfGeo
BEGIN	
	SELECT @casesFirstDay = MIN(LICZBA_ZAKAZENI_OGOLEM) 
	FROM [dbo].stage_tempo_fact
	WHERE GEOGRAFIA_ID = @GeoId AND
	LICZBA_ZAKAZENI_OGOLEM > 0;

	SELECT TOP 1 @RowToUpdateID = FAKT_ID, @dateOfFirstCase = c.[DATA]
	FROM [dbo].stage_tempo_fact f
	INNER JOIN CZAS_DIM c ON f.CZAS_ID = c.CZAS_ID
	WHERE GEOGRAFIA_ID = @GeoId AND
	LICZBA_ZAKAZENI_OGOLEM = @casesFirstDay
	ORDER BY [DATA]

	UPDATE [dbo].stage_tempo_fact 
	SET NUMER_KOLEJNY_DNIA = 1
	WHERE FAKT_ID = @RowToUpdateID

	SET @numOfDay = 2;
	SET @cursorDate = DATEADD(day, 1, @dateOfFirstCase)

	WHILE @cursorDate <= @lastDate
		BEGIN
			SELECT @RowToUpdateID = FAKT_ID FROM [dbo].stage_tempo_fact sf
			INNER JOIN CZAS_DIM cd ON sf.CZAS_ID = cd.CZAS_ID
			WHERE sf.GEOGRAFIA_ID = @GeoId AND
			cd.[DATA] = @cursorDate

			UPDATE [dbo].stage_tempo_fact 
			SET NUMER_KOLEJNY_DNIA = @numOfDay
			WHERE FAKT_ID = @RowToUpdateID

			SET @cursorDate = DATEADD(day, 1, @cursorDate)
			SET @numOfDay = @numOfDay + 1
		END
	
	SET @GeoId = @GeoId+1;
END
GO
