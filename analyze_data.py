import pandas as pd

try:
    df = pd.read_excel('/Users/shintaro/work/ye/gas_sensor/ガス感度データ サンプル.xlsx')
    print("Columns:", df.columns.tolist())
    print("First 3 rows:")
    print(df.head(3))
    print("\nData Types:")
    print(df.dtypes)
except Exception as e:
    print(e)
