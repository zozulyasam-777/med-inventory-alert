-- =============================================================================
-- 📦 med-inventory-alert: Medical warehouse database initialization script
-- =============================================================================
--
-- 💡 Manual usage (without Docker):
--
-- 1. Connect to PostgreSQL as superuser:
--    $ sudo -u postgres psql
--
-- 2. Create the database:
--    =# CREATE DATABASE medinventory;
--
-- 3. Connect to it:
--    =# \c medinventory
--
-- 4. Run this script:
--    =# \i /path/to/init-db.sql
--
-- =============================================================================

-- Create separate database for n8n (required if using PostgreSQL for n8n storage)
-- Note: This must be done by superuser (postgres), so we use DO + dblink or create manually.
-- Simpler: create it via shell, but since we can't, we'll rely on pre-creation.
-- Instead, we'll let n8n use SQLite for its own data (recommended for simplicity).

-- Reference table: package types
CREATE TABLE IF NOT EXISTS package_types (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE  -- e.g. "флакон", "блистер", "упаковка", "ампула"
);

-- Reference table: drugs
CREATE TABLE IF NOT EXISTS drugs (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,                -- Drug name
    package_type_id INTEGER NOT NULL REFERENCES package_types(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Reference table: warehouses
CREATE TABLE IF NOT EXISTS warehouses (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,                -- Warehouse name
    location TEXT,                            -- Location description
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Current stock levels (main monitoring table)
CREATE TABLE IF NOT EXISTS stock (
    drug_id INTEGER NOT NULL REFERENCES drugs(id) ON DELETE CASCADE,
    warehouse_id INTEGER NOT NULL REFERENCES warehouses(id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL DEFAULT 0 CHECK (quantity >= 0),
    daily_usage NUMERIC(10,2) NOT NULL DEFAULT 0.00,  -- Average daily consumption
    threshold INTEGER NOT NULL DEFAULT 10,            -- Alert threshold
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (drug_id, warehouse_id)
);

-- Incoming stock log (deliveries)
CREATE TABLE IF NOT EXISTS stock_in (
    id SERIAL PRIMARY KEY,
    drug_id INTEGER NOT NULL REFERENCES drugs(id) ON DELETE RESTRICT,
    warehouse_id INTEGER NOT NULL REFERENCES warehouses(id) ON DELETE RESTRICT,
    amount INTEGER NOT NULL CHECK (amount > 0),
    supplier TEXT,                    -- Supplier name
    invoice_number TEXT,              -- Invoice ID
    expiry_date DATE,                 -- Expiry date
    recorded_at TIMESTAMPTZ DEFAULT NOW()
);

-- Outgoing stock log (issuance)
CREATE TABLE IF NOT EXISTS stock_out (
    id SERIAL PRIMARY KEY,
    drug_id INTEGER NOT NULL REFERENCES drugs(id) ON DELETE RESTRICT,
    warehouse_id INTEGER NOT NULL REFERENCES warehouses(id) ON DELETE RESTRICT,
    amount INTEGER NOT NULL CHECK (amount > 0),
    recipient TEXT,                   -- Recipient (e.g. ward, patient)
    purpose TEXT,                     -- Purpose of issuance
    recorded_at TIMESTAMPTZ DEFAULT NOW()
);

-- Performance indexes
CREATE INDEX IF NOT EXISTS idx_stock_warehouse ON stock(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_stock_drug ON stock(drug_id);
CREATE INDEX IF NOT EXISTS idx_stock_in ON stock_in(drug_id, warehouse_id, recorded_at);
CREATE INDEX IF NOT EXISTS idx_stock_out ON stock_out(drug_id, warehouse_id, recorded_at);

-- =============================================================================
-- 🧪 Sample data
-- =============================================================================

-- Package types
INSERT INTO package_types (name)
VALUES ('флакон'), ('блистер'), ('упаковка'), ('ампула')
ON CONFLICT (name) DO NOTHING;

-- Drugs
INSERT INTO drugs (name, package_type_id)
SELECT 'Инсулин', id FROM package_types WHERE name = 'флакон'
ON CONFLICT (name) DO NOTHING;

INSERT INTO drugs (name, package_type_id)
SELECT 'Аспирин', id FROM package_types WHERE name = 'упаковка'
ON CONFLICT (name) DO NOTHING;

INSERT INTO drugs (name, package_type_id)
SELECT 'Амоксициллин', id FROM package_types WHERE name = 'блистер'
ON CONFLICT (name) DO NOTHING;

INSERT INTO drugs (name, package_type_id)
SELECT 'Парацетамол', id FROM package_types WHERE name = 'упаковка'
ON CONFLICT (name) DO NOTHING;

-- Warehouses
INSERT INTO warehouses (name, location)
VALUES
    ('Центральный склад', 'Главное здание, подвал'),
    ('Хирургическое отделение', 'Корпус Б, эт. 2'),
    ('Поликлиника', 'Корпус А, эт. 1')
ON CONFLICT (name) DO NOTHING;

-- Initial stock levels
INSERT INTO stock (drug_id, warehouse_id, quantity, daily_usage, threshold)
SELECT
    d.id,
    w.id,
    CASE
        WHEN d.name = 'Инсулин' AND w.name = 'Центральный склад' THEN 20
        WHEN d.name = 'Инсулин' AND w.name = 'Хирургическое отделение' THEN 5
        WHEN d.name = 'Аспирин' AND w.name = 'Поликлиника' THEN 100
        WHEN d.name = 'Амоксициллин' AND w.name = 'Центральный склад' THEN 30
        ELSE 0
    END,
    CASE
        WHEN d.name = 'Инсулин' THEN 2.5
        WHEN d.name = 'Аспирин' THEN 8.0
        WHEN d.name = 'Амоксициллин' THEN 4.0
        WHEN d.name = 'Парацетамол' THEN 6.0
        ELSE 1.0
    END,
    CASE
        WHEN d.name = 'Инсулин' THEN 10
        WHEN d.name = 'Аспирин' THEN 30
        ELSE 15
    END
FROM drugs d
CROSS JOIN warehouses w
ON CONFLICT (drug_id, warehouse_id) DO NOTHING;

-- Sample incoming delivery
INSERT INTO stock_in (drug_id, warehouse_id, amount, supplier, invoice_number, expiry_date)
SELECT
    (SELECT id FROM drugs WHERE name = 'Инсулин'),
    (SELECT id FROM warehouses WHERE name = 'Центральный склад'),
    25,
    'ФармПоставка ООО',
    'INV-2025-1001',
    '2027-12-31'
WHERE NOT EXISTS (
    SELECT 1 FROM stock_in WHERE invoice_number = 'INV-2025-1001'
);

-- Sample outgoing issuance
INSERT INTO stock_out (drug_id, warehouse_id, amount, recipient, purpose)
SELECT
    (SELECT id FROM drugs WHERE name = 'Инсулин'),
    (SELECT id FROM warehouses WHERE name = 'Хирургическое отделение'),
    1,
    'Палата 305',
    'Лечение пациента №12345'
WHERE NOT EXISTS (
    SELECT 1 FROM stock_out WHERE recipient = 'Палата 305' AND purpose LIKE 'Лечение пациента%'
);