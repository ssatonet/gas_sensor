import pandas as pd
import os

file_path = '/Users/shintaro/work/ye/gas_sensor/kaiseki.xlsx'

if not os.path.exists(file_path):
    print(f"File not found: {file_path}")
    exit(1)

try:
    xls = pd.ExcelFile(file_path)
    print(f"Sheet names: {xls.sheet_names}")

    for sheet_name in xls.sheet_names:
        print(f"\n--- Sheet: {sheet_name} ---")
        df = pd.read_excel(xls, sheet_name=sheet_name)
        print(f"Columns: {df.columns.tolist()}")
        print("First 15 rows:")
        print(df.head(15).to_string())
        print("\nData Types:")
        print(df.dtypes)
        print("\nSummary Statistics:")
        print(df.describe().to_string())

except Exception as e:
    print(f"Error reading Excel file: {e}")
