-- Portfolio 4: JSONB Data Models
ALTER TABLE customers ADD COLUMN profile_metadata JSONB DEFAULT '{}'::jsonb;

UPDATE customers 
SET profile_metadata = '{"notification_preferences": {"sms": true}, "trusted_devices": ["dev_hash_98213"]}'::jsonb
WHERE customer_id = (SELECT customer_id FROM customers LIMIT 1);

CREATE INDEX idx_customers_profile_gin ON customers USING GIN (profile_metadata jsonb_path_ops);

SELECT customer_id, first_name, last_name
FROM customers
WHERE profile_metadata @> '{"notification_preferences": {"sms": true}}';
