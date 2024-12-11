-- Database Assignment 6
-- Brittany Klose
-- Date: 12/10/24
-- This assignment uses stored procedures to test and evaluate point and range queries 
-- 	with and without indexes on different size datasets(50k, 100k, 150k)

set SQL_SAFE_UPDATES=0; -- Prevent dangerous updates

set FOREIGN_KEY_CHECKS=0; -- Disables enforment of foreign key constraints


/* **************************************************************************************** 
-- Stament below controls:
--     Max time (seconds) the client will wait while trying to establish a 
	   connection to the MySQL server 
--     How long client will wait for a response from the server once a request has 
       been sent over
**************************************************************************************** */
SHOW SESSION VARIABLES LIKE '%timeout%';       
SET GLOBAL mysqlx_connect_timeout = 600;
SET GLOBAL mysqlx_read_timeout = 600;

-- Database where accounts table is created
create database hwindex_procedures;
use hwindex_procedures;

drop table accounts;
-- ---------------------------------
-- Task 1: Create the accounts table:
-- ---------------------------------
create table accounts (
  account_num CHAR(5) PRIMARY KEY,    -- 5-digit account number (00001, 00002, ...)
  branch_name VARCHAR(50),            -- Branch name (e.g., Brighton, Downtown, etc.)
  balance DECIMAL(10, 2),             -- Balance of account, with two decimal places (1000.50)
  account_type VARCHAR(50)            -- Type of the account (e.g., Savings, Checking)
);

    
/* ***************************************************************************************************
The procedure generates 50,000 records for the accounts table, with the account_num padded to 5 digits.
branch_name is randomly selected from one of the six predefined branches.
balance is generated randomly, between 0 and 100,000, rounded to two decimal places.
***************************************************************************************************** */
-- Change delimiter to allow semicolons inside the procedure
delimiter $$

create procedure generate_accounts()
begin
  DECLARE i INT DEFAULT 1;
  DECLARE branch_name VARCHAR(50);
  DECLARE account_type VARCHAR(50);


-- --------------------------------------------------------------------
-- Task 2. & 5. Populate accounts table with datasets 50k, 100k, 150k:
-- ---------------------------------------------------------------------
 -- Loop to generate given number of account records
 -- WHILE i <= 150000 DO
 -- WHILE i <= 100000 DO
  WHILE i <= 50000 DO

    -- Randomly select a branch from the list of branches
    set branch_name = ELT(FLOOR(1 + (RAND() * 6)), 'Brighton', 'Downtown', 'Mianus', 'Perryridge', 'Redwood', 'RoundHill');
    
    -- Randomly select an account type
    set account_type = ELT(FLOOR(1 + (RAND() * 2)), 'Savings', 'Checking');
    
    -- Insert account record
    insert into accounts (account_num, branch_name, balance, account_type)
    values (
      LPAD(i, 5, '0'),                   -- Account number as just digits, padded to 5 digits (e.g., 00001, 00002, ...)
      branch_name,                       -- Randomly selected branch name
      ROUND((RAND() * 100000), 2),       -- Random balance between 0 and 100,000, rounded to 2 decimal places
      account_type                       -- Randomly selected account type (Savings/Checking)
    );

    set i = i + 1;
  end while;
end$$

-- Reset the delimiter back to the default semicolon
delimiter ;

-- Execute the procedure
call generate_accounts();

select count(*) from accounts; -- Track progress of generating account

select * from accounts limit 10; -- Preview snipet of code to make sure it's working

-- ---------------------------------------------------------------------
-- Task 3. Create indexes on the branch_name and account_type columns:
-- ----------------------------------------------------------------------
create index idx_branch_name ON accounts (branch_name);
DROP INDEX idx_branch_name ON accounts;

create index idx_branch_account_type ON accounts (branch_name, account_type);
DROP INDEX idx_branch_account_type ON accounts;

create index indx_balance on accounts(branch_name, balance);
DROP INDEX indx_balance ON accounts;

alter table accounts drop primary key;
alter table accounts add primary key(account_num);

-- ---------------------------------------------------
-- Task 4. Compare point queries and range queries:
-- ---------------------------------------------------
-- Point Query 1
SELECT count(*) FROM accounts  WHERE branch_name = 'Redwood' AND account_type = 'Checking'; 

-- Point Query 2
-- SELECT count(*) FROM accounts  WHERE branch_name = 'Perryridge' AND account_type = 'Savings'; 

-- Point Query 3
-- SELECT count(*) FROM accounts  WHERE branch_name = 'Mianus' AND balance = 90000; 

-- Range Query 1
-- SELECT count(*) FROM accounts  WHERE branch_name = 'Mianus' AND balance BETWEEN 90000 AND 70000;

-- Range Query 2
-- SELECT count(*) FROM accounts  WHERE branch_name = 'Brighton' AND balance BETWEEN 30000 AND 10000;

-- Range Query 3
-- SELECT count(*) FROM accounts  WHERE branch_name = 'Downtown' AND balance BETWEEN 10000 AND 5000;


-- --------------------------
-- Task 6. Timing analysis:
-- --------------------------
-- Step 1: Capture the start time with microsecond precision (6)
set @start_time = NOW(6);

-- Step 2: Run the query you want to measure
select count(*) FROM accounts 
where branch_name = 'Mianus'
-- and account_type = 'Savings';
-- and balance="90000";
and balance between 90000 AND 70000;

-- Step 3: Capture the end time with microsecond precision
set @end_time = NOW(6);

-- Step 4: Calculate the difference in microseconds
select 
    TIMESTAMPDIFF(MICROSECOND, @start_time, @end_time) AS execution_time_microseconds,
    TIMESTAMPDIFF(SECOND, @start_time, @end_time) AS execution_time_seconds;


-- ---------------------------------------------------------------------
-- Task 7. Create a stored procedure to measure average execution times:
-- ----------------------------------------------------------------------
delimiter $$

create procedure calculate_avg_time(in query_text TEXT)
begin 
	declare i INT DEFAULT 1;
    declare start_time DATETIME(6);
	declare end_time DATETIME(6);
    declare execution_time_ms bigint;
    declare sum_time bigint default 0;
	declare avg_time double;
	declare query_var text;
   
	-- Create loop to perform query 10 times
	while i<=10 do
		set start_time=NOW(6);
		
        set query_var=query_text;
		prepare stmt from @query_var;
		execute stmt;
		deallocate prepare stmt;
		
		set end_time=NOW(6);
        set execution_time_ms=TIMESTAMPDIFF(MICROSECOND, start_time, end_time);
        set sum_time=sum_time + execution_time_ms;
		set i = i + 1;
		
       end while;
       set avg_time=sum_time/10;
        
		SELECT 
            sum_time,
			avg_time;
    
end$$

-- Reset the delimiter back to the default semicolon
delimiter ;

-- Execute the procedure
call calculate_avg_time('SELECT count(*) FROM accounts  WHERE branch_name = ''Redwood'' AND account_type = ''Checking''');
call calculate_avg_time('SELECT count(*) FROM accounts  WHERE branch_name = ''Perryridge'' AND account_type = ''Savings''');
call calculate_avg_time('SELECT count(*) FROM accounts  WHERE branch_name = ''Mianus'' AND balance = 90000');

call calculate_avg_time('SELECT count(*) FROM accounts  WHERE branch_name = ''Mianus'' AND balance BETWEEN 90000 AND 70000');
call calculate_avg_time('SELECT count(*) FROM accounts  WHERE branch_name = ''Brighton'' AND balance BETWEEN 30000 AND 10000');
call calculate_avg_time('SELECT count(*) FROM accounts  WHERE branch_name = ''Downtown'' AND balance BETWEEN 10000 AND 5000');

