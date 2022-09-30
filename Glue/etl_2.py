import psycopg2
import pandas as pd
import pandas.io.sql as sqlio

ENDPOINT="mycluster.cluster-123456789012.us-east-1.rds.amazonaws.com"
PORT="5432"
USR="postgres"
REGION="us-east-1"
DBNAME="postgres"
PASSWORD = "5Y67bg#r#"

ma_query = "CREATE TABLE bank_3month_rolling_avg (
  SELECT 
    Bank.Name, 
    Bank.idBank, 
    Branch.idBranch, 
    Branch.Bank_idBank c.Branch_idBranch, 
    a.Client_idClient, 
    a.idAccount, 
    l.Account_idAccount, 
    YEAR(loan_date) AS Year, 
    MONTH(loan_date) AS Month, 
    SUM(Amount) AS Amount, 
    AVG(
      SUM(Amount)
    ) OVER (
      ORDER BY 
        MIN(DATE) ROWS BETWEEN 2 PRECEDING 
        AND CURRENT ROW
    ) as rolling_3month_avg 
  FROM 
    Bank 
    JOIN Branch on Bank.idBank = Branch.Bank_idBank 
    JOIN Client c ON Branch_idBranch = c.Branch_idBranch 
    JOIN Account a on a.Client_idClient = c.Branch_idBranch 
    JOIN Loans l on l.Account_idAccount = a.idAccount 
  GROUP BY 
    YEAR(loan_date), 
    Month(loan_date) 
  ORDER BY 
    Year, 
    Month
)"



conn = psycopg2.connect(dbname=DBNAME, user=USR, password=PASSWORD, host=ENDPOINT, port=PORT)

conn.autocommit = True
cursor = conn.cursor()
cursor.execute(ma_query)

