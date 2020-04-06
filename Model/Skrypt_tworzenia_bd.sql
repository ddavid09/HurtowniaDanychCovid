USE [master];
GO

IF EXISTS (SELECT [name] FROM [master].[sys].[databases] WHERE [name] = 'CovidHurtowniaDanych')
    DROP DATABASE [CovidHurtowniaDanych];
GO

CREATE DATABASE [CovidHurtowniaDanych];
GO

USE [CovidHurtowniaDanych];
GO

CREATE TABLE [dbo].[FaktTempoWirusa](
	[TempoKlucz] [int] IDENTITY(1,1) NOT NULL,
	[Liczba zakazen ogolem] [int] NOT NULL,
	[Liczba zgonow ogolem] [int] NOT NULL,
	[Liczba wyleczonych ogolem] [int] NOT NULL,
	[Liczba nowych zakazen dzis] [int] NOT NULL,
	[Liczba zakazonych na dzis] [int] NOT NULL,
	[Dynamika zakazen] [float] NOT NULL,
	[Numer kolejny dnia] [int] NOT NULL
)
GO

CREATE TABLE [dbo].[WymiarCzas](
	[DataKlucz] [int] IDENTITY(1,1) NOT NULL,
	[Dzien] [tinyint] NOT NULL,
	[Miesiac] [tinyint] NOT NULL,
	[Rok] [int] NOT NULL
)
GO

CREATE TABLE [dbo].[WymiarGeografia](
	[GeografiaKlucz] [int] IDENTITY(1,1) NOT NULL,
	[Kontynent] [nvarchar](50) NOT NULL,
	[Kraj] [nvarchar](50) NOT NULL,
	[Populacja] [int],
	[PKB] [int]
)
GO

CREATE TABLE [dbo].[WymiarPacjent](
	[PacjentKlucz] [int] IDENTITY(1,1) NOT NULL,
	[Wiek] [int] NOT NULL,
	[Plec] [int] NOT NULL,
	[Stan] [nvarchar](50) NOT NULL,
	)
GO

