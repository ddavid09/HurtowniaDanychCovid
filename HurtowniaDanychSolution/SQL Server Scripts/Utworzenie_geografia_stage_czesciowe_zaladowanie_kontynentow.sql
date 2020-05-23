USE [CovidHurtowniaDanych]
GO

DROP TABLE IF EXISTS [dbo].[geografia_stage]
GO

CREATE TABLE [dbo].[geografia_stage]
(
	[GEOGRAFIA_ID] [int] IDENTITY(1,1) NOT NULL,
	[ALPHA-3_CODE] [nvarchar](3) NULL,
	[KONTYNENT] [nvarchar](50) NULL,
	[KRAJ] [nvarchar](50) NULL,
	[POPULACJA] [int] NULL,
	[PKB] [int] NULL
)
GO

INSERT INTO [dbo].[geografia_stage] (KONTYNENT, KRAJ, POPULACJA)
SELECT DISTINCT REPLACE([Stage].[Country/Region], 'Taiwan*','Taiwan'), [Dictio].[Continent], CAST([Population].[Population (2020)] AS int)
FROM [dbo].[csse_covid_19_time_series_confirmed_stage] AS [Stage]
LEFT JOIN [dbo].[continents_dictio] AS [Dictio]
ON [Stage].[Country/Region]=[Dictio].[Country]
LEFT JOIN [dbo].[population_by_country_2020] AS [Population]
ON [Stage].[Country/Region]=[Population].[Country (or dependency)]


