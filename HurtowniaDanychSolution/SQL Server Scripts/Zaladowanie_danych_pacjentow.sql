USE CovidHurtowniaDanych
GO

DECLARE @lastDate DATE

IF (SELECT COUNT(*) FROM ZDARZENIE_PACJENT_DET) > 0
BEGIN
	SELECT @lastDate = CAST(MAX([DATA]) AS DATE)
	FROM ZDARZENIE_PACJENT_DET
	INNER JOIN CZAS_DIM ON ZDARZENIE_PACJENT_DET.CZAS_ID = CZAS_DIM.CZAS_ID
END
ELSE
BEGIN
	SET @lastDate = '2020-01-21'
END


SELECT FAKT_ID, CZAS_ID, GEOGRAFIA_ID, LICZBA_NOWYCH_ZAKAZEN_DZIS 
INTO #TEMP_ZAKAZENIA
FROM stage_tempo_fact
INNER JOIN GEOGRAFIA_DIM ON GEOGRAFIA = GEOGRAFIA_DIM.KRAJ
INNER JOIN CZAS_DIM ON CZAS = CZAS_DIM.[DATA]
WHERE CZAS_DIM.[DATA] > @lastDate
ORDER BY [DATA] DESC 

--************************************
--Tworzenie i ladowanie nowozakazonych
--************************************
DECLARE @geoId int 
DECLARE @czasId int
DECLARE @processingFactId int
DECLARE @numToProcess int
DECLARE @inCursor int = 0

WHILE (SELECT COUNT(*) FROM #TEMP_ZAKAZENIA) > 0
BEGIN
	SELECT TOP 1 
	@processingFactId = FAKT_ID,
	@geoId = GEOGRAFIA_ID,
	@czasId = CZAS_ID,
	@numToProcess = LICZBA_NOWYCH_ZAKAZEN_DZIS
	FROM #TEMP_ZAKAZENIA

	IF @numToProcess > 0
        BEGIN
        WHILE @inCursor < @numToProcess
            BEGIN
            EXEC dbo.UtworzNowoZakazonegoPacjenta 
			@geoId = @geoId, @dataId = @czasId
            SET @inCursor = @inCursor + 1
            END
        SET @inCursor = 0
        END
	
	DELETE #TEMP_ZAKAZENIA WHERE FAKT_ID = @processingFactId
END

DROP TABLE #TEMP_ZAKAZENIA

--***************************************
--Losowanie i ladowanie nowych wyzdrowien
--***************************************
SELECT FAKT_ID, CZAS_ID, GEOGRAFIA_ID, LICZBA_NOWYCH_WYLECZONYCH_DZIS  
INTO #TEMP_WYZDROWIENIA
FROM stage_tempo_fact
INNER JOIN GEOGRAFIA_DIM ON GEOGRAFIA = GEOGRAFIA_DIM.KRAJ
INNER JOIN CZAS_DIM ON CZAS = CZAS_DIM.[DATA]
WHERE CZAS_DIM.[DATA] > @lastDate

WHILE (SELECT COUNT(*) FROM #TEMP_WYZDROWIENIA) > 0
BEGIN
	SELECT TOP 1 
	@processingFactId = FAKT_ID,
	@geoId = GEOGRAFIA_ID,
	@czasId = CZAS_ID,
	@numToProcess = LICZBA_NOWYCH_WYLECZONYCH_DZIS
	FROM #TEMP_WYZDROWIENIA
	ORDER BY GEOGRAFIA_ID, CZAS_ID

	PRINT 'Obslugiwany fakt - geoID: ' + 
	CAST(@geoId AS varchar(15)) + ' czasID: ' 
	+ CAST(@czasId AS varchar(15))
	
	IF @numToProcess > 0
	BEGIN
		PRINT 'Liczba pacjentow do uzdrowienia: ' 
		+ CAST(@numToProcess AS varchar(15))
		EXEC NoweWyzdrowienia
		@geoId = @geoId, @dataId = @czasId, @numToProcess = @numToProcess
	END

	DELETE #TEMP_WYZDROWIENIA WHERE FAKT_ID = @processingFactId
END

DROP TABLE #TEMP_WYZDROWIENIA

--***************************************
--Losowanie i ladowanie nowych smierci
--***************************************
SELECT FAKT_ID, CZAS_ID, GEOGRAFIA_ID, LICZBA_NOWYCH_ZGONOW_DZIS 
INTO #TEMP_SMIERCI
FROM stage_tempo_fact
INNER JOIN GEOGRAFIA_DIM ON GEOGRAFIA = GEOGRAFIA_DIM.KRAJ
INNER JOIN CZAS_DIM ON CZAS = CZAS_DIM.[DATA]
WHERE CZAS_DIM.[DATA] > @lastDate

WHILE (SELECT COUNT(*) FROM #TEMP_SMIERCI) > 0
BEGIN
	SELECT TOP 1 
	@processingFactId = FAKT_ID,
	@geoId = GEOGRAFIA_ID,
	@czasId = CZAS_ID,
	@numToProcess = LICZBA_NOWYCH_ZGONOW_DZIS
	FROM #TEMP_SMIERCI
	ORDER BY GEOGRAFIA_ID, CZAS_ID

	PRINT 'Obslugiwany fakt - geoID: ' + 
	CAST(@geoId AS varchar(15)) + ' czasID: ' + 
	CAST(@czasId AS varchar(15))

	IF @numToProcess > 0
	BEGIN
		PRINT 'Liczba pacjentow do usmiercenia: ' + 
		CAST(@numToProcess AS varchar(15))
		EXEC NoweSmierci 
		@geoId = @geoId, @dataId = @czasId, @numToProcess = @numToProcess
	END
	
	DELETE #TEMP_SMIERCI WHERE FAKT_ID = @processingFactId
END

DROP TABLE #TEMP_SMIERCI