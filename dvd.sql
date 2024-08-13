--------------------------- PART B ---------------------------

-- CREATE A FUNCTION TO PERFORM THE TRANSFORMATION IDENTIFIED IN PART A4 --
CREATE OR REPLACE FUNCTION get_month_and_year(rental_date TIMESTAMP)
RETURNS TEXT AS $$
BEGIN
    RETURN TO_CHAR(rental_date, 'Month YYYY');
END;
$$ LANGUAGE plpgsql;


--------------------------- PART C ---------------------------

-- CREATE DETAILED TABLE -- 
CREATE TABLE detailed_category_rentals (
	rental_id INTEGER,
	month_and_year TEXT,
	category_id INTEGER,
	category_name VARCHAR(25),
	film_id INTEGER,
	film_title VARCHAR(255),
	film_description TEXT,
	inventory_id INTEGER,
	total_category_rentals INTEGER
);


-- CREATE SUMMARY TABLE --
CREATE TABLE summary_category_rentals (
	month_and_year TEXT,
	category_id INTEGER,
	category_name VARCHAR(25),
	total_category_rentals INTEGER,
	CONSTRAINT summary_pk PRIMARY KEY (month_and_year, category_id)
);


-- VERIFY THAT DETAILED TABLE HAS BEEN CREATED --
SELECT * FROM detailed_category_rentals;

-- VERIFY THAT SUMMARY TABLE HAS BEEN CREATED --
SELECT * FROM summary_category_rentals;



--------------------------- PART D ---------------------------

-- EXTRACT RAW DATA FROM THE SOURCE DATABASE AND INSERT INTO DETAILED TABLE --
INSERT INTO detailed_category_rentals (
    rental_id,
    month_and_year,
    category_id,
    category_name,
    film_id,
    film_title,
    film_description,
    inventory_id,
    total_category_rentals
)
SELECT
    r.rental_id,
    get_month_and_year(r.rental_date) AS month_and_year,
    c.category_id,
    c.name AS category_name,
    f.film_id,
    f.title AS film_title,
    f.description AS film_description,
    i.inventory_id,
    SUM(COUNT(*)) OVER (PARTITION BY get_month_and_year(r.rental_date), c.category_id) AS total_category_rentals
FROM 
    rental r
JOIN
    inventory i ON r.inventory_id = i.inventory_id
JOIN
    film f ON i.film_id = f.film_id
JOIN 
    film_category fc ON f.film_id = fc.film_id
JOIN 
    category c ON fc.category_id = c.category_id
GROUP BY
	r.rental_id,
    get_month_and_year(r.rental_date), 
    c.category_id,
    c.name,
    f.film_id,
    f.title,
    f.description,
    i.inventory_id
ORDER BY
    get_month_and_year(r.rental_date) ASC,
    total_category_rentals DESC,
    f.film_id ASC;


-- VERIFY THAT DATA HAS BEEN ENTERED INTO DETAILED TABLE --
SELECT * FROM detailed_category_rentals;



--------------------------- PART E ---------------------------

-- CREATE FUNCTION FOR THE TRIGGER ON THE DETAILED TABLE TO CONTINUALLY UPDATE THE SUMMARY TABLE  --
CREATE OR REPLACE FUNCTION update_summary_table_function()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO summary_category_rentals (
        month_and_year,
        category_id,
        category_name,
        total_category_rentals
    )
    SELECT
        NEW.month_and_year,
        NEW.category_id,
        NEW.category_name,
        COUNT(*) AS total_category_rentals
    FROM
        detailed_category_rentals
    WHERE
        month_and_year = NEW.month_and_year
        AND category_id = NEW.category_id
    GROUP BY
        month_and_year,
        category_id,
        category_name
    ON CONFLICT (month_and_year, category_id) DO UPDATE
    SET
        total_category_rentals = EXCLUDED.total_category_rentals;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- CREATE TRIGGER ON DETAILED TABLE TO UPDATE SUMMARY TABLE --
CREATE TRIGGER update_summary_table_trigger
AFTER INSERT ON detailed_category_rentals
FOR EACH ROW
EXECUTE FUNCTION update_summary_table_function();



-- VERIFY THAT THE TRIGGER IS WORKING: SUMMARY TABLE IS UPDATING WHEN DATA HAS BEEN ENTERED INTO DETAILED TABLE --


-- VERIFICATION WITHOUT DATA IN THE SUMMARY TABLE:

-- 1st verify the data in the detailed table:
SELECT * FROM detailed_category_rentals;

-- 2nd: Assess the current state of the summary table:
SELECT * FROM summary_category_rentals;

-- 3rd: Testing the trigger by inserting additional data into the detailed table: 
INSERT INTO detailed_category_rentals (
    rental_id,
    month_and_year,
    category_id,
    category_name,
    film_id,
    film_title,
    film_description,
    inventory_id,
    total_category_rentals
)
VALUES
    (1, get_month_and_year('2005-08-15'), 15, 'Sports', 10, 'Film 1', 'Description 1', 1, 1),
    (2, get_month_and_year('2005-08-15'), 15, 'Sports', 27, 'Film 2', 'Description 2', 2, 1),
    (3, get_month_and_year('2005-08-15'), 2, 'Animation', 18, 'Film 3', 'Description 3', 3, 1),
    (4, get_month_and_year('2005-08-15'), 2, 'Animation', 23, 'Film 4', 'Description 4', 4, 1);


-- 4th verify the data has been entered into the detailed table:
SELECT * FROM detailed_category_rentals;

-- 5th: Verify that the summary table has correctly updated:
SELECT * FROM summary_category_rentals;



-- VERIFICATION WITH DATA IN THE SUMMARY TABLE:

-- 1st: Clear all existing data in the tables:
TRUNCATE TABLE detailed_category_rentals;
TRUNCATE TABLE summary_category_rentals;

-- 2nd: Verfiy that the tables are empty:
SELECT * FROM detailed_category_rentals;
SELECT * FROM summary_category_rentals;

-- 3rd: Re-extract the raw data from the source database and re-insert it back into the table:
INSERT INTO detailed_category_rentals (
    rental_id,
    month_and_year,
    category_id,
    category_name,
    film_id,
    film_title,
    film_description,
    inventory_id,
    total_category_rentals
)
SELECT
    r.rental_id,
    get_month_and_year(r.rental_date) AS month_and_year,
    c.category_id,
    c.name AS category_name,
    f.film_id,
    f.title AS film_title,
    f.description AS film_description,
    i.inventory_id,
    SUM(COUNT(*)) OVER (PARTITION BY get_month_and_year(r.rental_date), c.category_id) AS total_category_rentals
FROM 
    rental r
JOIN
    inventory i ON r.inventory_id = i.inventory_id
JOIN
    film f ON i.film_id = f.film_id
JOIN 
    film_category fc ON f.film_id = fc.film_id
JOIN 
    category c ON fc.category_id = c.category_id
GROUP BY
	r.rental_id,
    get_month_and_year(r.rental_date), 
    c.category_id,
    c.name,
    f.film_id,
    f.title,
    f.description,
    i.inventory_id
ORDER BY
    get_month_and_year(r.rental_date) ASC,
    total_category_rentals DESC,
    f.film_id ASC;

-- 4th: Verify the data has been entered in the detailed and summary table:
-- This also shows that the trigger works
SELECT * FROM detailed_category_rentals;
SELECT * FROM summary_category_rentals;

-- 5th: Testing the trigger by inserting additional data into the detailed table: 
INSERT INTO detailed_category_rentals (
    rental_id,
    month_and_year,
    category_id,
    category_name,
    film_id,
    film_title,
    film_description,
    inventory_id,
    total_category_rentals
)
VALUES
    (1, get_month_and_year('2005-08-15'), 15, 'Sports', 10, 'Film 1', 'Description 1', 1, 1),
    (2, get_month_and_year('2005-08-15'), 15, 'Sports', 27, 'Film 2', 'Description 2', 2, 1),
    (3, get_month_and_year('2005-08-15'), 2, 'Animation', 18, 'Film 3', 'Description 3', 3, 1),
    (4, get_month_and_year('2005-08-15'), 2, 'Animation', 23, 'Film 4', 'Description 4', 4, 1);

-- 6th: Verify the data has been added to the detailed table:
SELECT * FROM detailed_category_rentals;

-- 7th: Verify that the summary table has updated correctly:
SELECT * FROM summary_category_rentals;


--------------------------- PART F ---------------------------

-- CREATE A STORED PROCEDURE THAT CAN BE USED TO REFRESH THE DATA IN BOTH TABLES 
CREATE OR REPLACE PROCEDURE refresh_tables()
LANGUAGE plpgsql
AS $$
BEGIN

-- Clear the contents (existing data) of the detailed table and summary table:
TRUNCATE TABLE detailed_category_rentals;
TRUNCATE TABLE summary_category_rentals;

-- Perform the raw data extraction from Part D:
INSERT INTO detailed_category_rentals (
    rental_id,
    month_and_year,
    category_id,
    category_name,
    film_id,
    film_title,
    film_description,
    inventory_id,
    total_category_rentals 
)
SELECT
    r.rental_id,
    get_month_and_year(r.rental_date) AS month_and_year,
    c.category_id,
    c.name AS category_name,
    f.film_id,
    f.title AS film_title,
    f.description AS film_description,
    i.inventory_id,
    SUM(COUNT(*)) OVER (PARTITION BY get_month_and_year(r.rental_date), c.category_id) AS total_category_rentals
FROM 
    rental r
JOIN
    inventory i ON r.inventory_id = i.inventory_id
JOIN
    film f ON i.film_id = f.film_id
JOIN 
    film_category fc ON f.film_id = fc.film_id
JOIN 
    category c ON fc.category_id = c.category_id
GROUP BY
    r.rental_id,
    get_month_and_year(r.rental_date), 
    c.category_id,
    c.name,
    f.film_id,
    f.title,
    f.description,
    i.inventory_id
ORDER BY
    get_month_and_year(r.rental_date) ASC,
    total_category_rentals DESC,
    f.film_id ASC;

END;
$$;


CALL refresh_tables();



-- VERIFY THAT THE refresh_tables() FUNCTION CORRECTLY REFRESHES THE DATA IN BOTH TABLES

-- 1st: Run the function:
CALL refresh_tables();

-- 2nd: Verify that the data has been refreshed in the detailed table:
SELECT * FROM detailed_category_rentals;

-- 3rd: Verify that the data has been refreshed in the summary table:
SELECT * FROM summary_category_rentals;

