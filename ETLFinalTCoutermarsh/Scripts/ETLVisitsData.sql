--****************** [VisitsStaging] *********************--
-- This file wil create the staging tables for the visits data
--********************************************************************--

Use tempdb;
Go
--********************************************************************--
-- Create the Tables
--********************************************************************--

Create or Alter Proc pETLCreateStagingTables
As
--*************************************************************************--
-- Desc:This Sproc creates the staging tables to load the visits data into.
-- Change Log: When,Who,What
-- 2025-03-05,TCoutermarsh,Created Sproc
--*************************************************************************--
Begin
  Declare @ReturnCode int = 0;
  Begin Try
  SET NOCOUNT ON;
/****** [BellevueVisitsStaging] ******/
Create Table BellevueVisitsStaging(
	[Time] nvarchar(100),
	[Patient] nvarchar(100),
	--Will need to add Clinic field
	[Doctor] nvarchar(100),
	[Procedure] nvarchar(100),
	[Charge] nvarchar(100)
)

/****** [KirklandVisitsStaging] ******/
Create Table KirklandVisitsStaging(
	[Time] nvarchar(100),
	[Patient] nvarchar(100),
	[Clinic] nvarchar(100),
	[Doctor] nvarchar(100),
	[Procedure] nvarchar(100),
	[Charge] nvarchar(100)
)

/****** [RedmondVisitsStaging] ******/
Create Table RedmondVisitsStaging(
	[Time] nvarchar(100),
	[Clinic] nvarchar(100),
	[Patient] nvarchar(100),
	[Doctor] nvarchar(100),
	[Procedure] nvarchar(100),
	[Charge] nvarchar(100)
)
  Set @ReturnCode = 1;
End Try
  Begin Catch
		Print 'Error Creating Staging Tables for File Import'
		Print ERROR_MESSAGE()
		Set @ReturnCode = -1;
  End Catch
  Return @ReturnCode;
End
Go

--Test Sproc
Exec pETLCreateStagingTables
--Select * From BellevueVisitsStaging
--Select * From KirklandVisitsStaging
--Select * From RedmondVisitsStaging
Go

--********************************************************************--
-- Transform Data
--********************************************************************--

Create or Alter Proc pETLTransformVisitsData
(@Date date)
As
----*************************************************************************--
---- Desc:This Sproc transforms the visits staging data.
---- Change Log: When,Who,What
---- 2025-03-06,TCoutermarsh,Created Sproc
----*************************************************************************--
Begin
  Declare @ReturnCode int = 0;
  Begin Try
    Select
	  [Date] = cast(@Date as datetime) + Cast([Time] as datetime)
     ,[Clinic] = 1 --Adding missing field and filling with 1
     ,[Patient]
     ,[Doctor]
     ,[Procedure]
     ,[Charge]
	From BellevueVisitsStaging
	Union --Stack separate staging data into one
	Select
	  [Date] = cast(@Date as datetime) + Cast([Time] as datetime)
     ,[Clinic]
     ,[Patient]
     ,[Doctor]
     ,[Procedure]
     ,[Charge]
	From KirklandVisitsStaging
	Union
	Select
	  [Date] = cast(@Date as datetime) + Cast([Time] as datetime)
     ,[Clinic]
     ,[Patient]
     ,[Doctor]
     ,[Procedure]
     ,[Charge]
	From RedmondVisitsStaging
	Order By [Date],[Clinic];
	Set @ReturnCode = 1
	;
  End Try
  Begin Catch
		Print 'Error Selecting all staging data'
		Print ERROR_MESSAGE()
		Set @ReturnCode = -1;
  End Catch
  Return @ReturnCode;
End
Go

--Test/Run Sproc
Exec pETLTransformVisitsData @Date = '20250306';
Go

--********************************************************************--
-- Drop Visits Foreign Keys
--********************************************************************--

Create or Alter Proc pETLDropVisitsForeignKeys
As
----*************************************************************************--
---- Desc:This Sproc drops foreign keys in the visits table to be able to insert.
---- Change Log: When,Who,What
---- 2025-03-06,TCoutermarsh,Created Sproc
----*************************************************************************--
Begin
  Declare @ReturnCode int = 0;
  Begin Try

  Alter Table [Patients].[dbo].[Visits]
    Drop Constraint [FK_Visits_Clinics]

  Alter Table [Patients].[dbo].[Visits]
    Drop Constraint [fkPatients] 

  Alter Table [Patients].[dbo].[Visits]
    Drop Constraint [fkProcedures]

  Alter Table [Patients].[dbo].[Visits]
    Drop Constraint [fkDoctors]
	Set @ReturnCode = 1
	;
  End Try
  Begin Catch
		Print 'Error dropping foregin keys'
		Print ERROR_MESSAGE()
		Set @ReturnCode = -1;
  End Catch
  Return @ReturnCode;
End
Go

--Test/Run Sproc
Exec pETLDropVisitsForeignKeys;
Go

--********************************************************************--
-- Insert Data
--********************************************************************--

Create or Alter Proc pETLInsertVisitsData
(@Date date)
As
----*************************************************************************--
---- Desc:This Sproc inserts the transformed data into the Visits table.
---- Change Log: When,Who,What
---- 2025-03-06,TCoutermarsh,Created Sproc
----*************************************************************************--
Begin
  Declare @ReturnCode int = 0;
  Begin Try
    Begin Tran;
	Insert Into [Patients].[dbo].[Visits]
	  ([Date], [Clinic], [Patient], [Doctor], [Procedure], [Charge])
	Exec pETLTransformVisitsData @Date = @Date
	Commit Tran;
   End Try
  Begin Catch
        Rollback Tran;
		Print 'Error inserting data'
		Print ERROR_MESSAGE()
		Set @ReturnCode = -1;
  End Catch
  Return @ReturnCode;
End
Go

--Test/Run Sproc
Exec pETLInsertVisitsData @Date = '20250306';
Go

--********************************************************************--
-- Add Foreign Keys
--********************************************************************--

Create or Alter Proc pETLInsertVisitsForeignKeys
As
----*************************************************************************--
---- Desc:This Sproc re-inserts the foreign keys to the visits table.
---- Change Log: When,Who,What
---- 2025-03-06,TCoutermarsh,Created Sproc
----*************************************************************************--
Begin
  Declare @ReturnCode int = 0;
  Begin Try

  Alter Table [Patients].[dbo].[Visits]
    Add Constraint [fkPatients]
    Foreign Key ([Patient]) References [Patients].[dbo].[Patients](ID);

  Alter Table [Patients].[dbo].[Visits]
    Add Constraint [fkProcedures]
    Foreign Key ([Procedure]) References [Patients].[dbo].[Procedures](ID);

  Alter Table [Patients].[dbo].[Visits]
    Add Constraint [fkDoctors]
    Foreign Key ([Doctor]) References [Patients].[dbo].[Doctors](ID);
	;
  End Try
  Begin Catch
		Print 'Error adding foregin keys'
		Print ERROR_MESSAGE()
		Set @ReturnCode = -1;
  End Catch
  Return @ReturnCode;
End
Go

--Test/Run Sproc
Exec pETLInsertVisitsForeignKeys;
Go

Select * From [Patients].[dbo].[Visits]

Use Patients
EXEC sp_help '[Patients].[dbo].[Visits]'; -- Replace with your table name
