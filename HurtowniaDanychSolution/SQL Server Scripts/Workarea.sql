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


	--dynamika zakazen
	--liczba nowych przypadkow/liczba nowych przypadkow w dniu wczorajszym

	--przechodze po calej tabeli faktow 
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
				
		SELECT CAST(CAST(1 AS decimal(17,5))/3 AS decimal(12,4))





	--


	SELECT * FROM [dbo].stage_tempo_fact sf
	INNER JOIN CZAS_DIM cd ON sf.CZAS_ID = cd.CZAS_ID
	INNER JOIN GEOGRAFIA_DIM gd ON sf.GEOGRAFIA_ID = gd.GEOGRAFIA_ID
	WHERE KRAJ = 'Poland'
	WHERE DYNAMIKA_ZAKAZEN IS NOT NULL

	UPDATE [dbo].stage_tempo_fact 
	SET DYNAMIKA_ZAKAZEN = NULL

	