# # -------------------------------------------------- #
# # Title: Email Validator and Processor
# # Description: Writing and Reading Data from a file
# # ChangeLog (Who,When,What):
# # TCoutermarsh,3.2.2025,Created started script
# # -------------------------------------------------- #
# # re is Python's regular expressions module 

import csv
import os
import re

# Regular expression to validate emails
strRegex = r'^([\w\.-]+)@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.)|(([\w-]+\.)+))([a-zA-Z]{2,4}|[0-9]{1,3})(\]?)$'

# Define output file paths
strValidDataFileName = "C:/_BISolutions/ETLFinalTCoutermarsh/DataFiles/ValidData.csv"
strInvalidDataFileName = "C:/_BISolutions/ETLFinalTCoutermarsh/DataFiles/BadData.csv"

# Define file paths for CSV files
source_files = [
    r"C:\_BISolutions\ETLFinalTCoutermarsh\DataFiles\ClinicDailyData\Bellevue\20100102NewPatients.csv",
    r"C:\_BISolutions\ETLFinalTCoutermarsh\DataFiles\ClinicDailyData\Kirkland\20100102NewPatients.csv",
    r"C:\_BISolutions\ETLFinalTCoutermarsh\DataFiles\ClinicDailyData\Redmond\20100102NewPatients.csv"
]

# Variable to store aggregated data
aggregated_data = []
header = None  # To store the header row

# Read and combine all CSV files
for file in source_files:
    if os.path.exists(file):  # Check if file exists
        with open(file, mode='r', newline='', encoding='utf-8') as f:
            reader = csv.reader(f)
            file_header = next(reader)  # Read header

            if header is None:  # Store header only once
                header = file_header
                aggregated_data.append(header)

            # Read and store all rows
            for row in reader:
                aggregated_data.append(row)
    else:
        print(f"❌ Warning: {file} not found.")

# Open files for writing valid/invalid emails
with open(strValidDataFileName, mode='w', newline='', encoding='utf-8') as valid_file, \
     open(strInvalidDataFileName, mode='w', newline='', encoding='utf-8') as invalid_file:

    valid_writer = csv.writer(valid_file)
    invalid_writer = csv.writer(invalid_file)

    # Write header to both files
    valid_writer.writerow(header)
    invalid_writer.writerow(header)

    intValidCounter = 0
    intInValidCounter = 0

    # Validate emails (assuming email is in column index 2)
    for row in aggregated_data[1:]:  # Skip header
        email = row[2]  # Adjust if email column is in a different position
        if re.match(strRegex, email):  
            valid_writer.writerow(row)
            intValidCounter += 1
        else:  
            invalid_writer.writerow(row)
            intInValidCounter += 1

# Print results
print("\n✅ Processing Complete!")
print("Number of Valid Rows Processed:", intValidCounter)
print("Number of Invalid Rows Processed:", intInValidCounter)

