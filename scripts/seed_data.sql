-- Generated Seed Data
INSERT INTO sites (code, name) VALUES ('2654202', 'A株式会社 B工場') ON CONFLICT (code) DO NOTHING;
-- NOTE: Equipments and Inspections require UUID lookups. Please configure DB connection in import_data.py and run it directly.
