/***************************************************************************
ETL Final Project: DWClinicReportData_TylerCoutermarsh
Dev: TCoutermarsh
Date:2/21/2017
Desc: This is a Data Warehouse for the Patient and DoctorsSchedule Databases.
	  ETL processing issues.
ChangeLog: (Who, When, What) 
	RRoot, 3/3/17, removed addresses from DimPatients
	RRoot, 3/4/17, removed addresses from DimDoctors and DimClinic
	RRoot, 3/4/17, altered the file description
	RRoot, 3/7/17, added names to all PK and FK constraints
	RRoot, 2/21/18, added SCD columns to DimPatients
	RRoot, 2/23/31, added ETL logging tables
    TCoutermarsh, 3/11/2025, modified the database name for ETL development project
	TCoutermarsh, 3/11/2025, Added incremental ETL processing
*****************************************************************************************/
Use Master;
go

If Exists (Select * From Sys.databases where Name = 'DWClinicReportDataTylerCoutermarsh')
  Begin
   Alter Database DWClinicReportDataTylerCoutermarsh set single_user with rollback immediate;
   Drop Database DWClinicReportDataTylerCoutermarsh;
  End
go

Create Database DWClinicReportDataTylerCoutermarsh;
go

Use DWClinicReportDataTylerCoutermarsh;
go


Create Table DimDates -- Type 1 SCD
(DateKey int Constraint pkDimDates Primary Key Identity 
,FullDate datetime Not Null
,FullDateName nvarchar (50) Not Null 
,MonthID int Not Null
,[MonthName] nvarchar(50) Not Null
,YearID int Not Null
,YearName nvarchar(50) Not Null
);
go

Create Table DimClinics -- Type 1 SCD
(ClinicKey int Constraint pkDimClinics Primary Key Identity
,ClinicID int Not Null
,ClinicName nvarchar(100) Not Null 
,ClinicCity nvarchar(100) Not Null
,ClinicState nvarchar(100) Not Null 
,ClinicZip nvarchar(5) Not Null 
);
go

Create Table DimDoctors -- Type 1 SCD
(DoctorKey int Constraint pkDimDoctors Primary Key Identity
,DoctorID int Not Null  
,DoctorFullName nvarchar(200) Not Null 
,DoctorEmailAddress nvarchar(100) Not Null  
,DoctorCity nvarchar(100) Not Null
,DoctorState nvarchar(100) Not Null
,DoctorZip nvarchar(5) Not Null 
);
go

Create Table DimShifts -- Type 1 SCD
(ShiftKey int Constraint pkDimShifts Primary Key Identity
,ShiftID int Not Null
,ShiftStart time(0) Not Null
,ShiftEnd time(0) Not Null
);
go

Create Table FactDoctorShifts -- Type 1 SCD
(DoctorsShiftID int Not Null
,ShiftDateKey int Constraint fkFactDoctorShiftsToDimDates References DimDates(DateKey) Not Null
,ClinicKey int Constraint fkFactDoctorShiftsToDimClinics References DimClinics(ClinicKey) Not Null
,ShiftKey int Constraint fkFactDoctorShiftsToDimShifts References DimShifts(ShiftKey) Not Null
,DoctorKey int Constraint fkFactDoctorShiftsToDimDoctors References DimDoctors(DoctorKey) Not Null
,HoursWorked int
Constraint pkFactDoctorShifts Primary Key(DoctorsShiftID, ShiftDateKey , ClinicKey, ShiftKey, DoctorKey)
);
go

Create Table DimProcedures -- Type 1 SCD
(ProcedureKey int Constraint pkDimProcedures Primary Key Identity
,ProcedureID int Not Null
,ProcedureName varchar(100) Not Null
,ProcedureDesc varchar(1000) Not Null
,ProcedureCharge money Not Null 
);
go

Create Table DimPatients -- Type 2 SCD
(PatientKey int Constraint pkDimPatients Primary Key Identity
,PatientID int Not Null
,PatientFullName varchar(100) Not Null
,PatientCity varchar(100) Not Null
,PatientState varchar(100) Not Null
,PatientZipCode int Not Null
,StartDate date Not Null
,EndDate date Null
,IsCurrent int Constraint ckDimPatientsIsCurrent Check (IsCurrent In (1,0))
);
go

Create Table FactVisits -- Type 1 SCD
(VisitKey int Not Null
,DateKey int Constraint fkFactVisitsToDimDates References DimDates(DateKey) Not Null
,ClinicKey int Constraint fkFactVisitsToDimClinics References DimClinics(ClinicKey) Not Null
,PatientKey int Constraint fkFactVisitsToDimPatients References DimPatients(PatientKey) Not Null
,DoctorKey int Constraint fkFactVisitsToDimDoctors References DimDoctors(DoctorKey) Not Null
,ProcedureKey int Constraint fkFactVisitsToDimProcedures References DimProcedures(ProcedureKey) Not Null 
,ProcedureVistCharge money Not Null
Constraint pkFactVisits Primary Key(VisitKey, DateKey, ClinicKey, PatientKey, DoctorKey, ProcedureKey)
);
go

--********************************************************************--
--  Create ETL logging objects. Use these in your ETL stored procedures!
--********************************************************************--
If NOT Exists(Select * From Sys.tables where Name = 'ETLLog')
  Create -- Drop
  Table ETLLog
  (ETLLogID int identity Primary Key
  ,ETLDateAndTime datetime Default GetDate()
  ,ETLAction varchar(100)
  ,ETLLogMessage varchar(2000)
  );
go

Create or Alter View vETLLog
As
  Select
   ETLLogID
  ,ETLDate = Format(ETLDateAndTime, 'D', 'en-us')
  ,ETLTime = Format(Cast(ETLDateAndTime as datetime2), 'HH:mm', 'en-us')
  ,ETLAction
  ,ETLLogMessage
  From ETLLog;
go


Create or Alter Proc pInsETLLog
 (@ETLAction varchar(100), @ETLLogMessage varchar(2000))
--*************************************************************************--
-- Desc:This Sproc creates an admin table for logging ETL metadata. 
-- Change Log: When,Who,What
-- 2020-01-01,RRoot,Created Sproc
--*************************************************************************--
As
Begin
  Declare @RC int = 0;
  Begin Try
    Begin Tran;
      Insert Into ETLLog
       (ETLAction,ETLLogMessage)
      Values
       (@ETLAction,@ETLLogMessage)
    Commit Tran;
    Set @RC = 1;
  End Try
  Begin Catch
    If @@TRANCOUNT > 0 Rollback Tran;
    Set @RC = -1;
  End Catch
  Return @RC;
End
Go

--********************************************************************--
--Synchronize the Tables
--********************************************************************--

/****** [dbo].[DimDates] ******/
Create or Alter Procedure pETLFillDimDates
/* Author: TCoutermarsh
** Desc: Inserts data Into DimDates
** Change Log: When,Who,What
** 20250311,TCoutermarsh,Created Sproc.
*/
AS
 Begin
  Declare @RC int = 0;
  Begin Try
  SET IDENTITY_INSERT DimDates ON;
    
      Declare @StartDate datetime = '01/01/2005'
      Declare @EndDate datetime = '12/31/2025' 
      Declare @DateInProcess datetime  = @StartDate
      -- Loop through the dates until you reach the end date
      While @DateInProcess <= @EndDate
       Begin
       -- Add a row Into the date dimension table for this date
       Begin Tran;
       Insert Into DimDates 
       ( [DateKey], [FullDate],[FullDateName],[MonthID],[MonthName],[YearID],[YearName])
       Values ( 
         Cast(Convert(nVarchar(50), @DateInProcess, 112) as int) -- [DateKey]
        ,@DateInProcess -- [FullDate]
		,DateName(weekday, @DateInProcess) + ', ' + Convert(nVarchar(50), @DateInProcess, 110) -- [FullDateName]  
        ,Cast(Left(Convert(nVarchar(50), @DateInProcess, 112), 6) as int)  -- [MonthID]
		,DateName(month, @DateInProcess) + ' - ' + DateName(YYYY,@DateInProcess) -- [MonthName]
        ,Year(@DateInProcess) -- [YearID] 
        ,Cast(Year(@DateInProcess ) as nVarchar(50)) -- [YearName] 
        )  
       -- Add a day and loop again
       Set @DateInProcess = DateAdd(d, 1, @DateInProcess)
       Commit Tran;
       End
    Exec pInsETLLog
	        @ETLAction = 'pETLFillDimDates'
	       ,@ETLLogMessage = 'DimDates filled';
    Set @RC = +1
  End Try
  Begin Catch
    If @@TRANCOUNT > 0 Rollback Tran;
    Declare @ErrorMessage nvarchar(1000) = Error_Message();
	  Exec pInsETLLog 
	     @ETLAction = 'pETLFillDimDates'
	    ,@ETLLogMessage = @ErrorMessage;
    Set @RC = -1;
  End Catch
  Return @RC;
 End
go
/* Testing Code:
 Declare @Status int;
 Exec @Status = pETLFillDimDates;
 Print @Status;
 Select * From DimDates;
 Select * From vETLLog;
*/
go

/****** [dbo].[DimPatients] ******/
go 
Create or Alter View vETLDimPatients
/* Author: Tyler Coutermarsh
** Desc: Extracts and transforms data for DimPatients
** Change Log: When,Who,What
** 2025-03-11, Tyler Coutermarsh, Created View.
*/
As
    Select
    [PatientID] = p.ID
   ,[PatientFullName] = CAST(CONCAT(p.FName,' ',p.LName) AS varchar(100))
   ,[PatientCity] = CAST(p.City as varchar(100))
   ,[PatientState] = CAST(p.State as varchar(100))
   ,[PatientZipCode] = CAST(p.ZipCode as int)
    From [Patients].dbo.Patients as p;
go
/* Testing Code:
 Select * From vETLPatients;
*/

go
Create or Alter Procedure pETLSyncDimPatients
/* Author: TCoutermarsh
** Desc: Updates data in DimPatients using the vETLDimPatients view
** Change Log: When,Who,What
** 2025-03-11,TCoutermarsh,Created Sproc.
*/
As
Begin
  Declare @RC int = 0;
  Begin Try
    
    Begin Tran;
      Merge Into DimPatients as tp
       Using vETLDimPatients as vp -- For Merge to work with SCD tables, I need to insert a new row when the following is not true:
        On  tp.PatientID = vp.PatientID
        And tp.PatientFullName = vp.PatientFullName
        And tp.PatientCity = vp.PatientCity
        And tp.PatientState = vp.PatientState
		And tp.PatientZipCode = vp.PatientZipCode
       When Not Matched -- At least one column value does not match add a new row:
        Then
         Insert (PatientID, PatientFullName, PatientCity, PatientState, PatientZipCode, StartDate, EndDate, IsCurrent)
          Values (vp.PatientID
                , vp.PatientFullName
                , vp.PatientCity
                , vp.PatientState
				, vp.PatientZipCode
                ,GetDate() -- Smart Key can be joined to the DimDate
                ,Null
                ,1)
        When Not Matched By Source -- If there is a row in the target (dim) table that is no longer in the source table
         Then -- indicate that row is no longer current, because this table is SCD Type 2!
          Update 
           Set tp.EndDate = GetDate() -- Smart Key can be joined to the DimDate
              ,tp.IsCurrent = 0
              ;
    Commit Tran;
    -- ETL Logging Code --
    Exec pInsETLLog
	        @ETLAction = 'pETLSyncDimPatients'
	       ,@ETLLogMessage = 'DimPatients synced';
    Set @RC = +1
  End Try
  Begin Catch
     Declare @ErrorMessage nvarchar(1000) = Error_Message();
	 Exec pInsETLLog 
	      @ETLAction = 'pETLSyncDimPatients'
	     ,@ETLLogMessage = @ErrorMessage;
    Set @RC = -1
  End Catch
  Return @RC;
 End
go
/* Testing Code:
 Exec pETLSyncDimPatients;
 Select * From DimPatients;
*/

/****** [dbo].[DimProcedures] ******/
go 
Create or Alter View vETLDimProcedures
/* Author: Tyler Coutermarsh
** Desc: Extracts and transforms data for DimProcedures
** Change Log: When,Who,What
** 2025-03-12, Tyler Coutermarsh,Created Sproc.
*/
As
    Select
    [ProcedureID] = p.ID
   ,[ProcedureName] = CAST(p.Name as varchar(100))
   ,[ProcedureDesc] = CAST(p.[Desc] as varchar(1000))
   ,[ProcedureCharge] = CAST(p.Charge as money)
    From [Patients].dbo.Procedures as p;
go

/* Testing Code:
 Select * From vETLDimProcedures;
*/


Create Or Alter Procedure pETLSyncDimProcedures
/* Author: TCoutermarsh
** Desc: Updates data in DimProcedures using the vETLDimProcedures view
** Change Log: When,Who,What
** 2025-03-12,TCoutermarsh,Created Sproc.
*/
AS 
BEGIN 
  Declare @RC int;
  Begin Try
    Begin Tran;
		  Merge Into DimProcedures as tp
		  Using vETLDimProcedures as vp
		  	ON tp.ProcedureID = vp.ProcedureID
		  	When Not Matched 
		  		Then -- The ID in the Source is not found the the Target
		  			INSERT 
		  			VALUES ( vp.ProcedureID, vp.ProcedureName, vp.ProcedureDesc, vp.ProcedureCharge )
		  	When Matched -- When the IDs match for the row currently being looked 
		  	AND ( vp.ProcedureName <> tp.ProcedureName  
		  		OR vp.ProcedureDesc <> tp.ProcedureDesc
				OR vp.ProcedureCharge <> tp.ProcedureCharge) 
		  		Then 
		  			UPDATE -- It know your target, so you dont specify the DimProcedures
		  			SET tp.ProcedureName = vp.ProcedureName
		  			  , tp.ProcedureDesc = vp.ProcedureDesc
					  , tp.ProcedureCharge = vp.ProcedureCharge
		  	When Not Matched By Source 
		  		Then -- The ProcedureID is in the Target table, but not the source table
		  			DELETE
		  ; -- The merge statement demands a semicolon at the end!
    Commit Tran;
    -- ETL Logging Code --
    Exec pInsETLLog
	        @ETLAction = 'pETLSyncDimProcedures'
	       ,@ETLLogMessage = 'DimProcedures synced';
    Set @RC = +1
  End Try
  Begin Catch
     Declare @ErrorMessage nvarchar(1000) = Error_Message();
	 Exec pInsETLLog 
	      @ETLAction = 'pETLSyncDimProcedures'
	     ,@ETLLogMessage = @ErrorMessage;
    Set @RC = -1
  End Catch
  Return @RC;
 End
go
/* Testing Code:
 Exec pETLSyncDimProcedures;
 Select * From DimProcedures;
*/

/****** [dbo].[DimClinics] ******/
go 
Create or Alter View vETLDimClinics
/* Author: Tyler Coutermarsh
** Desc: Extracts and transforms data for DimProcedures
** Change Log: When,Who,What
** 2025-03-12, Tyler Coutermarsh,Created Sproc.
*/
As
    Select
    [ClinicID] = c.ClinicID
   ,[ClinicName] = CAST(c.ClinicName as nvarchar(100))
   ,[ClinicCity] = CAST(c.City as nvarchar(100))
   ,[ClinicState] = CAST(c.State as nvarchar(100))
   ,[ClinicZip] = CAST(c.Zip as nvarchar(5))
    From [DoctorsSchedules].dbo.Clinics as c;
go

/* Testing Code:
 Select * From vETLDimClinics;
*/


Create Or Alter Procedure pETLSyncDimClinics
/* Author: TCoutermarsh
** Desc: Updates data in DimProcedures using the vETLDimClinics view
** Change Log: When,Who,What
** 2025-03-12,TCoutermarsh,Created Sproc.
*/
AS 
BEGIN 
  Declare @RC int;
  Begin Try
    Begin Tran;
		  Merge Into DimClinics as tc
		  Using vETLDimClinics as vc
		  	ON tc.ClinicID = vc.ClinicID
		  	When Not Matched 
		  		Then -- The ID in the Source is not found the the Target
		  			INSERT 
		  			VALUES ( vc.ClinicID, vc.ClinicName, vc.ClinicCity, vc.ClinicState, vc.ClinicZip )
		  	When Matched -- When the IDs match for the row currently being looked 
		  	AND ( vc.ClinicName <> tc.ClinicName  
		  		OR vc.ClinicCity <> tc.ClinicCity
				OR vc.ClinicState <> tc.ClinicState
				OR vc.ClinicZip <> tc.ClinicZip) 
		  		Then 
		  			UPDATE -- It know your target, so you dont specify the DimClinics
		  			SET tc.ClinicName = vc.ClinicName
		  			  , tc.ClinicCity = vc.ClinicCity
					  , tc.ClinicState = vc.ClinicState
					  , tc.ClinicZip = vc.ClinicZip
		  	When Not Matched By Source 
		  		Then -- The ClinicID is in the Target table, but not the source table
		  			DELETE
		  ; -- The merge statement demands a semicolon at the end!
    Commit Tran;
    -- ETL Logging Code --
    Exec pInsETLLog
	        @ETLAction = 'pETLSyncDimClinics'
	       ,@ETLLogMessage = 'DimClinics synced';
    Set @RC = +1
  End Try
  Begin Catch
     Declare @ErrorMessage nvarchar(1000) = Error_Message();
	 Exec pInsETLLog 
	      @ETLAction = 'pETLSyncDimClinics'
	     ,@ETLLogMessage = @ErrorMessage;
    Set @RC = -1
  End Catch
  Return @RC;
 End
go
/* Testing Code:
 Exec pETLSyncDimClinics;
 Select * From DimClinics;
*/

/****** [dbo].[DimShifts] ******/
go 
Create or Alter View vETLDimShifts
/* Author: Tyler Coutermarsh
** Desc: Extracts and transforms data for DimShifts
** Change Log: When,Who,What
** 2025-03-12, Tyler Coutermarsh,Created Sproc.
*/
As
    Select
    [ShiftID] = s.ShiftID
   ,[ShiftStart] = CAST(s.ShiftStart as time(0))
   ,[ShiftEnd] = CAST(s.ShiftEnd as time(0))
    From [DoctorsSchedules].dbo.Shifts as s;
go

/* Testing Code:
 Select * From vETLDimShifts;
*/


Create Or Alter Procedure pETLSyncDimShifts
/* Author: TCoutermarsh
** Desc: Updates data in DimProcedures using the vETLDimShifts view
** Change Log: When,Who,What
** 2025-03-12,TCoutermarsh,Created Sproc.
*/
AS 
BEGIN 
  Declare @RC int;
  Begin Try
    Begin Tran;
		  Merge Into DimShifts as ts
		  Using vETLDimshifts as vs
		  	ON ts.ShiftID = vs.ShiftID
		  	When Not Matched 
		  		Then -- The ID in the Source is not found the the Target
		  			INSERT 
		  			VALUES ( vs.ShiftID, vs.ShiftStart, vs.ShiftEnd )
		  	When Matched -- When the IDs match for the row currently being looked 
		  	AND ( vs.ShiftStart <> ts.ShiftStart
				OR vs.ShiftEnd <> ts.ShiftEnd) 
		  		Then 
		  			UPDATE -- It know your target, so you dont specify the DimClinics
		  			SET ts.ShiftID = vs.ShiftID
		  			  , ts.ShiftStart = vs.ShiftStart
					  , ts.ShiftEnd = vs.ShiftEnd
		  	When Not Matched By Source 
		  		Then -- The ShiftID is in the Target table, but not the source table
		  			DELETE
		  ; -- The merge statement demands a semicolon at the end!
    Commit Tran;
    -- ETL Logging Code --
    Exec pInsETLLog
	        @ETLAction = 'pETLSyncDimShifts'
	       ,@ETLLogMessage = 'DimShifts synced';
    Set @RC = +1
  End Try
  Begin Catch
     Declare @ErrorMessage nvarchar(1000) = Error_Message();
	 Exec pInsETLLog 
	      @ETLAction = 'pETLSyncDimShifts'
	     ,@ETLLogMessage = @ErrorMessage;
    Set @RC = -1
  End Catch
  Return @RC;
 End
go

/* Testing Code:
 Exec pETLSyncDimShifts;
 Select * From DimShifts;
*/

/****** [dbo].[DimDoctors] ******/
go 
Create or Alter View vETLDimDoctors
/* Author: Tyler Coutermarsh
** Desc: Extracts and transforms data for DimDoctors
** 2025-03-12, Tyler Coutermarsh,Created Sproc.
*/
As
    Select
    [DoctorID] = d.DoctorID
   ,[DoctorFullName] = CAST(CONCAT(d.FirstName,' ',d.LastName) AS varchar(100))
   ,[DoctorEmailAddress] = CAST(d.EmailAddress as nvarchar(200))
   ,[DoctorCity] = CAST(d.City as nvarchar(100))
   ,[DoctorState] = CAST(d.State as nvarchar(100))
   ,[DoctorZip] = CAST(d.Zip as nvarchar(5))
    From [DoctorsSchedules].dbo.Doctors as d;
go

/* Testing Code:
 Select * From vETLDimDoctors;
*/


Create Or Alter Procedure pETLSyncDimDoctors
/* Author: TCoutermarsh
** Desc: Updates data in DimProcedures using the vETLDimDoctors view
** Change Log: When,Who,What
** 2025-03-12,TCoutermarsh,Created Sproc.
*/
AS 
BEGIN 
  Declare @RC int;
  Begin Try
    Begin Tran;
		  Merge Into DimDoctors as td
		  Using vETLDimdoctors as vd
		  	ON td.DoctorID = vd.DoctorID
		  	When Not Matched 
		  		Then -- The ID in the Source is not found the the Target
		  			INSERT 
		  			VALUES ( vd.DoctorID, vd.DoctorFullName, vd.DoctorEmailAddress, vd.DoctorCity, vd.DoctorState, vd.DoctorZip )
		  	When Matched -- When the IDs match for the row currently being looked 
		  	AND ( vd.DoctorID <> td.DoctorID  
		  		OR vd.DoctorFullName <> td.DoctorFullName
				OR vd.DoctorEmailAddress <> td.DoctorEmailAddress
				OR vd.DoctorCity <> td.DoctorCity
				OR vd.DoctorState <> td.DoctorState
				OR vd.DoctorZip <> td.DoctorZip) 
		  		Then 
		  			UPDATE -- It know your target, so you dont specify the DimDoctors
		  			SET td.DoctorFullName = vd.DoctorFullName
		  			  , td.DoctorEmailAddress = vd.DoctorEmailAddress
					  , td.DoctorCity = vd.DoctorCity
					  , td.DoctorState = vd.DoctorState
					  , td.DoctorZip = vd.DoctorZip
		  	When Not Matched By Source 
		  		Then -- The DoctorID is in the Target table, but not the source table
		  			DELETE
		  ; -- The merge statement demands a semicolon at the end!
    Commit Tran;
    -- ETL Logging Code --
    Exec pInsETLLog
	        @ETLAction = 'pETLSyncDimDoctors'
	       ,@ETLLogMessage = 'DimDoctors synced';
    Set @RC = +1
  End Try
  Begin Catch
     Declare @ErrorMessage nvarchar(1000) = Error_Message();
	 Exec pInsETLLog 
	      @ETLAction = 'pETLSyncDimDoctors'
	     ,@ETLLogMessage = @ErrorMessage;
    Set @RC = -1
  End Catch
  Return @RC;
 End
go

/* Testing Code:
 Exec pETLSyncDimDoctors;
 Select * From DimDoctors;
*/

/****** [dbo].[FactShifts] ******/
go 
Create or Alter View vETLFactDoctorShifts
/* Author: Tyler Coutermarsh
** Desc: Extracts and transforms data for FactShifts
** Change Log: When,Who,What
** 2025-03-12, Tyler Coutermarsh,Created Sproc.
*/
As
    Select
    [DoctorsShiftID] = ds.DoctorsShiftID
   ,[ShiftDateKey] = Cast(Convert(nvarchar(50), ds.ShiftDate, 112) as int)
   ,[ClinicKey] = dc.ClinicKey
   ,[ShiftKey] = dsss.ShiftKey
   ,[DoctorKey] = dd.DoctorKey
   ,[HoursWorked] = CAST(DATEDIFF(HOUR, s.ShiftStart, s.ShiftEnd) as int)
  From [DoctorsSchedules].dbo.DoctorShifts as ds
  Join [DoctorsSchedules].dbo.Shifts as s
   On s.ShiftID = ds.ShiftID
  Join DimClinics as dc
   On dc.ClinicID = ds.ClinicID
  Join DimDoctors as dd
   On dd.DoctorID = ds.DoctorID
  Join DimShifts as dsss
   On dsss.ShiftID = ds.ShiftID
  ;
go

/* Testing Code:
 Select * From vETLFactDoctorShifts;
*/

go
Create or Alter Procedure pETLSyncFactDoctorShifts
/* Author: Tyler Coutermarsh
** Desc: Inserts data into FactDoctorShifts
** Change Log: When,Who,What
** 2025-03-13, Tyler Coutermash,Created Sproc.
*/
As
 Begin
  Declare @RC int = 0;
  Begin Try
    Begin Tran;
    -- ETL Processing Code --
  Merge Into FactDoctorShifts as tfd
  Using vETLFactDoctorShifts as vfd
      ON tfd.DoctorsShiftID = vfd.DoctorsShiftID
	  AND tfd.ClinicKey = vfd.ClinicKey
	  AND tfd.ShiftKey = vfd.ShiftKey
	  AND tfd.DoctorKey = vfd.DoctorKey
	  When Not Matched
	      Then
		      INSERT ( DoctorsShiftID, ShiftDateKey, ClinicKey, ShiftKey, DoctorKey, HoursWorked )
			  VALUES ( vfd.DoctorsShiftID, vfd.ShiftDateKey, vfd.ClinicKey, vfd.ShiftKey, vfd.DoctorKey, vfd.HoursWorked )
	When Matched
	       AND (vfd.ShiftDateKey <> tfd.ShiftDateKey
		   OR vfd.HoursWorked <> tfd.HoursWorked)
		 Then
		     UPDATE
			 SET tfd.ShiftDateKey = vfd.ShiftDateKey
				,tfd.HoursWorked = vfd.HoursWorked
	When Not Matched By Source
	     Then
		  DELETE
	;
	Commit Tran;
    -- ETL Logging Code --
    Exec pInsETLLog
	        @ETLAction = 'pETLSyncFactDoctorShifts'
	       ,@ETLLogMessage = 'FactDoctorShifts synced';
    Set @RC = +1
  End Try
  Begin Catch
     Declare @ErrorMessage nvarchar(1000) = Error_Message();
	 Exec pInsETLLog 
	      @ETLAction = 'pETLSyncFactDoctorShifts'
	     ,@ETLLogMessage = @ErrorMessage;
    Set @RC = -1
  End Catch
  Return @RC;
 End
go

/* Testing Code:
 Exec pETLSyncFactDoctorShifts;
 Select * From FactDoctorShifts;
*/
go

/****** [dbo].[FactVisits] ******/
go 
Create or Alter View vETLFactVisits
/* Author: Tyler Coutermarsh
** Desc: Extracts and transforms data for FactVisits
** Change Log: When,Who,What
** 2025-03-12, Tyler Coutermarsh,Created Sproc.
*/
As
    Select
	[VisitKey] = v.ID
   ,[DateKey] = Cast(Convert(nvarchar(50), v.Date, 112) as int)
   ,[ClinicKey] = dc.ClinicKey
   ,[PatientKey] = dp.PatientKey
   ,[DoctorKey] = dd.DoctorKey
   ,[ProcedureKey] = dpr.ProcedureKey
   ,[ProcedureVistCharge] = v.Charge
  From [Patients].dbo.Visits as v
  Join DimClinics as dc
   On dc.ClinicID = v.Clinic
  Join DimPatients as dp
   On dp.PatientID = v.Patient
  Join DimDoctors as dd
   On dd.DoctorID = v.Doctor
  Join DimProcedures as dpr
   On dpr.ProcedureID = v.[Procedure]
  Where dp.IsCurrent = 1
  ;
go

/* Testing Code:
 Select * From vETLFactVisits;
*/

go
Create or Alter Procedure pETLFactVisits
/* Author: Tyler Coutermarsh
** Desc: Inserts data into FactVisits
** Change Log: When,Who,What
** 2025-03-15, Tyler Coutermash,Created Sproc.
*/
As
 Begin
  Declare @RC int = 0;
  Begin Try
    -- ETL Processing Code --
	    Begin Tran;
  Merge Into FactVisits as tfv
  Using vETLFactVisits as vfv
      ON  tfv.VisitKey = vfv.VisitKey
	  AND tfv.ClinicKey = vfv.ClinicKey
	  AND tfv.PatientKey = vfv.PatientKey
	  AND tfv.DoctorKey = vfv.DoctorKey
	  AND tfv.ProcedureKey = vfv.ProcedureKey
	  When Not Matched
	      Then
		      INSERT ( VisitKey, DateKey, ClinicKey, PatientKey, DoctorKey, ProcedureKey, ProcedureVistCharge )
			  VALUES ( vfv.VisitKey, vfv.DateKey, vfv.ClinicKey, vfv.PatientKey, vfv.DoctorKey, vfv.ProcedureKey, vfv.ProcedureVistCharge )
	When Matched
	       AND (vfv.DateKey <> tfv.DateKey
		   OR vfv.ProcedureVistCharge <> tfv.ProcedureVistCharge)
		 Then
		     UPDATE
			 SET tfv.DateKey = vfv.DateKey
				,tfv.ProcedureVistCharge = vfv.ProcedureVistCharge
	When Not Matched By Source
	     Then
		     DELETE
	;
	Commit Tran;
    -- ETL Logging Code --
    Exec pInsETLLog
	        @ETLAction = 'pETLSyncFactVisits'
	       ,@ETLLogMessage = 'FactVisits Synced';
    Set @RC = +1
  End Try
  Begin Catch
     Declare @ErrorMessage nvarchar(1000) = Error_Message();
	 Exec pInsETLLog 
	      @ETLAction = 'pETLSyncFactVisits'
	     ,@ETLLogMessage = @ErrorMessage;
    Set @RC = -1
  End Catch
  Return @RC;
 End
go

/* Testing Code:
 Exec pETLFactVisits;
 Select * From FactVisits;
*/
go

--********************************************************************--
-- Review the results of this script
--********************************************************************--
go
Declare @Status int = 0;
Exec @Status = pETLFillDimDates;
Select [Object] = 'pETLFillDimDates', [Status] = @Status;

Exec @Status = pETLSyncDimPatients;
Select [Object] = 'pETLSyncDimPatients', [Status] = @Status;

Exec @Status = pETLSyncDimProcedures;
Select [Object] = 'pETLSyncDimProcedures', [Status] = @Status;

Exec @Status = pETLSyncDimClinics;
Select [Object] = 'pETLSyncDimClinics', [Status] = @Status;

Exec @Status = pETLSyncDimShifts;
Select [Object] = 'pETLSyncDimShifts', [Status] = @Status;

Exec @Status = pETLSyncDimDoctors;
Select [Object] = 'pETLSyncDimDoctors', [Status] = @Status;

Exec @Status = pETLSyncFactDoctorShifts;
Select [Object] = 'pETLSyncFactDoctorShifts', [Status] = @Status;

Exec @Status = pETLFactVisits;
Select [Object] = 'pETLFactVisits', [Status] = @Status;

go
Select * from DimDates;
Select * from DimClinics;
Select * from DimDoctors;
Select * from DimShifts;
Select * from FactDoctorShifts;
Select * from DimProcedures;
Select * from DimPatients;
Select * from FactVisits;



