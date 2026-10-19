-- Portfolio 5: Range Partitioning & Audit Query
CREATE TABLE transaction_logs_partitioned (
    log_id BIGSERIAL,
    account_id UUID NOT NULL,
    related_transfer_id UUID,
    entry_type entry_type_enum NOT NULL,
    amount NUMERIC(18, 4) NOT NULL,
    balance_after NUMERIC(18, 4) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (log_id, created_at)
) PARTITION BY RANGE (created_at);

CREATE TABLE transaction_logs_2026_m09 PARTITION OF transaction_logs_partitioned
    FOR VALUES FROM ('2026-09-01 00:00:00+00') TO ('2026-10-01 00:00:00+00');

CREATE TABLE transaction_logs_2026_m10 PARTITION OF transaction_logs_partitioned
    FOR VALUES FROM ('2026-10-01 00:00:00+00') TO ('2026-11-01 00:00:00+00');

WITH calculated_ledger AS (
    SELECT account_id, SUM(CASE WHEN entry_type = 'CREDIT' THEN amount ELSE -amount END) AS calculated_net_balance
    FROM transaction_logs_partitioned GROUP BY account_id
)
SELECT a.account_id, a.ledger_balance, COALESCE(cl.calculated_net_balance, 0.0000) AS audited_balance,
       CASE WHEN a.ledger_balance = COALESCE(cl.calculated_net_balance, 0.0000) THEN 'PASSED' ELSE 'FAILED' END AS audit_status
FROM accounts a LEFT JOIN calculated_ledger cl ON a.account_id = cl.account_id;
