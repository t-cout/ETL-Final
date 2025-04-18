# # -------------------------------------------------- #
# # Title: Reporting Views ETL
# # Description: Writing and Reading Data from a file
# # ChangeLog (Who,When,What):
# # TCoutermarsh,3.15.2025,Created started script
# # -------------------------------------------------- #

import os
import pyodbc
import pandas as pd
from openpyxl import Workbook
from datetime import datetime

def create_clinic_report():
    # Define file path
    date_str = datetime.today().strftime('%Y-%m-%d')
    folder_path = r"C:/_BISolutions/ETLFinalTCoutermarsh/Reports"
    file_name = f"ClinicReportsData_{date_str}.xlsx"
    file_path = os.path.join(folder_path, file_name)
    
    # Debugging: Print the folder path
    print(f"Attempting to create report in: {folder_path}")
    
    # Ensure directory exists
    if not os.path.exists(folder_path):
        print(f"Directory does not exist. Creating: {folder_path}")
        os.makedirs(folder_path, exist_ok=True)
    else:
        print(f"Directory already exists: {folder_path}")
    
    return file_path

if __name__ == "__main__":
    output_file = create_clinic_report()  # Get the correct file path

    # Connect to SQL
    conn_str = ("Driver={ODBC Driver 17 for SQL Server};"
                "Server=localhost;"
                "Database=DWClinicReportDataTylerCoutermarsh;"
                "Trusted_Connection=yes;")
    
    try:
        con_obj = pyodbc.connect(conn_str)
        print("Database connection successful!")

        # SQL queries for the views
        rptDoctorShifts = "SELECT * FROM vRptDoctorShifts"
        rptPatientsVisits = "SELECT * FROM vRptPatientVisits"

        # Fetch data from SQL views
        df1 = pd.read_sql(rptDoctorShifts, con_obj)
        df2 = pd.read_sql(rptPatientsVisits, con_obj)

        # Write to Excel file with multiple sheets
        with pd.ExcelWriter(output_file, engine="openpyxl") as writer:
            df1.to_excel(writer, sheet_name="rptDoctorShifts", index=False)
            df2.to_excel(writer, sheet_name="rptPatientVisits", index=False)

        print(f"Excel file '{output_file}' generated successfully!")

    except Exception as e:
        print(f"Error: {e}")

    finally:
        # Close the database connection
        con_obj.close()
        print("Database connection closed.")

