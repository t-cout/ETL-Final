# ETL-Final
This project is the ETL Final from my certification at the University of Washington for Business Intelligence &amp; Data Migration. The project is of a full ETL pipeline. Taken from a real life scenario, where a business that tracks and uploads data for their three clinics in Washington are in need of a full ETL automative process.

Overview

The ETL process, extracts and transforms data from the company's source by using SQL and Python inside SSIS packages to clean/transform the data before inserting into the correct location in the database.

A reporting datawarehouse is created using the OLAP star schema format, extracting and transforming data from the database into the new reporting datawarehouse.

Another SSIS package containing a python script is used to generate the results from reporting views into excel files for users in the company.

An SSRS dashboard is created to track the daily ETL status from the ETL logging data inside the ETL processing script.

Components

The project contains the following components:
- The Visual Studio solution
- The BI Solution Worksheet
- The Business’s Daily Data
- The Admin Manual Document
- The File-Based ETL
- The Data Warehouse ETL
- The Non-SQL ETL
- The SQL Server Agent Jobs
- The ETL Reporting Dashboard
- The Database Restoration Script
