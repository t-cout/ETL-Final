/***************************************************************************
ETL Final Project: DWClinicReportData_TylerCoutermarsh
Dev: TCoutermarsh
Date:3/15/2025
Desc: These are reporting views of doctor shifts and patient vists
ChangeLog: (Who, When, What) 
	TCoutermarsh, 3/15/2025, Created Script
*****************************************************************************************/
Use DWClinicReportDataTylerCoutermarsh;
go

If (OBJECT_ID('vRptDoctorShifts') is not null) Drop View vRptDoctorShifts;
go

Create or Alter View vRptDoctorShifts
/* Author: Tyler Coutermarsh
** Desc: Creates reporting view for doctor shifts
** Change Log: When,Who,What
** 2025-03-15, Tyler Coutermarsh, Created View.
*/
As
Select
 [ShiftDate] = Cast(dd.FullDate as date)
,[ClinicName] = dc.ClinicName
,[ClinicCity] = dc.ClinicCity
,[ClinicState] = dc.ClinicState
,[ShiftID] = ds.ShiftID
,[ShiftStart] = ds.ShiftStart
,[ShiftEnd] = ds.ShiftEnd
,[DoctorID] = ddc.DoctorID
,[DoctorName] = ddc.DoctorFullName
,[HoursWorked] = fds.HoursWorked
From FactDoctorShifts as fds
Join DimDates as dd
 On fds.ShiftDateKey = dd.DateKey
Join DimClinics as dc
 On fds.ClinicKey = dc.ClinicKey
Join DimShifts as ds
 On fds.ShiftKey = ds.ShiftKey
Join DimDoctors as ddc
 On fds.DoctorKey = ddc.DoctorKey;
 go

 If (OBJECT_ID('vRptPatientVisits') is not null) Drop View vRptPatientVisits;
go

 Create or Alter View vRptPatientVisits
/* Author: Tyler Coutermarsh
** Desc: Creates reporting view for patient visits
** Change Log: When,Who,What
** 2025-03-15, Tyler Coutermarsh, Created View.
*/
As
Select
 [VisitDate] = Cast(dd.FullDate as date)
,[PatientID] = dp.PatientID
,[PatientName] = dp.PatientFullName
,[DoctorID] = dds.DoctorID
,[DoctorName] = dds.DoctorFullName
,[ClinicKey] = dc.ClinicID
,[ClinicName] = dc.ClinicName
,[ClinicCity] = dc.ClinicCity
,[CliincState] = dc.ClinicState
,[ProcedureID] = dps.ProcedureID
,[ProcedureName] = dps.ProcedureName
,[ProcedureDesc] = dps.ProcedureDesc
,[ProcedureVisitsCharge] = fvs.ProcedureVistCharge
From FactVisits as fvs
Join DimDates as dd
 On fvs.DateKey = dd.DateKey
Join DimPatients as dp
 On fvs.PatientKey = dp.PatientKey
Join DimDoctors as dds
 On fvs.DoctorKey = dds.DoctorKey
Join DimClinics as dc
 On fvs.ClinicKey = dc.ClinicKey
Join DimProcedures as dps
 On fvs.ProcedureKey = dps.ProcedureKey;
 go

--Test Views
 Select * From vRptDoctorShifts

 Select * From vRptPatientVisits
