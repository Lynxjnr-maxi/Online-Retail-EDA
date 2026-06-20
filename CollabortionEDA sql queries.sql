SELECT *
FROM   dbo.OnlineRetail; 
--- Finding Duplicates ( InvoiceNo has many duplicates but the other columns have distinct values; same 
--- InvoiceNo but different transaction details)

SELECT   InvoiceNo,
         StockCode,
         Description,
         Quantity,
         InvoiceDate,
         UnitPrice,
         CustomerID,
         Country,
         COUNT(*) AS duplicates
FROM     dbo.OnlineRetail
GROUP BY InvoiceNo, StockCode, Description, Quantity, InvoiceDate, UnitPrice, CustomerID, Country
HAVING   count(*) > 1; 
--- Change InvoiceDate column to date type

ALTER TABLE dbo.OnlineRetail ALTER COLUMN InvoiceDate DATE;
--- Round UnitPrice to 2 decimal places

UPDATE dbo.OnlineRetail
SET    Unitprice = round(UnitPrice, 2);
--- Database Exploration

SELECT   DISTINCT customerID,
                  datediff(month, min(InvoiceDate), max(InvoiceDate)) AS lifespan
FROM     dbo.OnlineRetail
GROUP BY CustomerID
ORDER BY CustomerID ASC;
--- convert quantity to positive values

SELECT ABS(quantity * unitprice) AS revenue
FROM   dbo.OnlineRetail; 
-- add column returned

ALTER TABLE dbo.onlineretail
    ADD returned INT; 
  --- transfer negative quantity values to returned column

UPDATE dbo.OnlineRetail
SET    returned = quantity
WHERE  quantity < 0; 
--- cross-referencing transfer of values = status check

SELECT returned
FROM   dbo.onlineretail
WHERE  returned < 0;

SELECT quantity
FROM   dbo.OnlineRetail
WHERE  quantity < 0;
--- delete the negative values from quantity column 

DELETE dbo.OnlineRetail
WHERE  quantity < 0; 
--- detect missing values in columns

SELECT sum(CASE WHEN returned IS NULL THEN 1 ELSE 0 END) AS returnednulls,
       sum(CASE WHEN country IS NULL THEN 1 ELSE 0 END) AS countrynulls,
       sum(CASE WHEN CustomerID IS NULL THEN 1 ELSE 0 END) AS CustomerIDnulls,
       sum(CASE WHEN UnitPrice IS NULL THEN 1 ELSE 0 END) AS Unitpricenulls,
       sum(CASE WHEN InvoiceDate IS NULL THEN 1 ELSE 0 END) AS InvoiceDate
FROM   dbo.OnlineRetail;

SELECT *
FROM   dbo.OnlineRetail;
--- Sum of Invoices

SELECT format(count(DISTINCT InvoiceNo), 'N0') AS count_of_Invoices
FROM   dbo.OnlineRetail;
--- Sum of products(stockCode)

SELECT format(count(DISTINCT StockCode), 'N0') AS count_of_products
FROM   dbo.OnlineRetail; 

--- Sum of Quantity sold

SELECT sum(quantity) AS quantity_sold
FROM   dbo.OnlineRetail; 
--- datetime

SELECT datediff(month, min(InvoiceDate), max(InvoiceDate)) AS lifespan_months
FROM   dbo.OnlineRetail;

SELECT   StockCode,
         datediff(month, min(InvoiceDate), max(InvoiceDate)) AS lifespan_months
FROM     dbo.OnlineRetail
GROUP BY StockCode;

SELECT   DISTINCT CustomerID,
  datediff(month, min(InvoiceDate), max(InvoiceDate)) AS lifespan_months,
  CASE WHEN datediff(month, min(InvoiceDate), max(InvoiceDate)) > 1 THEN 'repeating customer'
  ELSE 'one time customer' 
  END AS Customer_Segmentation
FROM     dbo.OnlineRetail
GROUP BY CustomerID;
--- UnitPrice(Revenue)

SELECT format(sum(Unitprice * COALESCE (quantity, 0)), 'N0') AS revenue
FROM   dbo.OnlineRetail; 
-- Revenue per product

SELECT   DISTINCT StockCode,
                  format(sum(Unitprice * COALESCE (quantity, 0)), 'N0') AS revenue_per_product
FROM     dbo.OnlineRetail
GROUP BY StockCode;
--- Revenue per month & year

SELECT   year(InvoiceDate) AS year,
         month(InvoiceDate) AS month,
         format(sum(Unitprice * COALESCE (quantity, 0)), 'N0') AS revenue_per_month
FROM     dbo.OnlineRetail
GROUP BY month(InvoiceDate), year(InvoiceDate)
ORDER BY month(InvoiceDate) ASC;
--- Revene per Customer

SELECT   DISTINCT CustomerID,
                  format(sum(Unitprice * COALESCE (quantity, 0)), 'N0') AS revenue_per_customer
FROM     dbo.OnlineRetail
GROUP BY CustomerID; 
--- Revenue per Country

SELECT   DISTINCT Country,
                  format(sum(Unitprice * COALESCE (quantity, 0)), 'N0') AS revenue_per_country
FROM     dbo.OnlineRetail
GROUP BY Country; 
--- Average Invoice Value (AIV)

SELECT sum(Unitprice * COALESCE (quantity, 0)) / count(DISTINCT InvoiceNo) AS AIV
FROM   dbo.OnlineRetail; 
--- Average Transaction Value (ATV) per customer

SELECT sum(Unitprice * COALESCE (quantity, 0)) / count(DISTINCT CustomerID) AS ATV
FROM   dbo.OnlineRetail; 

--- Customer report/view
--- contains :
--- customerID 
--- lifespan_months - how long they have been with us
--- Customer_Segmentation - repeating or one time customer
--- Average mothly order
--- Sum of Quantity bought
--- Country of origin 
--- Revenue per customer
--- Average Invoice Order
--- Count of transactions


GO
CREATE OR ALTER VIEW customer_report
AS
WITH   base_query
AS (SELECT DISTINCT CustomerID,
                        InvoiceDate,
                        Quantity,
                        UnitPrice,
                        Country,
                        InvoiceNo
        FROM   dbo.OnlineRetail),
       calculationCTE
AS (SELECT   customerID,
datediff(month, min(InvoiceDate), max(InvoiceDate)) AS lifespan_months,
CASE WHEN datediff(month, min(InvoiceDate), max(InvoiceDate)) > 6 THEN 'loyal customer' 
ELSE 'short term customer' 
END AS Customer_Segmentation,
 sum(quantity) AS sum_quantity_bought,
round(sum(UnitPrice * Quantity), 2) AS revenue,
CASE WHEN sum(UnitPrice * quantity) < 1000 THEN 'standard customer'
WHEN sum(UnitPrice * quantity) BETWEEN 1000 AND 10000 THEN 'VIP customer' 
WHEN sum(UnitPrice * quantity) > 10000 THEN 'high value customer'
ELSE NULL 
END AS Customer_Monetary_Section,
round(sum(UnitPrice * Quantity) / NULLIF (datediff(month, min(InvoiceDate), max(InvoiceDate)), 0), 2) 
AS Average_Monthly_order,
round(sum(UnitPrice * Quantity) / NULLIF (count(DISTINCT InvoiceNo), 0), 2) AS Average_Invoice_Order,
 count(DISTINCT InvoiceNo) AS count_customer_transactions,
 CASE WHEN count(DISTINCT InvoiceNo) = 1 THEN 'one time buyer'
 WHEN count(DISTINCT InvoiceNo) BETWEEN 2 AND 5 THEN 'occasional buyer' 
 WHEN count(DISTINCT InvoiceNo) > 5 THEN 'frequent buyer' 
 ELSE NULL 
 END AS Customer_Frequency,
                 country
        FROM     base_query
        GROUP BY CustomerID, Country)
SELECT *
FROM   calculationCTE;


GO
SELECT   *
FROM     dbo.customer_report
ORDER BY CustomerID ASc
