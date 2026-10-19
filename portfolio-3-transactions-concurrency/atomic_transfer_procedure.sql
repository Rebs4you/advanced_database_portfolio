-- Portfolio 3: Atomic Stored Procedure
CREATE OR REPLACE FUNCTION process_atomic_transfer(
    p_source_account_id UUID,
    p_destination_account_id UUID,
    p_amount NUMERIC(18, 4),
    p_currency_code CHAR(3),
    p_idempotency_key VARCHAR(64)
) RETURNS UUID AS $$
DECLARE
    v_transfer_id UUID;
    v_source_balance NUMERIC(18, 4);
    v_dest_balance NUMERIC(18, 4);
    v_first_lock UUID;
    v_second_lock UUID;
BEGIN
    IF EXISTS (SELECT 1 FROM transfers WHERE idempotency_key = p_idempotency_key) THEN
        SELECT transfer_id INTO v_transfer_id FROM transfers WHERE idempotency_key = p_idempotency_key;
        RETURN v_transfer_id;
    END IF;

    IF p_source_account_id < p_destination_account_id THEN
        v_first_lock := p_source_account_id;
        v_second_lock := p_destination_account_id;
    ELSE
        v_first_lock := p_destination_account_id;
        v_second_lock := p_source_account_id;
    END IF;

    PERFORM 1 FROM accounts WHERE account_id = v_first_lock FOR UPDATE;
    PERFORM 1 FROM accounts WHERE account_id = v_second_lock FOR UPDATE;

    SELECT available_balance INTO v_source_balance 
    FROM accounts WHERE account_id = p_source_account_id AND status = 'ACTIVE';

    IF v_source_balance IS NULL OR v_source_balance < p_amount THEN
        RAISE EXCEPTION 'Insufficient funds or inactive account.';
    END IF;

    INSERT INTO transfers (source_account_id, destination_account_id, amount, currency_code, status, idempotency_key)
    VALUES (p_source_account_id, p_destination_account_id, p_amount, p_currency_code, 'INITIATED', p_idempotency_key)
    RETURNING transfer_id INTO v_transfer_id;

    UPDATE accounts SET available_balance = available_balance - p_amount, ledger_balance = ledger_balance - p_amount
    WHERE account_id = p_source_account_id RETURNING available_balance INTO v_source_balance;

    UPDATE accounts SET available_balance = available_balance + p_amount, ledger_balance = ledger_balance + p_amount
    WHERE account_id = p_destination_account_id RETURNING available_balance INTO v_dest_balance;

    INSERT INTO transaction_logs (account_id, related_transfer_id, entry_type, amount, balance_after)
    VALUES (p_source_account_id, v_transfer_id, 'DEBIT', p_amount, v_source_balance);

    INSERT INTO transaction_logs (account_id, related_transfer_id, entry_type, amount, balance_after)
    VALUES (p_destination_account_id, v_transfer_id, 'CREDIT', p_amount, v_dest_balance);

    UPDATE transfers SET status = 'COMPLETED', completed_at = CURRENT_TIMESTAMP WHERE transfer_id = v_transfer_id;
    RETURN v_transfer_id;
END;
$$ LANGUAGE plpgsql;
