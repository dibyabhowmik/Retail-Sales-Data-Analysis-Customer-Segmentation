CREATE DATABASE Retail_db;
USE  Retail_db;
SELECT * FROM retail_sales;
SELECT * FROM customer_dim;
SELECT * FROM product_dim;
ALTER TABLE customer_dim 
MODIFY CustomerID VARCHAR(50) NOT NULL;
ALTER TABLE customer_dim
ADD PRIMARY KEY (CustomerID);
ALTER TABLE product_dim 
MODIFY ProductID VARCHAR(50) NOT NULL;
SHOW CREATE TABLE product_dim;
ALTER TABLE retail_sales
MODIFY CustomerID VARCHAR(50) NOT NULL;
ALTER TABLE retail_sales
ADD CONSTRAINT fk_sales_customer
FOREIGN KEY (CustomerID) REFERENCES customer_dim(CustomerID);
ALTER TABLE retail_sales
MODIFY ProductID VARCHAR(50) NOT NULL;
ALTER TABLE retail_sales
ADD CONSTRAINT fk_sales_product
FOREIGN KEY (ProductID) REFERENCES product_dim(ProductID);

##Create sales_cleaned table
CREATE TABLE sales_clean (
  TransactionID BIGINT AUTO_INCREMENT PRIMARY KEY,
  InvoiceNo VARCHAR(100),
  InvoiceDate DATETIME,
  CustomerID VARCHAR(50),
  ProductID VARCHAR(50),
  Quantity INT,
  UnitPrice DECIMAL(12,2),
  DiscountPct DECIMAL(5,2),
  TotalPrice DECIMAL(12,2),
  Description TEXT,
  Category VARCHAR(100)
);
  
SELECT 
    InvoiceDate,
    STR_TO_DATE(InvoiceDate, '%d-%m-%Y %H:%i') AS parsed_date
FROM retail_sales
LIMIT 10;
ALTER TABLE sales_clean 
MODIFY TotalPrice DECIMAL(15,2);

INSERT INTO sales_clean 
(InvoiceNo, InvoiceDate, CustomerID, ProductID, Quantity, UnitPrice, DiscountPct, TotalPrice, Description, Category)
SELECT 
    InvoiceNo,
    STR_TO_DATE(InvoiceDate, '%d-%m-%Y %H:%i'),
    CustomerID,
    ProductID,
    Quantity,
    UnitPrice,
    COALESCE(DiscountPct,0),
    COALESCE(TotalPrice, Quantity * UnitPrice * (1 - COALESCE(DiscountPct,0)/100)),
    Description,
    Category
FROM retail_sales
;
SELECT * FROM sales_clean;
SELECT DISTINCT InvoiceDate 
FROM retail_sales 
LIMIT 20;
  
SHOW COLUMNS FROM retail_sales LIKE 'InvoiceDate';
##Top 20 customers by revenue
SELECT CustomerID, SUM(TotalPrice) AS revenue, COUNT(DISTINCT InvoiceNo) AS orders
FROM sales_clean
GROUP BY CustomerID
ORDER BY revenue DESC
LIMIT 20;

##Top 20 products by revenue
SELECT s.ProductID, p.Description, p.Category, SUM(s.TotalPrice) AS revenue, SUM(s.Quantity) AS total_qty
FROM sales_clean s
JOIN product_dim p ON s.ProductID = p.ProductID
GROUP BY s.ProductID, p.Description, p.Category
ORDER BY revenue DESC
LIMIT 20;

##Revenue by category
SELECT p.Category, SUM(s.TotalPrice) AS revenue
FROM sales_clean s
JOIN product_dim p ON s.ProductID = p.ProductID
GROUP BY p.Category
ORDER BY revenue DESC;

##Total daily revenue
SELECT DATE(InvoiceDate) AS day, SUM(TotalPrice) AS revenue
FROM sales_clean
GROUP BY day
ORDER BY day;

##Average Order Value (AOV)
SELECT SUM(TotalPrice)/COUNT(DISTINCT InvoiceNo) AS AOV
FROM sales_clean;

##RFM Table for segmentation
##snapshot date = day after last transaction
SET @snapshot_date = (SELECT DATE_ADD(MAX(InvoiceDate), INTERVAL 1 DAY) FROM sales_clean);
CREATE TABLE customer_rfm AS
SELECT 
  CustomerID,
  MIN(InvoiceDate) AS first_purchase,
  MAX(InvoiceDate) AS last_purchase,
  DATEDIFF(@snapshot_date, MAX(InvoiceDate)) AS recency,
  COUNT(DISTINCT InvoiceNo) AS frequency,
  SUM(TotalPrice) AS monetary
FROM sales_clean
GROUP BY CustomerID;
##RFM table
SELECT * FROM customer_rfm ;

##Simple cohort / retention (monthly cohorts)
##first purchase month per customer
CREATE TABLE customer_cohort AS
SELECT 
    CustomerID,
    DATE_FORMAT(MIN(InvoiceDate),'%Y-%m-01') AS cohort_month
FROM sales_clean
GROUP BY CustomerID;
##Monthly activity per cohort
SELECT
  c.cohort_month,
  DATE_FORMAT(s.InvoiceDate,'%Y-%m-01') AS order_month,
  COUNT(DISTINCT s.CustomerID) AS customers
FROM sales_clean s
JOIN customer_cohort c ON s.CustomerID = c.CustomerID
GROUP BY c.cohort_month, order_month
ORDER BY c.cohort_month, order_month;

SELECT * FROM sales_clean;
SELECT USER();




