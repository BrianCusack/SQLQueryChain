-- Bank Database Schema
-- A normalized PostgreSQL database for banking operations

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Drop tables if they exist (for clean setup)
DROP TABLE IF EXISTS transaction_details CASCADE;
DROP TABLE IF EXISTS transactions CASCADE;
DROP TABLE IF EXISTS account_fees CASCADE;
DROP TABLE IF EXISTS fee_types CASCADE;
DROP TABLE IF EXISTS accounts CASCADE;
DROP TABLE IF EXISTS account_types CASCADE;
DROP TABLE IF EXISTS user_roles CASCADE;
DROP TABLE IF EXISTS roles CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS branches CASCADE;

-- Create Branches table
CREATE TABLE branches (
    branch_id SERIAL PRIMARY KEY,
    branch_name VARCHAR(100) NOT NULL,
    branch_address TEXT NOT NULL,
    branch_phone VARCHAR(20) NOT NULL,
    branch_email VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create Users table
CREATE TABLE users (
    user_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL, -- Store hashed passwords only
    phone_number VARCHAR(20),
    date_of_birth DATE NOT NULL,
    address TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP WITH TIME ZONE
);

-- Create Roles table
CREATE TABLE roles (
    role_id SERIAL PRIMARY KEY,
    role_name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create User_Roles join table (many-to-many)
CREATE TABLE user_roles (
    user_role_id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    role_id INTEGER NOT NULL REFERENCES roles(role_id) ON DELETE CASCADE,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    assigned_by UUID REFERENCES users(user_id),
    is_active BOOLEAN DEFAULT TRUE,
    UNIQUE(user_id, role_id) -- Each user can have a specific role only once
);

-- Create Account Types table
CREATE TABLE account_types (
    account_type_id SERIAL PRIMARY KEY,
    type_name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    minimum_balance DECIMAL(15, 2) DEFAULT 0.00,
    interest_rate DECIMAL(5, 2) DEFAULT 0.00,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create Accounts table
CREATE TABLE accounts (
    account_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    account_number VARCHAR(20) UNIQUE NOT NULL,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    account_type_id INTEGER NOT NULL REFERENCES account_types(account_type_id),
    branch_id INTEGER REFERENCES branches(branch_id),
    balance DECIMAL(15, 2) DEFAULT 0.00 NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD' NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    opened_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    closed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CHECK (balance >= 0) -- Prevents negative balance unless overridden
);

-- Create Fee Types table
CREATE TABLE fee_types (
    fee_type_id SERIAL PRIMARY KEY,
    fee_name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    default_amount DECIMAL(10, 2) NOT NULL,
    is_percentage BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create Account-specific Fees table
CREATE TABLE account_fees (
    account_fee_id SERIAL PRIMARY KEY,
    account_type_id INTEGER NOT NULL REFERENCES account_types(account_type_id) ON DELETE CASCADE,
    fee_type_id INTEGER NOT NULL REFERENCES fee_types(fee_type_id) ON DELETE CASCADE,
    fee_amount DECIMAL(10, 2) NOT NULL, -- Can override default_amount from fee_types
    is_percentage BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    effective_from DATE NOT NULL,
    effective_to DATE, -- NULL means indefinite
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(account_type_id, fee_type_id, effective_from) -- Only one fee of a specific type per account type at a time
);

-- Create Transactions table
CREATE TABLE transactions (
    transaction_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transaction_code VARCHAR(50) UNIQUE NOT NULL,
    account_id UUID NOT NULL REFERENCES accounts(account_id) ON DELETE CASCADE,
    transaction_type VARCHAR(50) NOT NULL, -- 'deposit', 'withdrawal', 'transfer', 'fee', 'interest', etc.
    amount DECIMAL(15, 2) NOT NULL,
    running_balance DECIMAL(15, 2) NOT NULL,
    description TEXT,
    status VARCHAR(20) DEFAULT 'pending' NOT NULL, -- 'pending', 'completed', 'failed', 'cancelled'
    transaction_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create Transaction Details table for additional transaction information
CREATE TABLE transaction_details (
    detail_id SERIAL PRIMARY KEY,
    transaction_id UUID NOT NULL REFERENCES transactions(transaction_id) ON DELETE CASCADE,
    reference_id UUID, -- For transfers, this could be another transaction_id
    fee_id INTEGER REFERENCES account_fees(account_fee_id),
    metadata JSONB, -- Flexible field for additional transaction data
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for performance
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_user_roles_user_id ON user_roles(user_id);
CREATE INDEX idx_user_roles_role_id ON user_roles(role_id);
CREATE INDEX idx_accounts_user_id ON accounts(user_id);
CREATE INDEX idx_accounts_account_type_id ON accounts(account_type_id);
CREATE INDEX idx_account_fees_account_type_id ON account_fees(account_type_id);
CREATE INDEX idx_account_fees_fee_type_id ON account_fees(fee_type_id);
CREATE INDEX idx_transactions_account_id ON transactions(account_id);
CREATE INDEX idx_transactions_transaction_date ON transactions(transaction_date);
CREATE INDEX idx_transaction_details_transaction_id ON transaction_details(transaction_id);

-- Create a function to update 'updated_at' timestamp
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers to automatically update 'updated_at'
CREATE TRIGGER update_branches_modtime
BEFORE UPDATE ON branches
FOR EACH ROW
EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER update_users_modtime
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER update_roles_modtime
BEFORE UPDATE ON roles
FOR EACH ROW
EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER update_account_types_modtime
BEFORE UPDATE ON account_types
FOR EACH ROW
EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER update_accounts_modtime
BEFORE UPDATE ON accounts
FOR EACH ROW
EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER update_fee_types_modtime
BEFORE UPDATE ON fee_types
FOR EACH ROW
EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER update_account_fees_modtime
BEFORE UPDATE ON account_fees
FOR EACH ROW
EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER update_transactions_modtime
BEFORE UPDATE ON transactions
FOR EACH ROW
EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER update_transaction_details_modtime
BEFORE UPDATE ON transaction_details
FOR EACH ROW
EXECUTE FUNCTION update_modified_column();

-- Populate default roles
INSERT INTO roles (role_name, description) VALUES
('customer', 'Regular bank customer'),
('teller', 'Bank teller who can process basic transactions'),
('manager', 'Branch manager with elevated permissions'),
('admin', 'System administrator with full access');

-- Populate default account types
INSERT INTO account_types (type_name, description, minimum_balance, interest_rate) VALUES
('checking', 'Standard checking account', 0.00, 0.00),
('savings', 'Interest-bearing savings account', 100.00, 0.50),
('money_market', 'High-yield money market account', 1000.00, 1.25),
('certificate', 'Certificate of deposit', 500.00, 2.00),
('credit', 'Credit account or line of credit', 0.00, 0.00);

-- Populate default fee types
INSERT INTO fee_types (fee_name, description, default_amount, is_percentage) VALUES
('monthly_maintenance', 'Monthly account maintenance fee', 5.00, FALSE),
('minimum_balance', 'Fee for falling below minimum balance', 10.00, FALSE),
('overdraft', 'Overdraft fee', 35.00, FALSE),
('wire_transfer', 'Wire transfer fee', 25.00, FALSE),
('atm_withdrawal', 'ATM withdrawal fee', 2.50, FALSE),
('foreign_transaction', 'Foreign transaction fee', 3.00, TRUE),
('early_withdrawal', 'Early withdrawal penalty (CDs)', 10.00, TRUE),
('card_replacement', 'Card replacement fee', 15.00, FALSE);

-- Set up default account fees
INSERT INTO account_fees (account_type_id, fee_type_id, fee_amount, is_percentage, effective_from) VALUES
(1, 1, 5.00, FALSE, '2023-01-01'), -- Checking: Monthly maintenance
(1, 2, 10.00, FALSE, '2023-01-01'), -- Checking: Minimum balance
(1, 3, 35.00, FALSE, '2023-01-01'), -- Checking: Overdraft
(2, 1, 4.00, FALSE, '2023-01-01'), -- Savings: Monthly maintenance
(2, 2, 15.00, FALSE, '2023-01-01'), -- Savings: Minimum balance
(3, 1, 10.00, FALSE, '2023-01-01'), -- Money Market: Monthly maintenance
(3, 2, 25.00, FALSE, '2023-01-01'), -- Money Market: Minimum balance
(4, 7, 20.00, TRUE, '2023-01-01'); -- Certificate: Early withdrawal penalty

-- Create a sample branch
INSERT INTO branches (branch_name, branch_address, branch_phone, branch_email) VALUES
('Main Branch', '123 Finance St, New York, NY 10001', '212-555-1234', 'main@bankexample.com');

-- Create sample users (passwords should be properly hashed in production)
INSERT INTO users (first_name, last_name, email, password_hash, phone_number, date_of_birth, address) VALUES
('John', 'Doe', 'john.doe@example.com', 'hashed_password_1', '555-123-4567', '1980-06-15', '42 Main St, Springfield, IL'),
('Jane', 'Smith', 'jane.smith@example.com', 'hashed_password_2', '555-987-6543', '1975-09-22', '123 Oak Ave, Chicago, IL'),
('Admin', 'User', 'admin@bankexample.com', 'hashed_password_admin', '555-111-2222', '1985-03-10', '456 Admin Rd, New York, NY');

-- Assign roles to users
INSERT INTO user_roles (user_id, role_id) VALUES
((SELECT user_id FROM users WHERE email = 'john.doe@example.com'), (SELECT role_id FROM roles WHERE role_name = 'customer')),
((SELECT user_id FROM users WHERE email = 'jane.smith@example.com'), (SELECT role_id FROM roles WHERE role_name = 'customer')),
((SELECT user_id FROM users WHERE email = 'jane.smith@example.com'), (SELECT role_id FROM roles WHERE role_name = 'teller')), -- Jane is both customer and teller
((SELECT user_id FROM users WHERE email = 'admin@bankexample.com'), (SELECT role_id FROM roles WHERE role_name = 'admin'));

-- Create sample accounts
INSERT INTO accounts (account_number, user_id, account_type_id, branch_id, balance, currency) VALUES
('CH001234567', (SELECT user_id FROM users WHERE email = 'john.doe@example.com'), 1, 1, 1500.50, 'USD'),
('SV001234568', (SELECT user_id FROM users WHERE email = 'john.doe@example.com'), 2, 1, 5000.75, 'USD'),
('CH001234569', (SELECT user_id FROM users WHERE email = 'jane.smith@example.com'), 1, 1, 2500.00, 'USD'),
('MM001234570', (SELECT user_id FROM users WHERE email = 'jane.smith@example.com'), 3, 1, 25000.00, 'USD');

-- Create sample transactions
INSERT INTO transactions (transaction_code, account_id, transaction_type, amount, running_balance, description, status) VALUES
('TRX00001', (SELECT account_id FROM accounts WHERE account_number = 'CH001234567'), 'deposit', 1000.00, 1000.00, 'Initial deposit', 'completed'),
('TRX00002', (SELECT account_id FROM accounts WHERE account_number = 'CH001234567'), 'withdrawal', -500.00, 500.00, 'ATM withdrawal', 'completed'),
('TRX00003', (SELECT account_id FROM accounts WHERE account_number = 'CH001234567'), 'deposit', 1000.50, 1500.50, 'Payroll deposit', 'completed'),
('TRX00004', (SELECT account_id FROM accounts WHERE account_number = 'SV001234568'), 'deposit', 5000.75, 5000.75, 'Initial deposit', 'completed'),
('TRX00005', (SELECT account_id FROM accounts WHERE account_number = 'CH001234569'), 'deposit', 2500.00, 2500.00, 'Initial deposit', 'completed'),
('TRX00006', (SELECT account_id FROM accounts WHERE account_number = 'MM001234570'), 'deposit', 25000.00, 25000.00, 'Initial deposit', 'completed');

-- Add transaction details for a fee
INSERT INTO transaction_details (transaction_id, fee_id, metadata) VALUES
((SELECT transaction_id FROM transactions WHERE transaction_code = 'TRX00002'), 
 (SELECT account_fee_id FROM account_fees WHERE account_type_id = 1 AND fee_type_id = 5), 
 '{"location": "ATM #1234", "notes": "External ATM fee"}'::jsonb);

-- Create a view for user account summary
CREATE OR REPLACE VIEW user_account_summary AS
SELECT 
    u.user_id,
    u.first_name || ' ' || u.last_name AS full_name,
    u.email,
    a.account_id,
    a.account_number,
    at.type_name AS account_type,
    a.balance,
    a.currency,
    a.is_active,
    a.opened_at,
    b.branch_name
FROM 
    users u
JOIN 
    accounts a ON u.user_id = a.user_id
JOIN 
    account_types at ON a.account_type_id = at.account_type_id
JOIN 
    branches b ON a.branch_id = b.branch_id
WHERE 
    a.is_active = TRUE;

-- Create a view for account transaction history
CREATE OR REPLACE VIEW account_transaction_history AS
SELECT 
    a.account_id,
    a.account_number,
    at.type_name AS account_type,
    u.user_id,
    u.first_name || ' ' || u.last_name AS full_name,
    t.transaction_id,
    t.transaction_code,
    t.transaction_type,
    t.amount,
    t.running_balance,
    t.description,
    t.status,
    t.transaction_date,
    ft.fee_name,
    af.fee_amount
FROM 
    accounts a
JOIN 
    users u ON a.user_id = u.user_id
JOIN 
    account_types at ON a.account_type_id = at.account_type_id
JOIN 
    transactions t ON a.account_id = t.account_id
LEFT JOIN 
    transaction_details td ON t.transaction_id = td.transaction_id
LEFT JOIN 
    account_fees af ON td.fee_id = af.account_fee_id
LEFT JOIN 
    fee_types ft ON af.fee_type_id = ft.fee_type_id
ORDER BY 
    t.transaction_date DESC;

-- Create a sample stored procedure for applying monthly maintenance fees
CREATE OR REPLACE PROCEDURE apply_monthly_maintenance_fees()
LANGUAGE plpgsql
AS $$
DECLARE
    account_rec RECORD;
    fee_rec RECORD;
    new_transaction_id UUID;
    transaction_code VARCHAR(50);
BEGIN
    -- Loop through all active accounts
    FOR account_rec IN 
        SELECT a.account_id, a.account_number, a.balance, a.account_type_id
        FROM accounts a
        WHERE a.is_active = TRUE
    LOOP
        -- Find the monthly maintenance fee for this account type
        SELECT af.* INTO fee_rec
        FROM account_fees af
        WHERE af.account_type_id = account_rec.account_type_id
          AND af.fee_type_id = (SELECT fee_type_id FROM fee_types WHERE fee_name = 'monthly_maintenance')
          AND af.is_active = TRUE
          AND CURRENT_DATE BETWEEN af.effective_from AND COALESCE(af.effective_to, CURRENT_DATE + 1);
          
        IF FOUND THEN
            -- Generate transaction code
            SELECT 'FEE' || TO_CHAR(NOW(), 'YYYYMMDD') || LPAD(CAST(NEXTVAL('transaction_code_seq') AS VARCHAR), 6, '0')
            INTO transaction_code;
            
            -- Create the fee transaction
            INSERT INTO transactions (
                transaction_code, 
                account_id, 
                transaction_type, 
                amount, 
                running_balance, 
                description, 
                status
            ) VALUES (
                transaction_code,
                account_rec.account_id,
                'fee',
                -fee_rec.fee_amount,
                account_rec.balance - fee_rec.fee_amount,
                'Monthly Maintenance Fee',
                'completed'
            ) RETURNING transaction_id INTO new_transaction_id;
            
            -- Update the account balance
            UPDATE accounts 
            SET balance = balance - fee_rec.fee_amount
            WHERE account_id = account_rec.account_id;
            
            -- Add transaction details
            INSERT INTO transaction_details (
                transaction_id, 
                fee_id, 
                metadata
            ) VALUES (
                new_transaction_id,
                fee_rec.account_fee_id,
                jsonb_build_object(
                    'fee_type', 'Monthly Maintenance',
                    'applied_date', CURRENT_DATE,
                    'notes', 'Automatically applied monthly fee'
                )
            );
        END IF;
    END LOOP;
    
    COMMIT;
END;
$$;

-- Create a sequence for transaction codes
CREATE SEQUENCE IF NOT EXISTS transaction_code_seq START 1;

-- Create a function to transfer funds between accounts
CREATE OR REPLACE FUNCTION transfer_funds(
    p_from_account VARCHAR(20),
    p_to_account VARCHAR(20),
    p_amount DECIMAL(15, 2),
    p_description TEXT DEFAULT 'Fund transfer'
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_from_account_id UUID;
    v_to_account_id UUID;
    v_from_balance DECIMAL(15, 2);
    v_to_balance DECIMAL(15, 2);
    v_transaction_code_from VARCHAR(50);
    v_transaction_code_to VARCHAR(50);
    v_from_transaction_id UUID;
    v_to_transaction_id UUID;
BEGIN
    -- Get account IDs
    SELECT account_id, balance INTO v_from_account_id, v_from_balance
    FROM accounts WHERE account_number = p_from_account AND is_active = TRUE;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Source account not found or inactive: %', p_from_account;
    END IF;
    
    SELECT account_id, balance INTO v_to_account_id, v_to_balance
    FROM accounts WHERE account_number = p_to_account AND is_active = TRUE;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Destination account not found or inactive: %', p_to_account;
    END IF;
    
    -- Verify sufficient funds
    IF v_from_balance < p_amount THEN
        RAISE EXCEPTION 'Insufficient funds in account %', p_from_account;
    END IF;
    
    -- Begin transaction
    BEGIN
        -- Generate transaction codes
        SELECT 'TRF' || TO_CHAR(NOW(), 'YYYYMMDD') || LPAD(CAST(NEXTVAL('transaction_code_seq') AS VARCHAR), 6, '0')
        INTO v_transaction_code_from;
        
        SELECT 'TRF' || TO_CHAR(NOW(), 'YYYYMMDD') || LPAD(CAST(NEXTVAL('transaction_code_seq') AS VARCHAR), 6, '0')
        INTO v_transaction_code_to;
        
        -- Create "from" transaction
        INSERT INTO transactions (
            transaction_code,
            account_id,
            transaction_type,
            amount,
            running_balance,
            description,
            status
        ) VALUES (
            v_transaction_code_from,
            v_from_account_id,
            'transfer_out',
            -p_amount,
            v_from_balance - p_amount,
            p_description || ' (To: ' || p_to_account || ')',
            'completed'
        ) RETURNING transaction_id INTO v_from_transaction_id;
        
        -- Create "to" transaction
        INSERT INTO transactions (
            transaction_code,
            account_id,
            transaction_type,
            amount,
            running_balance,
            description,
            status
        ) VALUES (
            v_transaction_code_to,
            v_to_account_id,
            'transfer_in',
            p_amount,
            v_to_balance + p_amount,
            p_description || ' (From: ' || p_from_account || ')',
            'completed'
        ) RETURNING transaction_id INTO v_to_transaction_id;
        
        -- Link the transactions in transaction_details
        INSERT INTO transaction_details (transaction_id, reference_id, metadata)
        VALUES (v_from_transaction_id, v_to_transaction_id, 
                jsonb_build_object('transfer_type', 'outgoing', 'related_transaction', v_transaction_code_to));
                
        INSERT INTO transaction_details (transaction_id, reference_id, metadata)
        VALUES (v_to_transaction_id, v_from_transaction_id, 
                jsonb_build_object('transfer_type', 'incoming', 'related_transaction', v_transaction_code_from));
        
        -- Update account balances
        UPDATE accounts
        SET balance = balance - p_amount
        WHERE account_id = v_from_account_id;
        
        UPDATE accounts
        SET balance = balance + p_amount
        WHERE account_id = v_to_account_id;
        
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END;
END;
$$;

-- Grant necessary permissions (adjust as needed for your environment)
-- GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO your_db_user;
-- GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO your_db_user;
-- GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO your_db_user;
-- GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA public TO your_db_user;

COMMENT ON DATABASE BankingDB IS 'Complete normalized bank database schema with roles, accounts, fees, and transactions.';
