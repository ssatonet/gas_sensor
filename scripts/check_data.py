import os
import psycopg2
import pandas as pd

# Configuration (Same as import_data.py)
DB_HOST = os.getenv("SUPABASE_DB_HOST", "db.vcsisykedsnjnjpdzlqi.supabase.co")
DB_NAME = os.getenv("SUPABASE_DB_NAME", "postgres")
DB_USER = os.getenv("SUPABASE_DB_USER", "postgres")
DB_PASS = os.getenv("SUPABASE_DB_PASS", "VNFyTJe1Jv2mISP1")
DB_PORT = os.getenv("SUPABASE_DB_PORT", "5432")

def check_data():
    try:
        # Resolve hostname to IPv4 using getaddrinfo to strictly enforce IPv4
        import socket
        import sys
        
        try:
            # Force IPv4 resolution
            ip_infos = socket.getaddrinfo(DB_HOST, None, family=socket.AF_INET, type=socket.SOCK_STREAM)
            if ip_infos:
                host_ip = ip_infos[0][4][0]
                print(f"Resolved {DB_HOST} to {host_ip}")
            else:
                print(f"Warning: No IPv4 address found for {DB_HOST}")
                host_ip = DB_HOST
        except Exception as e:
            print(f"Warning: Could not resolve {DB_HOST}: {e}")
            host_ip = DB_HOST

        conn = psycopg2.connect(
            host=host_ip,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASS,
            port=DB_PORT,
            sslmode='require'
        )
        cursor = conn.cursor()
        
        print("Checking latest sensitivity for equipments...")
        
        query = """
        SELECT 
            e.tag_no, 
            e.model_name,
            i.inspection_date, 
            i.gas_sensitivity
        FROM equipments e
        JOIN inspections i ON e.id = i.equipment_id
        WHERE i.inspection_date = (
            SELECT MAX(inspection_date) 
            FROM inspections i2 
            WHERE i2.equipment_id = e.id
        )
        ORDER BY e.tag_no;
        """
        
        cursor.execute(query)
        rows = cursor.fetchall()
        
        print(f"{'TAG':<10} | {'Model':<10} | {'Date':<12} | {'Sensitivity'}")
        print("-" * 50)
        for row in rows:
            tag, model, date, sens = row
            print(f"{tag:<10} | {model:<10} | {date} | {sens}")
            
        conn.close()
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    check_data()
