USE [CovidHurtowniaDanych]
GO

GO 
DROP PROCEDURE IF EXISTS dbo.zasil_wymiar_geografia
GO

CREATE PROC dbo.zasil_wymiar_geografia

@hurtowniaPath nvarchar(max)

AS

--DECLARE @hurtowniaPath nvarchar(max)
--SET @hurtowniaPath = N'C:\Users\ddawi\Google-cloud\02-Studia\16-Sem6-2020-03-2020-06\HD\Projekt\HurtowniaDanychCovid'

DROP TABLE IF EXISTS [dbo].[data_region_country]
DROP TABLE IF EXISTS [dbo].[data_country_population]
DROP TABLE IF EXISTS [dbo].[data_country_alpha3_gdp]

CREATE TABLE [dbo].[data_region_country]
(
	[Region] [nvarchar](50) NULL,
	[Country] [nvarchar](50) NULL,
)

CREATE TABLE [dbo].[data_country_population]
(
	[Country] [nvarchar](50) NULL,
	[Population] [int] NULL,
)

CREATE TABLE [dbo].[data_country_alpha3_gdp]
(
	[Country] [nvarchar](100) NULL,
	[ALPHA3] [nvarchar](50) NULL,
	[GDP] [nvarchar](50) NULL,
)


DECLARE @sqltext nvarchar(max)
SET @sqltext =
N'BULK INSERT [dbo].[data_region_country]
    FROM ''' + @hurtowniaPath + '\CSVDATA\region-country.csv''
    WITH
    (
    FIRSTROW = 2,
    FIELDTERMINATOR = '','', 
    ROWTERMINATOR = ''\n'',  
    ERRORFILE = ''' + @hurtowniaPath + '\CSVDATA\Errors\region-country-ErrorRows.csv'',
    TABLOCK
    )


BULK INSERT [dbo].[data_country_population]
    FROM ''' + @hurtowniaPath + '\CSVDATA\country-population.csv''
    WITH
    (
    FIRSTROW = 2,
    FIELDTERMINATOR = '';'', 
    ROWTERMINATOR = ''\n'',  
    ERRORFILE = ''' + @hurtowniaPath + '\CSVDATA\Errors\country-population-ErrorRows.csv'',
    TABLOCK
    )

BULK INSERT [dbo].[data_country_alpha3_gdp]
    FROM ''' + @hurtowniaPath + '\CSVDATA\country-alpha3-gdp.csv''
    WITH
    (
    FIRSTROW = 2,
    FIELDTERMINATOR = '';'', 
    ROWTERMINATOR = ''\n'',  
    ERRORFILE = ''' + @hurtowniaPath + '\CSVDATA\Errors\country-alpha3-gdp-ErrorRows.csv'',
    TABLOCK
    )'

--PRINT @sqltext
EXEC sp_executesql @sqltext

--***********************************************
--Utowrzenie przestrzeni stage dla wymiaru data
--***********************************************
DROP TABLE IF EXISTS [dbo].[stage_geografia]


CREATE TABLE [dbo].[stage_geografia]
(
	[GEOGRAFIA_ID] [int] IDENTITY(1,1) NOT NULL,
	[KRAJ] [nvarchar](50) NULL,
	[ALPHA-3_CODE] [nvarchar](3) NULL,
	[PKB] [Bigint] NULL,
	[KONTYNENT] [nvarchar](50) NULL,
	[POPULACJA] [Bigint] NULL,
	
)


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

UPDATE [dbo].[stage_geografia] SET KRAJ = 'Taiwan' WHERE KRAJ = 'Taiwan*'

--***********************************************
--Ladowanie do wymiaru GEOGRAFIA_DIM
--***********************************************
INSERT INTO [dbo].[GEOGRAFIA_DIM] (KONTYNENT, KRAJ, POPULACJA, PKB)
SELECT s.KONTYNENT, s.KRAJ, s.POPULACJA, s.PKB
FROM [dbo].[stage_geografia] AS [s]
WHERE NOT EXISTS (SELECT gd.KRAJ FROM
				GEOGRAFIA_DIM gd WHERE 
				gd.KRAJ = s.KRAJ)

--*********************************
--Posprzatanie wykorzystanych tabel
--*********************************
DROP TABLE IF EXISTS [dbo].[data_region_country]
DROP TABLE IF EXISTS [dbo].[data_country_population]
DROP TABLE IF EXISTS [dbo].[data_country_alpha3_gdp]
DROP TABLE IF EXISTS [dbo].[stage_geografia]

--****************************
--Uzupelnienie brakujacych pol
--****************************

UPDATE  GEOGRAFIA_DIM SET
KONTYNENT = (CASE
					WHEN KRAJ = 'Burkina Faso' OR
						KRAJ = 'Cabo Verde' OR
						KRAJ = 'Congo (Brazzaville)' OR
						KRAJ = 'Congo (Kinshasa)' OR
						KRAJ = 'Cote d''Ivoire' OR
						KRAJ = 'Eswatini' OR
						KRAJ = 'Western Sahara' THEN 'Africa'
					WHEN KRAJ = 'Burma' OR
						KRAJ = 'Korea South' OR
						KRAJ = 'Taiwan*' OR
						KRAJ = 'Timor-Leste' OR
						KRAJ = 'West Bank and Gaza' THEN 'Asia'
					WHEN KRAJ = 'Czechia' OR
						KRAJ = 'Diamond Princess' OR
						KRAJ = 'Holy See' OR
						KRAJ = 'Kosovo' OR
						KRAJ = 'MS Zaandam' OR
						KRAJ = 'North Macedonia' OR
						KRAJ = 'Russia'
						THEN 'Europe' else KONTYNENT END)


UPDATE GEOGRAFIA_DIM SET 
POPULACJA = '53710000'
WHERE KRAJ = 'Burma'
UPDATE GEOGRAFIA_DIM SET 
POPULACJA = '5244000'
WHERE KRAJ = 'Congo (Brazzaville)'
UPDATE GEOGRAFIA_DIM SET 
POPULACJA = '84070000'
WHERE KRAJ = 'Congo (Kinshasa)'
UPDATE GEOGRAFIA_DIM SET 
POPULACJA = '25070000'
WHERE KRAJ = 'Cote d''Ivoire'
UPDATE GEOGRAFIA_DIM SET 
POPULACJA = '10690000'
WHERE KRAJ = 'Czechia'
UPDATE GEOGRAFIA_DIM SET 
POPULACJA = '3770'
WHERE KRAJ = 'Diamond Princess'
UPDATE GEOGRAFIA_DIM SET 
POPULACJA = '51640000'
WHERE KRAJ = 'Korea South'
UPDATE GEOGRAFIA_DIM SET 
POPULACJA = '1845000'
WHERE KRAJ = 'Kosovo'
UPDATE GEOGRAFIA_DIM SET 
POPULACJA = '2047'
WHERE KRAJ = 'MS Zaandam'
UPDATE GEOGRAFIA_DIM SET 
POPULACJA = '52441'
WHERE KRAJ = 'Saint Kitts and Nevis'
UPDATE GEOGRAFIA_DIM SET 
POPULACJA = '110210'
WHERE KRAJ = 'Saint Vincent and the Grenadines'
UPDATE GEOGRAFIA_DIM SET 
POPULACJA = '211028'
WHERE KRAJ = 'Sao Tome and Principe'
UPDATE GEOGRAFIA_DIM SET 
POPULACJA = '23780000'
WHERE KRAJ = 'Taiwan'
UPDATE GEOGRAFIA_DIM SET 
POPULACJA = '328200000'
WHERE KRAJ = 'US'
UPDATE GEOGRAFIA_DIM SET 
POPULACJA = '4569000'
WHERE KRAJ = 'West Bank and Gaza'


UPDATE GEOGRAFIA_DIM SET
PKB = '12420000000'
WHERE KRAJ = 'Bahamas'
UPDATE GEOGRAFIA_DIM SET
PKB = '13570000000'
WHERE KRAJ = 'Brunei'
UPDATE GEOGRAFIA_DIM SET
PKB = '71210000000'
WHERE KRAJ = 'Burma'
UPDATE GEOGRAFIA_DIM SET
PKB = '11260000000'
WHERE KRAJ = 'Congo (Brazzaville)'
UPDATE GEOGRAFIA_DIM SET
PKB = '47230000000'
WHERE KRAJ = 'Congo (Kinshasa)'
UPDATE GEOGRAFIA_DIM SET
PKB = '245200000000'
WHERE KRAJ = 'Czechia'
UPDATE GEOGRAFIA_DIM SET
PKB = '0'
WHERE KRAJ = 'Diamond Princess'
UPDATE GEOGRAFIA_DIM SET
PKB = '250900000000'
WHERE KRAJ = 'Egypt'
UPDATE GEOGRAFIA_DIM SET
PKB = '2608000000'
WHERE KRAJ = 'Eritrea'
UPDATE GEOGRAFIA_DIM SET
PKB = '1633000000'
WHERE KRAJ = 'Gambia'
UPDATE GEOGRAFIA_DIM SET
PKB = '315000000'
WHERE KRAJ = 'Holy See'
UPDATE GEOGRAFIA_DIM SET
PKB = '454000000000'
WHERE KRAJ = 'Iran'
UPDATE GEOGRAFIA_DIM SET
PKB = '1619000000000'
WHERE KRAJ = 'Korea South'
UPDATE GEOGRAFIA_DIM SET
PKB = '8093000000'
WHERE KRAJ = 'Kyrgyzstan'
UPDATE GEOGRAFIA_DIM SET
PKB = '17950000000'
WHERE KRAJ = 'Laos'
UPDATE GEOGRAFIA_DIM SET
PKB = '6215000000'
WHERE KRAJ = 'Liechtenstein'
UPDATE GEOGRAFIA_DIM SET
PKB = '0'
WHERE KRAJ = 'MS Zaandam'
UPDATE GEOGRAFIA_DIM SET
PKB = '1658000000000'
WHERE KRAJ = 'Russia'
UPDATE GEOGRAFIA_DIM SET
PKB = '1011000000'
WHERE KRAJ = 'Saint Kitts and Nevis'
UPDATE GEOGRAFIA_DIM SET
PKB = '1922000000'
WHERE KRAJ = 'Saint Lucia'
UPDATE GEOGRAFIA_DIM SET
PKB = '811300000'
WHERE KRAJ = 'Saint Vincent and the Grenadines'
UPDATE GEOGRAFIA_DIM SET
PKB = '1633000000'
WHERE KRAJ = 'San Marino'
UPDATE GEOGRAFIA_DIM SET
PKB = '105900000000'
WHERE KRAJ = 'Slovakia'
UPDATE GEOGRAFIA_DIM SET
PKB = '12000000000'
WHERE KRAJ = 'South Sudan'
UPDATE GEOGRAFIA_DIM SET
PKB = '40410000000'
WHERE KRAJ = 'Syria'
UPDATE GEOGRAFIA_DIM SET
PKB = '586104000000'
WHERE KRAJ = 'Taiwan'
UPDATE GEOGRAFIA_DIM SET
PKB = '20540000000000'
WHERE KRAJ = 'US'
UPDATE GEOGRAFIA_DIM SET
PKB = '482400000000'
WHERE KRAJ = 'Venezuela'
UPDATE GEOGRAFIA_DIM SET
PKB = '908900000'
WHERE KRAJ = 'Western Sahara'
UPDATE GEOGRAFIA_DIM SET
PKB = '26910000000'
WHERE KRAJ = 'Yemen'
GO