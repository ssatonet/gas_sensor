import pandas as pd
import os

EXCEL_FILE = '/Users/shintaro/work/ye/gas_sensor/ガス感度データ サンプル.xlsx'

def analyze():
    if not os.path.exists(EXCEL_FILE):
        print(f"File not found: {EXCEL_FILE}")
        return

    print(f"Analyzing {EXCEL_FILE}...\n")
    df = pd.read_excel(EXCEL_FILE)

    # 1. Overview
    total_records = len(df)
    unique_sites = df['納入先名'].nunique()
    unique_models = df['製品名'].nunique()
    total_sensors = len(df.drop_duplicates(subset=['納入先コード', 'TAGNO']))

    print("## 1. データ概要")
    print(f"- 総レコード数: {total_records}")
    print(f"- 納入先数: {unique_sites}")
    print(f"- センサー数 (ユニーク): {total_sensors}")
    print(f"- 製品モデル数: {unique_models}")
    print("\n")

    # 2. Model Distribution
    print("## 2. 製品モデル別 センサー数")
    sensors_per_model = df.drop_duplicates(subset=['納入先コード', 'TAGNO'])['製品名'].value_counts()
    print(sensors_per_model.to_markdown())
    print("\n")

    # 3. Gas Distribution
    print("## 3. 検知ガス別 センサー数")
    sensors_per_gas = df.drop_duplicates(subset=['納入先コード', 'TAGNO'])['検知ガス'].value_counts()
    print(sensors_per_gas.to_markdown())
    print("\n")

    # 4. Inspection Results
    print("## 4. 点検結果の内訳")
    result_counts = df['総合判定'].value_counts()
    print(result_counts.to_markdown())
    print("\n")

    # 5. Sensitivity Analysis (Latest inspection per sensor)
    print("## 5. 最新点検時の平均感度 (モデル別)")
    # Sort by date
    df['作業完了日'] = pd.to_datetime(df['作業完了日'])
    df_sorted = df.sort_values(['納入先コード', 'TAGNO', '作業完了日'])
    
    # Get latest
    latest_df = df_sorted.drop_duplicates(subset=['納入先コード', 'TAGNO'], keep='last')
    
    # Filter valid sensitivity
    valid_sens = latest_df[pd.to_numeric(latest_df['ガス感度'], errors='coerce').notnull()]
    valid_sens['ガス感度'] = pd.to_numeric(valid_sens['ガス感度'])
    
    avg_sens_per_model = valid_sens.groupby('製品名')['ガス感度'].mean().round(1).sort_values(ascending=False)
    print(avg_sens_per_model.to_markdown())
    print("\n")

    # 6. Low Sensitivity Sensors (Potential Replacements)
    print("## 6. 要注意センサー (感度 60%未満)")
    low_sens = valid_sens[valid_sens['ガス感度'] < 60]
    if low_sens.empty:
        print("該当なし")
    else:
        print(low_sens[['納入先名', 'TAGNO', '製品名', 'ガス感度', '作業完了日']].sort_values('ガス感度').to_markdown(index=False))

if __name__ == "__main__":
    analyze()
