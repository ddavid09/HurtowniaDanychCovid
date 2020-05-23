--*********************************************************************
--nieuzywne - zastapione przez procedure skladowana utworz_tabele_stage
--*********************************************************************

USE [CovidHurtowniaDanych]
GO

IF EXISTS (SELECT [name]
	FROM [CovidHurtowniaDanych].[sys].[tables]
	WHERE [name] = 'csse_covid_19_time_series_stage')
		DROP TABLE [csse_covid_19_time_series_stage]
GO

CREATE TABLE [dbo].[csse_covid_19_time_series_stage]
(
	[Province/State] [nvarchar](50) NULL,
	[Country/Region] [nvarchar](50) NULL,
	[Lat] [decimal](4) NULL,
	[Long] [decimal](4) NULL,
)

DECLARE @liczbakolumn int = -1
DECLARE @startdate DATE = '2020-01-22'
DECLARE @extractdate DATE = CONVERT(DATE, GETDATE()-1)
DECLARE @addcolumnsql nvarchar(max)
DECLARE @i int = 0;

WHILE @i <= @liczbakolumn
BEGIN
	set @addcolumnsql = N'ALTER TABLE [dbo].[csse_covid_19_time_series_stage]
						ADD [' + CAST(@startdate AS nvarchar(25)) + '] [int]'
	EXEC sys.sp_executesql @addcolumnsql
SET @startdate = DATEADD(day, 1, @startdate)
SET @i = @i + 1;
END
GO

BULK INSERT [dbo].[csse_covid_19_time_series_stage] FROM 'C:\ssis_hd_temp\csse_covid_19_time_series.csv'
WITH (
	CODEPAGE='ACP',
	DATAFILETYPE = 'char',
	FIRSTROW = 2,
    FIELDTERMINATOR=',',
    ROWTERMINATOR = '0x0A',
    TABLOCK
);


