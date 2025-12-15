-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Sites Table (Factories / Locations)
CREATE TABLE IF NOT EXISTS sites (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code TEXT NOT NULL UNIQUE, -- e.g., '2654202'
    name TEXT NOT NULL,        -- e.g., 'A株式会社 B工場'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Equipments Table (Gas Detectors)
CREATE TABLE IF NOT EXISTS equipments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    site_id UUID REFERENCES sites(id) ON DELETE CASCADE,
    tag_no TEXT NOT NULL,      -- e.g., 'XA-591'
    serial_no TEXT,            -- e.g., '123456'
    model_name TEXT,           -- e.g., 'GD-K8A'
    sensor_type TEXT,          -- e.g., '接触燃焼式'
    gas_name TEXT,             -- e.g., 'CL2'
    full_scale FLOAT,          -- e.g., 100.0
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(site_id, tag_no)    -- Ensure unique TAG per site
);

-- 3. Inspections Table (History)
CREATE TABLE IF NOT EXISTS inspections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    equipment_id UUID REFERENCES equipments(id) ON DELETE CASCADE,
    inspection_date DATE NOT NULL,
    gas_sensitivity FLOAT,     -- e.g., 85.5 (%)
    adjustment_before FLOAT,   -- Value before adjustment
    adjustment_after FLOAT,    -- Value after adjustment
    is_sensor_replaced BOOLEAN DEFAULT FALSE,
    result TEXT,               -- e.g., 'OK', 'NG'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraint to ensure sensitivity is valid percentage if present
    CONSTRAINT check_sensitivity_range CHECK (gas_sensitivity IS NULL OR (gas_sensitivity >= 0 AND gas_sensitivity <= 200))
);

-- Indexes for performance
CREATE INDEX idx_equipments_site_id ON equipments(site_id);
CREATE INDEX idx_inspections_equipment_id ON inspections(equipment_id);
CREATE INDEX idx_inspections_date ON inspections(inspection_date);
