
import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job

#Custom import to get date ready for SQL
from datetime import datetime
from pyspark.sql.functions import year
from pyspark.sql.functions import to_date

## @params: [JOB_NAME]
args = getResolvedOptions(sys.argv, ['JOB_NAME'])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

#Getting date here
current_date =datetime.now().strftime('%Y-%m-%d')


#Generated from glue studio for SQL componenet
def sparkSqlQuery(glueContext, query, mapping, transformation_ctx) -> DynamicFrame:
    for alias, frame in mapping.items():
        frame.toDF().createOrReplaceTempView(alias)
    result = spark.sql(query)
    return DynamicFrame.fromDF(result, glueContext, transformation_ctx)

#Get the data from the glue catalog via Terraform
Table_Banks = glueContext.create_dynamic_frame.from_catalog(database = "bank_data", table_name = "Bank", transformation_ctx = "Table_Banks")
Table_Branch = glueContext.create_dynamic_frame.from_catalog(database = "bank_data", table_name = "Branch", transformation_ctx = "Table_Branch")
Table_Client = glueContext.create_dynamic_frame.from_catalog(database = "bank_data", table_name = "Client", transformation_ctx = "Table_Client")
Table_Worker = glueContext.create_dynamic_frame.from_catalog(database = "bank_data", table_name = "Worker", transformation_ctx = "Table_Worker")
Table_Account = glueContext.create_dynamic_frame.from_catalog(database = "bank_data", table_name = "Account", transformation_ctx = "Table_Account")
Table_Loans = glueContext.create_dynamic_frame.from_catalog(database = "bank_data", table_name = "Loans", transformation_ctx = "Table_Loans")


#SQL Query to get the correct result
query_sql = """
SELECT 
  ba.Name as Bank_Name, 
  ba.Address as Branch_Address, 
  YEAR(lo.loan_date) AS Year, 
  MONTH(lo.loan_date) AS Month, 
  SUM(lo.amount) AS Moving_Load_Amount 
FROM 
  Banks ba 
  LEFT JOIN Branch br ON ba.Ban_idBank = br.Bank_idBank 
  LEFT JOIN Client cl ON br.idBranch = cl.Branch_idBranch 
  JOIN Account ac ON cl.idClinet = Client_idClient 
  LEFT JOIN Loans lo ON ac.idAccount = lo.Account_idAccount 
WHERE 
  Month(lo.loan_date) >= MONTH(add_months(""" + current_date + """, -3)) 
GROUP BY 
  ba.Name as Bank_Name, 
  ba.Address as Branch_Address, 
  YEAR(lo.loan_date) AS Year, 
  MONTH(lo.loan_date) AS Month

"""

#Execute the sql against the data
sql_execution = sparkSqlQuery(
    glueContext,
    query=query_sql,
    mapping={"Bank": Table_Banks,"Branch": Table_Branch,"Client": Table_Client,"Account": Table_Account,"Loans": Table_Loans},
    transformation_ctx="sql_execution",
)

#Save Data back to s3 as csv
#Did not manage to get the file name changed
Save_to_s3 = glueContext.write_dynamic_frame.from_options(
    frame=sql_execution,
    connection_type="s3",
    format="csv",
    connection_options={"path": "s3://bank_date/", "partitionKeys": [Table_Banks.Name , datetime.now().year,datetime.now().month,datetime.now().day]},
    transformation_ctx="Save_to_s3",
)

job.commit()

