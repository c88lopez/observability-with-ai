-- PostgreSQL Initialization Script for Monitoring Demo
-- This script creates sample tables and data for monitoring demonstration

-- Create a sample application schema
CREATE SCHEMA IF NOT EXISTS app_monitoring;

-- Create users table
CREATE TABLE app_monitoring.users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- Create orders table
CREATE TABLE app_monitoring.orders (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES app_monitoring.users(id),
    order_total DECIMAL(10,2) NOT NULL,
    order_status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create products table
CREATE TABLE app_monitoring.products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    stock_quantity INTEGER DEFAULT 0,
    category VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample users
INSERT INTO app_monitoring.users (username, email, last_login, is_active) VALUES
('john_doe', 'john@example.com', CURRENT_TIMESTAMP - INTERVAL '2 hours', TRUE),
('jane_smith', 'jane@example.com', CURRENT_TIMESTAMP - INTERVAL '1 day', TRUE),
('bob_wilson', 'bob@example.com', CURRENT_TIMESTAMP - INTERVAL '3 days', TRUE),
('alice_brown', 'alice@example.com', CURRENT_TIMESTAMP - INTERVAL '1 hour', TRUE),
('charlie_davis', 'charlie@example.com', CURRENT_TIMESTAMP - INTERVAL '5 days', FALSE);

-- Insert sample products
INSERT INTO app_monitoring.products (name, price, stock_quantity, category) VALUES
('Laptop Computer', 999.99, 50, 'Electronics'),
('Coffee Mug', 12.99, 200, 'Kitchen'),
('Running Shoes', 79.99, 75, 'Sports'),
('Office Chair', 249.99, 30, 'Furniture'),
('Smartphone', 699.99, 100, 'Electronics'),
('Desk Lamp', 39.99, 150, 'Furniture'),
('Bluetooth Headphones', 129.99, 80, 'Electronics'),
('Water Bottle', 19.99, 300, 'Sports');

-- Insert sample orders
INSERT INTO app_monitoring.orders (user_id, order_total, order_status) VALUES
(1, 999.99, 'completed'),
(2, 32.98, 'completed'),
(3, 79.99, 'pending'),
(1, 249.99, 'shipped'),
(4, 699.99, 'completed'),
(2, 39.99, 'completed'),
(3, 129.99, 'processing'),
(4, 19.99, 'completed'),
(1, 12.99, 'completed'),
(2, 79.99, 'shipped');

-- Create indexes for better query performance
CREATE INDEX idx_users_active ON app_monitoring.users(is_active);
CREATE INDEX idx_users_created_at ON app_monitoring.users(created_at);
CREATE INDEX idx_orders_status ON app_monitoring.orders(order_status);
CREATE INDEX idx_orders_created_at ON app_monitoring.orders(created_at);
CREATE INDEX idx_products_category ON app_monitoring.products(category);

-- Create a view for order analytics
CREATE VIEW app_monitoring.order_summary AS
SELECT 
    DATE(created_at) as order_date,
    order_status,
    COUNT(*) as order_count,
    SUM(order_total) as total_revenue,
    AVG(order_total) as avg_order_value
FROM app_monitoring.orders
GROUP BY DATE(created_at), order_status
ORDER BY order_date DESC;

-- Create a function to simulate activity (for monitoring purposes)
CREATE OR REPLACE FUNCTION app_monitoring.simulate_activity()
RETURNS void AS $$
BEGIN
    -- Update some last_login timestamps
    UPDATE app_monitoring.users 
    SET last_login = CURRENT_TIMESTAMP 
    WHERE id = (SELECT id FROM app_monitoring.users ORDER BY RANDOM() LIMIT 1);
    
    -- Add a random order
    INSERT INTO app_monitoring.orders (user_id, order_total, order_status)
    SELECT 
        (SELECT id FROM app_monitoring.users WHERE is_active = TRUE ORDER BY RANDOM() LIMIT 1),
        (SELECT price FROM app_monitoring.products ORDER BY RANDOM() LIMIT 1),
        CASE 
            WHEN RANDOM() < 0.7 THEN 'completed'
            WHEN RANDOM() < 0.85 THEN 'pending'
            WHEN RANDOM() < 0.95 THEN 'processing'
            ELSE 'shipped'
        END;
END;
$$ LANGUAGE plpgsql;

-- Create monitoring-specific database objects
CREATE SCHEMA IF NOT EXISTS monitoring;

-- Create a table to track database statistics
CREATE TABLE monitoring.db_stats (
    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total_connections INTEGER,
    active_connections INTEGER,
    database_size_bytes BIGINT,
    tables_count INTEGER
);

-- Grant permissions for monitoring
CREATE USER IF NOT EXISTS monitoring_user WITH PASSWORD 'monitoring_pass';
GRANT CONNECT ON DATABASE monitoring_demo TO monitoring_user;
GRANT USAGE ON SCHEMA app_monitoring TO monitoring_user;
GRANT SELECT ON ALL TABLES IN SCHEMA app_monitoring TO monitoring_user;
GRANT USAGE ON SCHEMA monitoring TO monitoring_user;
GRANT SELECT ON ALL TABLES IN SCHEMA monitoring TO monitoring_user;

-- Enable statistics collection
ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_statements';
ALTER SYSTEM SET track_activities = on;
ALTER SYSTEM SET track_counts = on;
ALTER SYSTEM SET track_io_timing = on;

-- Display initialization summary
DO $$
BEGIN
    RAISE NOTICE 'PostgreSQL monitoring database initialized successfully!';
    RAISE NOTICE 'Created schema: app_monitoring';
    RAISE NOTICE 'Created tables: users (%), orders (%), products (%)', 
        (SELECT COUNT(*) FROM app_monitoring.users),
        (SELECT COUNT(*) FROM app_monitoring.orders),
        (SELECT COUNT(*) FROM app_monitoring.products);
    RAISE NOTICE 'Access URLs:';
    RAISE NOTICE '  - PostgreSQL: localhost:5432 (postgres/postgres)';
    RAISE NOTICE '  - Metrics: localhost:9187/metrics';
END $$;
