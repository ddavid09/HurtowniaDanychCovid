--********************************************************
--ETL
--********************************************************
USE CovidHurtowniaDanych
GO

--czesciowe zasilenie stage tabeli faktow kolumny:
--CZAS|GEOGRAFIA|LICZBA_ZAKAZENI_OGOLEM|LICZBA_ZGONOW_OGOLEM|LICZBA_WYLECZONYCH_OGOLEM|LICZBA_ZAKAZONYCH_NA_DZIS|NUMER_KOLEJNY_DNIA = 0
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

--poprawa nazwy Taiwanu w nowozaladowanych rekordach
UPDATE [dbo].[stage_tempo_fact] SET geografia = 'Taiwan' WHERE GEOGRAFIA = 'Taiwan*'

--***************************************
--NUMER_KOLEJNY_DNIA
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

UPDATE stage_tempo_fact
SET LICZBA_NOWYCH_ZAKAZEN_DZIS = 0
WHERE LICZBA_NOWYCH_ZAKAZEN_DZIS < 0
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

UPDATE stage_tempo_fact
SET LICZBA_NOWYCH_ZGONOW_DZIS = 0
WHERE LICZBA_NOWYCH_ZGONOW_DZIS < 0
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

UPDATE stage_tempo_fact
SET LICZBA_NOWYCH_WYLECZONYCH_DZIS = 0
WHERE LICZBA_NOWYCH_WYLECZONYCH_DZIS < 0
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

--*******************************************
--ZALADOWANIE PRZYROSTU DO TABELI FAKTOW TEMPO_WIRUSA_SUM
--*******************************************
INSERT INTO [dbo].TEMPO_WIRUSA_SUM
(CZAS_ID, GEOGRAFIA_ID, LICZBA_ZAKAZENI_OGOLEM, LICZBA_ZGONOW_OGOLEM , LICZBA_WYLECZONYCH_OGOLEM,
LICZBA_NOWYCH_ZAKAZEN_DZIS, LICZBA_ZAKAZONYCH_NA_DZIS, DYNAMIKA_ZAKAZEN, NUMER_KOLEJNY_DNIA)
SELECT 
cd.CZAS_ID, gd.GEOGRAFIA_ID, LICZBA_ZAKAZENI_OGOLEM, LICZBA_ZGONOW_OGOLEM, LICZBA_WYLECZONYCH_OGOLEM,
LICZBA_NOWYCH_ZAKAZEN_DZIS, LICZBA_ZAKAZONYCH_NA_DZIS, DYNAMIKA_ZAKAZEN, NUMER_KOLEJNY_DNIA
FROM [dbo].stage_tempo_fact stf
INNER JOIN CZAS_DIM cd ON CAST(stf.CZAS AS DATE) = cd.[DATA]
INNER JOIN GEOGRAFIA_DIM gd ON stf.GEOGRAFIA = gd.KRAJ
WHERE NOT EXISTS (SELECT [DATA], KRAJ FROM [dbo].TEMPO_WIRUSA_SUM ft
				INNER JOIN CZAS_DIM cd ON ft.CZAS_ID = cd.CZAS_ID
				INNER JOIN GEOGRAFIA_DIM gd ON ft.GEOGRAFIA_ID = gd.GEOGRAFIA_ID
				WHERE cd.[DATA] = stf.CZAS AND gd.KRAJ = stf.GEOGRAFIA)
GO





