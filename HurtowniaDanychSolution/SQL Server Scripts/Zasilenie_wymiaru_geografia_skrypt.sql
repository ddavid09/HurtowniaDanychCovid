USE [CovidHurtowniaDanych]
GO

--******************************************************************
--przed uruchomieniem skryptu nalezy wlaczyc opcje Query->SQLCMD Mode
--******************************************************************

 :setvar HurtowniaCovidPath "C:\Users\ddawi\Google-cloud\02-Studia\16-Sem6-2020-03-2020-06\HD\Projekt\HurtowniaDanychCovid"

--***********************************************
--Tabela danych kontynent-kraj
--***********************************************

DROP TABLE IF EXISTS [dbo].[data_region_country]
GO

CREATE TABLE [dbo].[data_region_country]
(
	[Region] [nvarchar](50) NULL,
	[Country] [nvarchar](50) NULL,
)
GO

BULK INSERT [dbo].[data_region_country]
    FROM '$(HurtowniaCovidPath)\CSVDATA\region-country.csv'
    WITH
    (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',', 
    ROWTERMINATOR = '\n',  
    ERRORFILE = '$(HurtowniaCovidPath)\CSVDATA\Errors\region-country-ErrorRows.csv',
    TABLOCK
    )

--***********************************************
--Tabela danych kraj-populacja
--***********************************************

DROP TABLE IF EXISTS [dbo].[data_country_population]
GO

CREATE TABLE [dbo].[data_country_population]
(
	[Country] [nvarchar](50) NULL,
	[Population] [int] NULL,
)
GO

BULK INSERT [dbo].[data_country_population]
    FROM '$(HurtowniaCovidPath)\CSVDATA\country-population.csv'
    WITH
    (
    FIRSTROW = 2,
    FIELDTERMINATOR = ';', 
    ROWTERMINATOR = '\n',  
    ERRORFILE = '$(HurtowniaCovidPath)\CSVDATA\Errors\country-population-ErrorRows.csv',
    TABLOCK
    )

--***********************************************
--Tabela danych kraj-kod_alpha3_kraju-PKB
--***********************************************

DROP TABLE IF EXISTS [dbo].[data_country_alpha3_gdp]
GO

CREATE TABLE [dbo].[data_country_alpha3_gdp]
(
	[Country] [nvarchar](100) NULL,
	[ALPHA3] [nvarchar](50) NULL,
	[GDP] [nvarchar](50) NULL,
)
GO

BULK INSERT [dbo].[data_country_alpha3_gdp]
    FROM '$(HurtowniaCovidPath)\CSVDATA\country-alpha3-gdp.csv'
    WITH
    (
    FIRSTROW = 2,
    FIELDTERMINATOR = ';', 
    ROWTERMINATOR = '\n',  
    ERRORFILE = '$(HurtowniaCovidPath)\CSVDATA\Errors\country-alpha3-gdp-ErrorRows.csv',
    TABLOCK
    )

--***********************************************
--Utowrzenie przestrzeni stage dla wymiaru data
--***********************************************

DROP TABLE IF EXISTS [dbo].[stage_geografia]
GO

CREATE TABLE [dbo].[stage_geografia]
(
	[GEOGRAFIA_ID] [int] IDENTITY(1,1) NOT NULL,
	[KRAJ] [nvarchar](50) NULL,
	[ALPHA-3_CODE] [nvarchar](3) NULL,
	[PKB] [Bigint] NULL,
	[KONTYNENT] [nvarchar](50) NULL,
	[POPULACJA] [Bigint] NULL,
	
)
GO

--***********************************************
--Wypelnienie przestrzeni stage dla wymiaru data
--***********************************************


INSERT INTO [dbo].[stage_geografia] (KRAJ, [ALPHA-3_CODE], PKB, KONTYNENT, POPULACJA)
SELECT DISTINCT
	[csse].[Country/Region] AS [KRAJ],
	[a].[ALPHA3] AS [ALPHA-3_CODE], 
	CAST([a].[GDP] AS Bigint) AS [PKB],
	[b].[Region] AS [KONTYNENT],
	CAST([c].[Population] AS Bigint) AS [POPULACJA]
FROM [dbo].[csse_covid_19_time_series_confirmed_stage] AS [csse]

LEFT JOIN [dbo].[data_country_alpha3_gdp] AS [a]
ON [csse].[Country/Region]=[a].[Country]

LEFT JOIN [dbo].[data_region_country] AS [b]
ON [csse].[Country/Region]=[b].[Country]

LEFT JOIN [dbo].[data_country_population] AS [c]
ON [csse].[Country/Region]=[c].[Country]

--***********************************************
--Ladowanie do wymiaru GEOGRAFIA_DIM
--***********************************************

INSERT INTO [dbo].[GEOGRAFIA_DIM] (KONTYNENT, KRAJ, POPULACJA, PKB)
SELECT s.KONTYNENT, s.KRAJ, s.POPULACJA, s.PKB
FROM [dbo].[stage_geografia] AS [s]

