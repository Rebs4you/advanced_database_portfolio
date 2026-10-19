-- Portfolio 1: Core Relational Schema
CREATE TYPE kyc_status_enum AS ENUM ('PENDING', 'VERIFIED', 'REJECTED');
CREATE TYPE account_status_enum AS ENUM ('ACTIVE', 'FROZEN', 'CLOSED');
CREATE TYPE transfer_status_enum AS ENUM ('INITIATED', 'COMPLETED', 'FAILED', 'REVERSED');
CREATE TYPE entry_type_enum AS ENUM ('DEBIT', 'CREDIT');

CREATE TABLE customers (
    customer_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tax_id VARCHAR(32) NOT NULL UNIQUE,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    kyc_status kyc_status_enum NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE accounts (
    account_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(customer_id) ON DELETE RESTRICT,
    account_number VARCHAR(20) NOT NULL UNIQUE,
    currency_code CHAR(3) NOT NULL DEFAULT 'USD',
    available_balance NUMERIC(18, 4) NOT NULL DEFAULT 0.0000,
    ledger_balance NUMERIC(18, 4) NOT NULL DEFAULT 0.0000,
    status account_status_enum NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_positive_available_balance CHECK (available_balance >= 0.0000)
);

CREATE TABLE transfers (
    transfer_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_account_id UUID NOT NULL REFERENCES accounts(account_id) ON DELETE RESTRICT,
    destination_account_id UUID NOT NULL REFERENCES accounts(account_id) ON DELETE RESTRICT,
    amount NUMERIC(18, 4) NOT NULL,
    currency_code CHAR(3) NOT NULL,
    status transfer_status_enum NOT NULL DEFAULT 'INITIATED',
    idempotency_key VARCHAR(64) NOT NULL UNIQUE,
    initiated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMPTZ,
    CONSTRAINT chk_positive_transfer_amount CHECK (amount > 0.0000),
    CONSTRAINT chk_different_accounts CHECK (source_account_id <> destination_account_id)
);

CREATE TABLE transaction_logs (
    log_id BIGSERIAL PRIMARY KEY,
    account_id UUID NOT NULL REFERENCES accounts(account_id) ON DELETE RESTRICT,
    related_transfer_id UUID REFERENCES transfers(transfer_id) ON DELETE RESTRICT,
    entry_type entry_type_enum NOT NULL,
    amount NUMERIC(18, 4) NOT NULL,
    balance_after NUMERIC(18, 4) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_log_amount_positive CHECK (amount > 0.0000)
);
