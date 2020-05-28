DECLARE @GeoId int;
DECLARE @casesFirstDay int;
DECLARE @RowToUpdateID int;
DECLARE @dateOfFirstCase DATE;
DECLARE @daysDelta int;

SELECT @casesFirstDay = MIN(LICZBA_ZAKAZENI_OGOLEM) 
FROM [dbo].stage_tempo_fact
WHERE GEOGRAFIA_ID = @GeoId AND
LICZBA_ZAKAZENI_OGOLEM > 0;

SELECT @RowToUpdateID = FAKT_ID, @dateOfFirstCase = c.[DATA]
FROM [dbo].stage_tempo_fact f
INNER JOIN CZAS_DIM c ON f.CZAS_ID = c.CZAS_ID
WHERE GEOGRAFIA_ID = @GeoId AND
LICZBA_ZAKAZENI_OGOLEM = @casesFirstDay
ORDER BY [DATA]

PRINT @RowToUpdateID
PRINT @dateOfFirstCase

SELECT gd.KRAJ, cd.[DATA], sf.* FROM [dbo].stage_tempo_fact sf
INNER JOIN GEOGRAFIA_DIM gd ON sf.GEOGRAFIA_ID = gd.GEOGRAFIA_ID
INNER JOIN CZAS_DIM cd ON sf.CZAS_ID = cd.CZAS_ID
WHERE  FAKT_ID = @RowToUpdateID

--^^Uzyskanie id faktu pierwszego zakazenia w zadanej parametrem geografii
--TODO Update tego wiersza, i dla ka?dego z kolejn? dat? a? do ko?ca update numeru kolejnego dnia 
SELECT * FROM [dbo].stage_tempo_fact sf
INNER JOIN GEOGRAFIA_DIM gd ON sf.GEOGRAFIA_ID = gd.GEOGRAFIA_ID
INNER JOIN CZAS_DIM cd ON sf.CZAS_ID = cd.CZAS_ID
WHERE KRAJ = 'Poland'
ORDER BY NUMER_KOLEJNY_DNIA



SELECT FAKT_ID, sf.GEOGRAFIA_ID FROM [dbo].stage_tempo_fact sf
INNER JOIN GEOGRAFIA_DIM gd ON sf.GEOGRAFIA_ID = gd.GEOGRAFIA_ID
WHERE KRAJ = 'Germany'

SELECT FAKT_ID, sf.GEOGRAFIA_ID FROM [dbo].stage_tempo_fact sf
INNER JOIN GEOGRAFIA_DIM gd ON sf.GEOGRAFIA_ID = gd.GEOGRAFIA_ID
WHERE KRAJ = 'Germany' AND LICZBA_ZAKAZENI_OGOLEM > 0 
ORDER BY LICZBA_ZAKAZENI_OGOLEM

SELECT * FROM GEOGRAFIA_DIM