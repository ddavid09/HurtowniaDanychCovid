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
