import pandas as pd
import os
import psycopg2
from psycopg2.extras import execute_values
import math

# Configuration - Update these with your Supabase connection details
# Found in: Dashboard > Project Settings > Database > Connection parameters
DB_HOST = os.getenv("SUPABASE_DB_HOST", "db.vcsisykedsnjnjpdzlqi.supabase.co")
DB_NAME = os.getenv("SUPABASE_DB_NAME", "postgres")
DB_USER = os.getenv("SUPABASE_DB_USER", "postgres")
DB_PASS = os.getenv("SUPABASE_DB_PASS", "VNFyTJe1Jv2mISP1") # プロジェクト作成時のパスワード
DB_PORT = os.getenv("SUPABASE_DB_PORT", "5432")

EXCEL_FILE = '/Users/shintaro/work/ye/gas_sensor/ガス感度データ サンプル.xlsx'

def connect_db():
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASS,
            port=DB_PORT,
            sslmode='require'
        )
        return conn
    except Exception as e:
        print(f"Error connecting to DB: {e}")
        return None

def clean_float(val):
    if pd.isna(val):
        return None
    s_val = str(val).strip()
    if s_val == '-' or s_val == '':
        return None
    try:
        return float(val)
    except ValueError:
        return None

def import_data():
    print(f"Reading {EXCEL_FILE}...")
    df = pd.read_excel(EXCEL_FILE)
    
    conn = connect_db()
    if not conn:
        print("Skipping DB import (no connection). Generating SQL file instead.")
        generate_sql_inserts(df)
        return

    cursor = conn.cursor()

    # 1. Import Sites
    print("Importing Sites...")
    sites = df[['納入先コード', '納入先名']].drop_duplicates()
    site_map = {} # code -> uuid
    
    for _, row in sites.iterrows():
        code = str(row['納入先コード'])
        name = row['納入先名']
        
        cursor.execute(
            "INSERT INTO sites (code, name) VALUES (%s, %s) ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name RETURNING id",
            (code, name)
        )
        site_id = cursor.fetchone()[0]
        site_map[code] = site_id
    
    conn.commit()
    print(f"Imported {len(site_map)} sites.")

    # 2. Import Equipments
    print("Importing Equipments...")
    equipments = df[['納入先コード', 'TAGNO', 'シリアルNO', '製品名', '検知原理', '検知ガス', '検知範囲1']].drop_duplicates(subset=['納入先コード', 'TAGNO'])
    equipment_map = {} # (site_code, tag_no) -> uuid

    for _, row in equipments.iterrows():
        site_code = str(row['納入先コード'])
        if site_code not in site_map:
            continue
            
        site_id = site_map[site_code]
        tag_no = str(row['TAGNO'])
        
        cursor.execute("""
            INSERT INTO equipments (site_id, tag_no, serial_no, model_name, sensor_type, gas_name, full_scale)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (site_id, tag_no) DO UPDATE SET
                serial_no = EXCLUDED.serial_no,
                model_name = EXCLUDED.model_name,
                sensor_type = EXCLUDED.sensor_type,
                gas_name = EXCLUDED.gas_name,
                full_scale = EXCLUDED.full_scale
            RETURNING id
        """, (
            site_id, 
            tag_no, 
            str(row['シリアルNO']) if not pd.isna(row['シリアルNO']) else None,
            row['製品名'],
            row['検知原理'],
            row['検知ガス'],
            clean_float(row['検知範囲1'])
        ))
        
        eq_id = cursor.fetchone()[0]
        equipment_map[(site_code, tag_no)] = eq_id
    
    conn.commit()
    print(f"Imported {len(equipment_map)} equipments.")

    # 3. Import Inspections
    print("Importing Inspections...")
    inspection_count = 0
    
    for _, row in df.iterrows():
        site_code = str(row['納入先コード'])
        tag_no = str(row['TAGNO'])
        key = (site_code, tag_no)
        
        if key not in equipment_map:
            continue
            
        eq_id = equipment_map[key]
        
        # Determine if sensor was replaced (heuristic: sensitivity near 100% or explicit note?)
        # For now, we don't have an explicit column, so we'll rely on sensitivity logic in SQL later
        # or if '備考' contains '交換'
        is_replaced = False
        if not pd.isna(row['備考']) and '交換' in str(row['備考']):
            is_replaced = True
            
        cursor.execute("""
            INSERT INTO inspections (equipment_id, inspection_date, gas_sensitivity, adjustment_before, adjustment_after, is_sensor_replaced, result)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
        """, (
            eq_id,
            row['作業完了日'],
            clean_float(row['ガス感度']),
            clean_float(row['調整前値']),
            clean_float(row['調整後値']),
            is_replaced,
            row['総合判定']
        ))
        inspection_count += 1
        
    conn.commit()
    print(f"Imported {inspection_count} inspections.")
    conn.close()

def generate_sql_inserts(df):
    print("Generating SQL inserts to 'scripts/seed_data.sql'...")
    with open('scripts/seed_data.sql', 'w') as f:
        f.write("-- Generated Seed Data\n")
        f.write("-- Copy and paste this into Supabase SQL Editor to import data.\n\n")
        
        # 1. Sites
        f.write("-- 1. Sites\n")
        sites = df[['納入先コード', '納入先名']].drop_duplicates()
        for _, row in sites.iterrows():
            code = str(row['納入先コード'])
            name = row['納入先名']
            f.write(f"INSERT INTO sites (code, name) VALUES ('{code}', '{name}') ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name;\n")
        
        f.write("\n-- 2. Equipments\n")
        equipments = df[['納入先コード', 'TAGNO', 'シリアルNO', '製品名', '検知原理', '検知ガス', '検知範囲1']].drop_duplicates(subset=['納入先コード', 'TAGNO'])
        
        for _, row in equipments.iterrows():
            site_code = str(row['納入先コード'])
            tag_no = str(row['TAGNO'])
            serial = f"'{row['シリアルNO']}'" if not pd.isna(row['シリアルNO']) else "NULL"
            model = row['製品名']
            sensor_type = row['検知原理']
            gas = row['検知ガス']
            fs = row['検知範囲1'] if not pd.isna(row['検知範囲1']) else "NULL"
            
            # Use subquery to find site_id
            f.write(f"""
INSERT INTO equipments (site_id, tag_no, serial_no, model_name, sensor_type, gas_name, full_scale)
SELECT id, '{tag_no}', {serial}, '{model}', '{sensor_type}', '{gas}', {fs}
FROM sites WHERE code = '{site_code}'
ON CONFLICT (site_id, tag_no) DO UPDATE SET
    serial_no = EXCLUDED.serial_no,
    model_name = EXCLUDED.model_name,
    sensor_type = EXCLUDED.sensor_type,
    gas_name = EXCLUDED.gas_name,
    full_scale = EXCLUDED.full_scale;
""")

        f.write("\n-- 3. Inspections\n")
        for _, row in df.iterrows():
            site_code = str(row['納入先コード'])
            tag_no = str(row['TAGNO'])
            
            date = row['作業完了日']
            sensitivity = row['ガス感度'] if not pd.isna(row['ガス感度']) else "NULL"
            adj_before = row['調整前値'] if not pd.isna(row['調整前値']) else "NULL"
            adj_after = row['調整後値'] if not pd.isna(row['調整後値']) else "NULL"
            result = row['総合判定']
            
            is_replaced = 'FALSE'
            if not pd.isna(row['備考']) and '交換' in str(row['備考']):
                is_replaced = 'TRUE'

            # Use subquery to find equipment_id based on site_code and tag_no
            f.write(f"""
INSERT INTO inspections (equipment_id, inspection_date, gas_sensitivity, adjustment_before, adjustment_after, is_sensor_replaced, result)
SELECT e.id, '{date}', {sensitivity}, {adj_before}, {adj_after}, {is_replaced}, '{result}'
FROM equipments e
JOIN sites s ON e.site_id = s.id
WHERE s.code = '{site_code}' AND e.tag_no = '{tag_no}';
""")

if __name__ == "__main__":
    import_data()
