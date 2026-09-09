-- READ ONLY verification for production migration 007.

SELECT TABLE_NAME, ENGINE, TABLE_COLLATION
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN ('employee_kyc_bank_private', 'employee_kyc_bank_amendment_private')
ORDER BY TABLE_NAME;

SELECT TABLE_NAME, COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, EXTRA
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN ('employee_kyc_bank_private', 'employee_kyc_bank_amendment_private')
ORDER BY TABLE_NAME, ORDINAL_POSITION;

SELECT TABLE_NAME, INDEX_NAME, NON_UNIQUE, SEQ_IN_INDEX, COLUMN_NAME
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN ('employee_kyc_bank_private', 'employee_kyc_bank_amendment_private')
ORDER BY TABLE_NAME, INDEX_NAME, SEQ_IN_INDEX;

SELECT TABLE_NAME, CONSTRAINT_NAME, REFERENCED_TABLE_NAME, DELETE_RULE
FROM information_schema.REFERENTIAL_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA = DATABASE()
  AND TABLE_NAME IN ('employee_kyc_bank_private', 'employee_kyc_bank_amendment_private')
ORDER BY TABLE_NAME, CONSTRAINT_NAME;

SELECT 'employee_kyc_bank_private' AS table_name, COUNT(*) AS initial_row_count FROM employee_kyc_bank_private
UNION ALL
SELECT 'employee_kyc_bank_amendment_private', COUNT(*) FROM employee_kyc_bank_amendment_private;
