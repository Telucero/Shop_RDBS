BEGIN TRY
    -- Start a transaction
    BEGIN TRANSACTION;

    DECLARE @partsFilePath NVARCHAR(255) = 'data/parts.json';
    DECLARE @transactionDateFilePath NVARCHAR(255) = 'data/transaction_date.json';
    DECLARE @transactionFilePath NVARCHAR(255) = 'data/transaction.json';

    -- Logging
    PRINT 'Dropping existing tables if they exist...';

    -- Drop existing tables if they exist
    IF OBJECT_ID('dbo.prj_transaction_part') IS NOT NULL
        DROP TABLE dbo.prj_transaction_part;
    IF OBJECT_ID('dbo.prj_part') IS NOT NULL
        DROP TABLE dbo.prj_part;
    IF OBJECT_ID('dbo.prj_transaction') IS NOT NULL
        DROP TABLE dbo.prj_transaction;
    IF OBJECT_ID('dbo.prj_transaction_type') IS NOT NULL
        DROP TABLE dbo.prj_transaction_type;

    -- Logging
    PRINT 'Creating prj_transaction_type table...';

    -- Create prj_transaction_type table
    CREATE TABLE dbo.prj_transaction_type (
        trans_type_id INT IDENTITY PRIMARY KEY,
        trans_type_text VARCHAR(30) UNIQUE NOT NULL
    );

    -- Insert data into prj_transaction_type table
    INSERT INTO dbo.prj_transaction_type (trans_type_text) 
    VALUES ('Purchase'), ('Used');

    -- Logging
    PRINT 'Creating prj_part table...';

    -- Create prj_part table
    CREATE TABLE dbo.prj_part (
        part_id INT IDENTITY PRIMARY KEY,
        part_name VARCHAR(30) UNIQUE NOT NULL,
        part_cost MONEY NOT NULL
    );

    -- Insert data into prj_part table using OPENROWSET
    INSERT INTO dbo.prj_part (part_name, part_cost)
    SELECT part_name, part_cost
    FROM OPENROWSET (BULK @partsFilePath, SINGLE_CLOB) as j
    CROSS APPLY OPENJSON (j)
    WITH (
        part_name VARCHAR(30),
        part_cost MONEY
    );

    -- Logging
    PRINT 'Creating prj_transaction table...';

    -- Create prj_transaction table
    CREATE TABLE dbo.prj_transaction (
        transaction_date DATETIME NOT NULL,
        transaction_id INT IDENTITY NOT NULL PRIMARY KEY,
        transaction_type_id INT NOT NULL,
        FOREIGN KEY (transaction_type_id) REFERENCES dbo.prj_transaction_type(trans_type_id)
    );

    -- Insert data into prj_transaction table using OPENROWSET
    INSERT INTO dbo.prj_transaction (transaction_date, transaction_type_id)
    SELECT transaction_date, transaction_type_id
    FROM OPENROWSET (BULK @transactionDateFilePath, SINGLE_CLOB) as j
    CROSS APPLY OPENJSON (j)
    WITH (
        transaction_date DATETIME,
        transaction_type_id INT
    );

    -- Logging
    PRINT 'Creating prj_transaction_part table...';

    -- Create prj_transaction_part table
    CREATE TABLE dbo.prj_transaction_part (
        transaction_part_id INT IDENTITY PRIMARY KEY,
        tp_transaction_id INT NOT NULL,
        tp_part_id INT NOT NULL,
        tp_quantity INT NOT NULL,
        FOREIGN KEY (tp_transaction_id) REFERENCES dbo.prj_transaction(transaction_id),
        FOREIGN KEY (tp_part_id) REFERENCES dbo.prj_part(part_id)
    );

    -- Insert data into prj_transaction_part table using OPENROWSET
    INSERT INTO dbo.prj_transaction_part (tp_transaction_id, tp_part_id, tp_quantity)
    SELECT tp_transaction_id, tp_part_id, tp_quantity
    FROM OPENROWSET (BULK @transactionFilePath, SINGLE_CLOB) as j
    CROSS APPLY OPENJSON (j)
    WITH (
        tp_transaction_id INT '$.transaction_id',
        tp_part_id INT '$.parts[0].part_id',
        tp_quantity INT '$.parts[0].quantity'
    );

    -- Commit the transaction
    COMMIT TRANSACTION;
    PRINT 'Transaction committed successfully.';
END TRY
BEGIN CATCH
    -- Rollback the transaction if an error occurs
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    
    -- Print the error message
    PRINT 'Error occurred: ' + ERROR_MESSAGE();
END CATCH;


select 
	part_name,
	Sum(part_cost * tp_quantity) as check_entry
from prj_transaction_part
	join prj_transaction on transaction_id = tp_transaction_id
	join prj_transaction_type on transaction_type_id=trans_type_id
	join prj_part on part_id=tp_part_id
group by part_name


--1
select * from prj_part

--2
select top 5 * from prj_part
order by part_cost desc

--3
Select trans_type_text, month(transaction_date) as Month, part_name,
part_cost, tp_quantity, (part_cost * tp_quantity) as total_cost
from prj_transaction_part
	join prj_transaction on transaction_id = tp_transaction_id
	join prj_transaction_type on transaction_type_id=trans_type_id
	join prj_part on part_id=tp_part_id
group by transaction_date,trans_type_text, part_name, part_cost, tp_quantity
order by month(transaction_date), trans_type_text, part_name

--4
Select part_name, sum(tp_quantity) as Remaining
from prj_transaction_part
	join prj_part on part_id=tp_part_id
where part_name ='Freeze Ray'
group by part_name

--5
select 
sum(tp_quantity * part_cost) as total_cost
from prj_part
	join prj_transaction_part on part_id = tp_part_id


--6
--start of statement
select trans_type_text , count(transaction_id) as transactions, 
CURRENT_USER as ME, GETDATE() as Today, DB_NAME() as My_Database from prj_transaction_type
	join prj_transaction on transaction_type_id = trans_type_id
group by trans_type_text
--end of statement 