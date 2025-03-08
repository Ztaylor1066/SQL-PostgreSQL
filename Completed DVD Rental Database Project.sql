--Creating Detailed Table--

CREATE TABLE Rental_Detail_Table(
	customer_id smallint,
	first_name varchar(45),
	last_name varchar(45),
	email_address varchar(60),
	rental_date timestamp,
	amount_spent decimal(10,2)	
);
-----------------------------

--Test--
SELECT * FROM Rental_Detail_Table;
--------

--Populating Detailed Table--
INSERT INTO Rental_Detail_Table(customer_id, first_name, last_name,
	email_address, rental_date, amount_spent)
SELECT c.customer_id AS customer_id,
	   c.first_name AS first_name,
	   c.last_name AS last_name,
	   c.email AS email_address,
	   r.rental_date As rental_date,
	   p.amount AS amount_spent
From rental r
Join payment p ON p.rental_id = r.rental_id 
Join customer c ON c.customer_id = r.customer_id
ORDER BY customer_id, rental_date;
-----------------------------

--Test--
SELECT * FROM Rental_Detail_Table
--------

-- Creating Functions for Transformations--
CREATE OR REPLACE FUNCTION date_format(rental_date timestamp)
RETURNS TEXT 
LANGUAGE plpgsql
AS
$$
BEGIN
	RETURN TO_CHAR(rental_date, 'MONYYYY');
END;
$$

CREATE OR REPLACE FUNCTION name_format(first_name varchar(45), last_name varchar(45))
RETURNS TEXT
LANGUAGE plpgsql
AS 
$$
BEGIN
	return first_name || ' ' || last_name;
End;
$$
-----------------------------

--Creating Summary Table--
CREATE TABLE Summary_Table(
	customer_id smallint,
	first_last_name varchar(60),
	email_address varchar(60),
	rental_month text,
	amount_spent decimal(10,2)
);
-----------------------------

--Test--
SELECT * FROM Summary_Table;
--------
--Creating the TRIGGER AND TRIGGER functions--
CREATE TRIGGER New_Summary_Table
AFTER INSERT OR DELETE
ON Rental_Detail_Table
FOR EACH STATEMENT
EXECUTE PROCEDURE summary_trigger_fn();


CREATE OR REPLACE FUNCTION summary_trigger_fn()
RETURNS TRIGGER 
LANGUAGE plpgsql
AS 
$$
BEGIN
DELETE FROM Summary_Table;

INSERT INTO Summary_Table
SELECT 
	customer_id,
	name_format(first_name, last_name) AS full_name,
	email_address,
	date_format(rental_date) AS rental_month,
	SUM(amount_spent)
FROM Rental_Detail_Table
GROUP BY customer_id, full_name, email_address, rental_month
ORDER BY rental_month DESC, SUM(amount_spent) DESC;

RETURN NEW;
END;
$$;
-----------------------------

--Creating the stored procedure--
CREATE OR REPLACE PROCEDURE create_monthly_winners_tables()
LANGUAGE plpgsql
AS $$
BEGIN
DROP TABLE IF EXISTS Rental_Detail_Table;
DROP TABLE IF EXISTS Summary_Table;
DROP TRIGGER IF EXISTS New_Summary_Table ON Rental_Detail_Table;

CREATE TABLE Rental_Detail_Table AS
SELECT c.customer_id,
	   c.first_name,
	   c.last_name,
	   c.email AS email_address,
	   r.rental_date,
	   p.amount AS amount_spent
From rental r
Join payment p ON p.rental_id = r.rental_id 
Join customer c ON c.customer_id = r.customer_id
ORDER BY customer_id, rental_date desc;

CREATE TABLE Summary_Table AS
    SELECT customer_id,
           name_format(first_name, last_name) AS first_last_name,
           email_address,
           date_format(rental_date) AS rental_month,
           SUM(amount_spent) AS total_spent
    FROM Rental_Detail_Table
    GROUP BY customer_id, first_last_name, email_address, rental_month
    ORDER BY rental_month DESC, total_spent DESC;

CREATE TRIGGER New_Summary_Table
AFTER INSERT OR DELETE
ON Rental_Detail_Table
FOR EACH STATEMENT
EXECUTE FUNCTION summary_trigger_fn();

RETURN;
END;
$$;


-----------------------------
--Testing--
CALL create_monthly_winners_tables();

SELECT * FROM Summary_Table;

SELECT * FROM Rental_Detail_Table;

INSERT INTO Rental_Detail_Table(customer_id, first_name, last_name, email_address, rental_date, amount_spent)
VALUES(26, 'Jessica', 'Hall', 'jessica.hall@sakilacustomer.org', '2005-06-07', 20.00);

DELETE FROM Rental_Detail_Table
WHERE customer_id = 26 
AND first_name = 'Jessica'
AND last_name = 'Hall'
AND email_address = 'jessica.hall@sakilacustomer.org'
AND rental_date = '2005-06-07' 
AND amount_spent = 20.00;

DROP TABLE Rental_Detail_Table;
DROP TABLE Summary_Table;
DROP FUNCTION IF EXISTS name_format();
DROP FUNCTION IF EXISTS date_format();
DROP TRIGGER New_Summary_Table ON Rental_Detail_Table;
DROP TRIGGER New_Summary_Table;
DROP PROCEDURE IF EXISTS create_monthly_winners_tables;
