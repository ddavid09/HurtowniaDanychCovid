--********************************************************
--ETL init 
--********************************************************
--czesciowe zasilenie tabeli faktow dla wszystkich kolumn
--********************************************************
USE CovidHurtowniaDanych
GO

DECLARE @startDate DATE
DECLARE @todayDate DATE = GETDATE()

IF (SELECT COUNT(*) FROM stage_tempo_fact) > 0
	SELECT @startDate = MAX(CAST([CZAS] AS DATE)) FROM stage_tempo_fact 
ELSE
	SET @startDate = '2020-01-22'
PRINT 'Ostanie dane w przestrzeni stage z: ' + CAST(@startDate AS varchar(50))

WHILE @startDate <= @todayDate
BEGIN
	EXEC dbo.zasil_tempo_stage_confirmed_recovered_deaths_onthatday @data = @startDate
	SET @startDate = DATEADD(day, 1, @startDate)
END
GO

--***************************************
--Nadanie numeru kolejnego dnia zakazenia 
--przejscie po kazdej geografi
--****************************************
UPDATE sf
SET sf.NUMER_KOLEJNY_DNIA = pt.nkd
FROM
stage_tempo_fact AS sf
INNER JOIN 
(SELECT CZAS, GEOGRAFIA, MIN(LICZBA_ZAKAZENI_OGOLEM) as lz,
ROW_NUMBER() OVER (PARTITION BY GEOGRAFIA ORDER BY CZAS) AS nkd
FROM stage_tempo_fact
WHERE LICZBA_ZAKAZENI_OGOLEM > 0
GROUP BY CZAS, GEOGRAFIA) AS pt
ON sf.CZAS = pt.CZAS AND sf.GEOGRAFIA = pt.GEOGRAFIA
GO

--************************************************************************************
--Uzupelnienie liczby nowych przypadkow dla kazdego faktu (kazdego dnia w kazdym kraju)
--************************************************************************************

SELECT * FROM stage_tempo_fact


UPDATE [dbo].stage_tempo_fact
SET 
	LICZBA_NOWYCH_ZAKAZEN_DZIS = LICZBA_ZAKAZONYCH_NA_DZIS,
	DYNAMIKA_ZAKAZEN = 0
FROM [dbo].stage_tempo_fact sf
INNER JOIN CZAS_DIM cd ON sf.CZAS_ID = cd.CZAS_ID
WHERE [DATA] = '2020-01-22'

DECLARE @maxDate DATE

SELECT TOP 1 @maxDate = [DATA]
FROM [dbo].stage_tempo_fact sf
INNER JOIN CZAS_DIM cd ON sf.CZAS_ID = cd.CZAS_ID
ORDER BY [DATA] DESC

DECLARE @dateCoursor DATE = '2020-01-23'

WHILE @dateCoursor <= @maxDate
	BEGIN
		DECLARE @numOfFactsThisDate int
		SELECT @numOfFactsThisDate = COUNT(*) FROM 
		[dbo].stage_tempo_fact sf
		INNER JOIN CZAS_DIM cd ON sf.CZAS_ID = cd.CZAS_ID
		WHERE [DATA] = @dateCoursor

		DECLARE @factCursor int = 0;

			WHILE @factCursor < @numOfFactsThisDate
				BEGIN
					DECLARE @idToUpdate int;
					DECLARE @GeographyId int;

					SELECT TOP 1 @idToUpdate = FAKT_ID, @GeographyId = GEOGRAFIA_ID
					FROM [dbo].stage_tempo_fact sf
					INNER JOIN CZAS_DIM cd ON sf.CZAS_ID = cd.CZAS_ID
					WHERE [DATA] = @dateCoursor AND
					LICZBA_NOWYCH_ZAKAZEN_DZIS IS NULL

					DECLARE @ConfirmedDayBefore int;

					SELECT @ConfirmedDayBefore = LICZBA_ZAKAZENI_OGOLEM 
					FROM [dbo].stage_tempo_fact sf
					INNER JOIN CZAS_DIM cd ON sf.CZAS_ID = cd.CZAS_ID
					WHERE [DATA] = DATEADD(day, -1, @dateCoursor) AND
					GEOGRAFIA_ID = @GeographyId

					UPDATE [dbo].stage_tempo_fact
					SET LICZBA_NOWYCH_ZAKAZEN_DZIS = LICZBA_ZAKAZENI_OGOLEM - @ConfirmedDayBefore
					WHERE FAKT_ID = @idToUpdate

					SET @factCursor = @factCursor + 1
				END
		SET @dateCoursor = DATEADD(day, 1, @dateCoursor)
	END
	GO

--********************************************************************
--Uzupe?nienie dynamiki zakazen petla po kazdym nieuzupelnionym fakcie
--********************************************************************

ALTER TABLE [dbo].stage_tempo_fact 
ALTER COLUMN DYNAMIKA_ZAKAZEN decimal(12,4)

DECLARE @numOfFacts int
DECLARE @cursor int = 0

SELECT @numOfFacts = COUNT(*) FROM [dbo].stage_tempo_fact

WHILE @cursor < @numOfFacts
	BEGIN
		DECLARE @toUpdateId int
		DECLARE @toUpdateData DATE
		DECLARE @toUpdateGeoId int

		SELECT TOP 1
		@toUpdateId = FAKT_ID,
		@toUpdateData = cd.[DATA],
		@toUpdateGeoId = GEOGRAFIA_ID
		FROM 
		[dbo].stage_tempo_fact sf
		INNER JOIN CZAS_DIM cd ON sf.CZAS_ID = cd.CZAS_ID
		WHERE 
		DYNAMIKA_ZAKAZEN IS NULL AND
		[DATA] > '2020-02-22'

		DECLARE @newCasesDayBefore int

		SELECT @newCasesDayBefore = LICZBA_NOWYCH_ZAKAZEN_DZIS
		FROM [dbo].stage_tempo_fact sf
		INNER JOIN CZAS_DIM cd ON sf.CZAS_ID = cd.CZAS_ID
		WHERE 
		[DATA] = DATEADD(day, -1, @toUpdateData) AND
		GEOGRAFIA_ID = @toUpdateGeoId

		IF @newCasesDayBefore > 0
			UPDATE [dbo].stage_tempo_fact 
			SET DYNAMIKA_ZAKAZEN = 
			CAST(CAST(LICZBA_NOWYCH_ZAKAZEN_DZIS AS decimal(12,5))/@newCasesDayBefore AS decimal(12,4))
			WHERE FAKT_ID = @toUpdateId
		ELSE
			UPDATE [dbo].stage_tempo_fact 
			SET DYNAMIKA_ZAKAZEN = 0
			WHERE FAKT_ID = @toUpdateId
			SET @cursor = @cursor + 1
	END

--************************************
--zaladowanie danych stage->tab faktow
--************************************

ALTER TABLE [dbo].TEMPO_WIRUSA_SUM
ALTER COLUMN DYNAMIKA_ZAKAZEN decimal(12,4)

SET IDENTITY_INSERT [dbo].TEMPO_WIRUSA_SUM ON

INSERT INTO [dbo].TEMPO_WIRUSA_SUM
(FAKT_ID, CZAS_ID, GEOGRAFIA_ID, LICZBA_ZAKAZENI_OGOLEM, LICZBA_ZGONOW_OGOLEM , LICZBA_WYLECZONYCH_OGOLEM,
LICZBA_NOWYCH_ZAKAZEN_DZIS, LICZBA_ZAKAZONYCH_NA_DZIS, DYNAMIKA_ZAKAZEN, NUMER_KOLEJNY_DNIA)
SELECT 
FAKT_ID, CZAS_ID, GEOGRAFIA_ID, LICZBA_ZAKAZENI_OGOLEM, LICZBA_ZGONOW_OGOLEM, LICZBA_WYLECZONYCH_OGOLEM,
LICZBA_NOWYCH_ZAKAZEN_DZIS, LICZBA_ZAKAZONYCH_NA_DZIS, DYNAMIKA_ZAKAZEN, NUMER_KOLEJNY_DNIA
FROM [dbo].stage_tempo_fact


--************************************
--odznaczenie daty danych 
--fdfafds
SELECT * FROM [dbo].stage_tempo_fact sf
INNER JOIN GEOGRAFIA_DIM gd ON sf.GEOGRAFIA_ID = gd.GEOGRAFIA_ID
INNER JOIN CZAS_DIM cd ON sf.CZAS_ID = cd.CZAS_ID
WHERE DYNAMIKA_ZAKAZEN IS NULL