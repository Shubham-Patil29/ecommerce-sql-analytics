-- Small deterministic seed dataset for testing the portfolio queries.
-- Run after schema/create_tables.sql.

BEGIN;

INSERT INTO customers (customer_id, customer_unique_id, customer_city, customer_state)
VALUES
    ('c001', 'u001', 'sao paulo', 'SP'),
    ('c002', 'u002', 'rio de janeiro', 'RJ'),
    ('c003', 'u003', 'curitiba', 'PR'),
    ('c004', 'u004', 'salvador', 'BA'),
    ('c005', 'u005', 'belo horizonte', 'MG'),
    ('c006', 'u006', 'recife', 'PE'),
    ('c007', 'u007', 'fortaleza', 'CE'),
    ('c008', 'u008', 'campinas', 'SP')
ON CONFLICT (customer_id) DO NOTHING;

INSERT INTO products (product_id, product_category_name)
VALUES
    ('p001', 'electronics'),
    ('p002', 'bed_bath_table'),
    ('p003', 'sports_leisure'),
    ('p004', 'health_beauty'),
    ('p005', 'toys')
ON CONFLICT (product_id) DO NOTHING;

INSERT INTO orders (order_id, customer_id, order_status, order_purchase_timestamp)
VALUES
    ('o001', 'c001', 'delivered', '2024-01-10 09:00:00'),
    ('o002', 'c001', 'delivered', '2024-02-12 10:00:00'),
    ('o003', 'c001', 'delivered', '2024-04-20 11:00:00'),
    ('o004', 'c002', 'delivered', '2024-01-15 12:00:00'),
    ('o005', 'c002', 'delivered', '2024-03-18 13:00:00'),
    ('o006', 'c003', 'delivered', '2024-02-05 14:00:00'),
    ('o007', 'c003', 'delivered', '2024-02-25 15:00:00'),
    ('o008', 'c003', 'delivered', '2024-05-02 16:00:00'),
    ('o009', 'c004', 'delivered', '2024-03-11 09:30:00'),
    ('o010', 'c005', 'delivered', '2024-03-19 10:30:00'),
    ('o011', 'c005', 'delivered', '2024-04-22 11:30:00'),
    ('o012', 'c006', 'delivered', '2024-04-03 12:30:00'),
    ('o013', 'c007', 'delivered', '2024-04-10 13:30:00'),
    ('o014', 'c008', 'delivered', '2024-05-09 14:30:00'),
    ('o015', 'c008', 'canceled', '2024-05-20 15:30:00')
ON CONFLICT (order_id) DO NOTHING;

INSERT INTO order_items (order_id, order_item_id, product_id, price, freight_value)
VALUES
    ('o001', 1, 'p001', 100.00, 10.00),
    ('o002', 1, 'p002', 80.00, 8.00),
    ('o003', 1, 'p003', 150.00, 15.00),
    ('o004', 1, 'p004', 50.00, 7.00),
    ('o005', 1, 'p001', 120.00, 12.00),
    ('o006', 1, 'p005', 40.00, 6.00),
    ('o007', 1, 'p003', 90.00, 9.00),
    ('o008', 1, 'p001', 200.00, 18.00),
    ('o009', 1, 'p002', 75.00, 8.00),
    ('o010', 1, 'p004', 60.00, 7.00),
    ('o011', 1, 'p004', 110.00, 10.00),
    ('o012', 1, 'p005', 45.00, 6.00),
    ('o013', 1, 'p003', 70.00, 8.00),
    ('o014', 1, 'p001', 130.00, 12.00),
    ('o015', 1, 'p002', 90.00, 9.00)
ON CONFLICT (order_id, order_item_id) DO NOTHING;

INSERT INTO payments (order_id, payment_sequential, payment_type, payment_installments, payment_value)
SELECT order_id, 1, 'credit_card', 1, price + freight_value
FROM order_items
ON CONFLICT (order_id, payment_sequential) DO NOTHING;

INSERT INTO reviews (review_id, order_id, review_score)
SELECT 'r' || order_id, order_id, 5
FROM orders
WHERE order_status = 'delivered'
ON CONFLICT (review_id) DO NOTHING;

COMMIT;

-- Sanity checks
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'payments', COUNT(*) FROM payments
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'reviews', COUNT(*) FROM reviews
ORDER BY table_name;
