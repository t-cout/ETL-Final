Use DWClinicReportDataTylerCoutermarsh;
go

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