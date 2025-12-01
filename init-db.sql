-- =============================================================================
-- 📦 med-inventory-alert: Medical warehouse database initialization
-- =============================================================================
--
-- 💡 Used on first startup of PostgreSQL container via docker-compose.
--     Automatically creates schema and sample data.
--
-- =============================================================================

-- Package types (e.g. vial, blister, pack)
CREATE TABLE IF NOT EXISTS package_types (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE
);

-- Drugs reference
CREATE TABLE IF NOT EXISTS drugs (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    package_type_id INTEGER NOT NULL REFERENCES package_types(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Warehouses reference
CREATE TABLE IF NOT EXISTS warehouses (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    location TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Incoming stock log (deliveries)
CREATE TABLE IF NOT EXISTS stock_in (
    id SERIAL PRIMARY KEY,
    drug_id INTEGER NOT NULL REFERENCES drugs(id) ON DELETE RESTRICT,
    warehouse_id INTEGER NOT NULL REFERENCES warehouses(id) ON DELETE RESTRICT,
    amount INTEGER NOT NULL CHECK (amount > 0),
    supplier TEXT,
    invoice_number TEXT,
    expiry_date DATE,
    recorded_at TIMESTAMPTZ DEFAULT NOW()
);

-- Outgoing stock log (issuance)
CREATE TABLE IF NOT EXISTS stock_out (
    id SERIAL PRIMARY KEY,
    drug_id INTEGER NOT NULL REFERENCES drugs(id) ON DELETE RESTRICT,
    warehouse_id INTEGER NOT NULL REFERENCES warehouses(id) ON DELETE RESTRICT,
    amount INTEGER NOT NULL CHECK (amount > 0),
    recipient TEXT,
    purpose TEXT,
    recorded_at TIMESTAMPTZ DEFAULT NOW()
);

-- Daily inventory snapshots (e.g. from CSV import or manual count)
CREATE TABLE IF NOT EXISTS daily_stock_snapshot (
    drug_id INTEGER NOT NULL REFERENCES drugs(id),
    warehouse_id INTEGER NOT NULL REFERENCES warehouses(id),
    snapshot_date DATE NOT,
    quantity INTEGER NOT NULL,
    source_type TEXT NOT NULL DEFAULT 'calculated'
        CHECK (source_type IN ('calculated', 'csv', 'manual')),
    PRIMARY KEY (drug_id, warehouse_id, snapshot_date)
);

-- Current stock cache (used by monitoring/alerting workflow)
CREATE TABLE IF NOT EXISTS stock (
    drug_id INTEGER NOT NULL REFERENCES drugs(id) ON DELETE CASCADE,
    warehouse_id INTEGER NOT NULL REFERENCES warehouses(id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL DEFAULT 0 CHECK (quantity >= 0),
    daily_usage NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    threshold INTEGER NOT NULL DEFAULT 10,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (drug_id, warehouse_id)
);

-- Performance indexes
CREATE INDEX IF NOT EXISTS idx_stock_warehouse ON stock(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_stock_drug ON stock(drug_id);
CREATE INDEX IF NOT EXISTS idx_stock_in ON stock_in(drug_id, warehouse_id, recorded_at);
CREATE INDEX IF NOT EXISTS idx_stock_out ON stock_out(drug_id, warehouse_id, recorded_at);
CREATE INDEX IF NOT EXISTS idx_snapshot_date ON daily_stock_snapshot(snapshot_date);

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

-- Initial stock snapshots (simulates first inventory)
INSERT INTO daily_stock_snapshot (drug_id, warehouse_id, snapshot_date, quantity, source_type)
SELECT
    d.id,
    w.id,
    CURRENT_DATE,
    CASE
        WHEN d.name = 'Инсулин' AND w.name = 'Центральный склад' THEN 25
        WHEN d.name = 'Инсулин' AND w.name = 'Хирургическое отделение' THEN 3
        WHEN d.name = 'Аспирин' AND w.name = 'Поликлиника' THEN 80
        WHEN d.name = 'Амоксициллин' AND w.name = 'Центральный склад' THEN 30
        ELSE 0
    END,
    'initial'
FROM drugs d
CROSS JOIN warehouses w
ON CONFLICT (drug_id, warehouse_id, snapshot_date) DO NOTHING;

-- Populate initial 'stock' cache from latest snapshot
INSERT INTO stock (drug_id, warehouse_id, quantity, daily_usage, threshold)
SELECT
    ds.drug_id,
    ds.warehouse_id,
    ds.quantity,
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
FROM daily_stock_snapshot ds
JOIN drugs d ON ds.drug_id = d.id
WHERE ds.snapshot_date = CURRENT_DATE
ON CONFLICT (drug_id, warehouse_id) DO NOTHING;

-- Sample incoming/outgoing logs (optional)
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