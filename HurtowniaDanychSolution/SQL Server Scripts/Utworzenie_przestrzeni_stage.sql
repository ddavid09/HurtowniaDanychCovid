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

DECLARE @startdate DATE = '2020-01-22'
DECLARE @extractdate DATE = CONVERT(DATE, GETDATE())
DECLARE @addcolumnsql nvarchar(max)

WHILE @startdate <= @extractdate
BEGIN
	set @addcolumnsql = N'ALTER TABLE [dbo].[csse_covid_19_time_series_stage]
						ADD [' + CAST(@startdate AS nvarchar(25)) + '] [int]'
	EXEC sys.sp_executesql @addcolumnsql
SET @startdate = DATEADD(day, 1, @startdate)
END
GO



