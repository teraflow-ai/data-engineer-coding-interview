import sys
from awsglue.transforms import *
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue import DynamicFrame
from awsglue.utils import getResolvedOptions





arg = getResolvedOptions(sys.argv, ['JOB_NAME'])
sc = SparkContext.getOrCreate()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(arg['JOB_NAME'], arg)



# s3 output directory
output_dir = "s3://gluetest007/outputtestcase/"

# Create source DataFrames from the Glue Data Catalog tables
loan = glueContext.create_data_frame.from_catalog(
    database="bank_data", table_name="loans", transformation_ctx="loan"
)
account = glueContext.create_data_frame.from_catalog(
    database="bank_data", table_name="account", transformation_ctx="account"
)
client = glueContext.create_data_frame.from_catalog(
    database="bank_data", table_name="client", transformation_ctx="client"
)
branch = glueContext.create_data_frame.from_catalog(
    database="bank_data", table_name="branch", transformation_ctx="branch"
)
bank = glueContext.create_data_frame.from_catalog(
    database="bank_data", table_name="bank_details", transformation_ctx="bank"
)

loan_view =loan.createorReplaceTempView("loan")
client_view=client.createorReplaceTempView("client")
bank_view =bank.createorReplaceTempView("bank")
account_view = account.createorReplaceTempView("account")
branch_view =branch.createorReplaceTempView("branch")

# Join tables and Calculate the average
sqlquery = """        
select Name, idBranch, extract(year from loan_date) year, extract(month from loan_date) month, 
          avg(amount) over (partition by Name,idBranch, year, month ) average
from (select br.idBranch,b.Name,c.Name as client_name,a.idAccount,l.amount,l.loan_date 
        from bank_data.bank b
        join bank_data.branch br 
        on b.idBank = br.Bank_idBank
        join  bank_data.client c 
        on br.idBranch= c.Branch_idBranch 
        join bank_data.account a
        on a.Client_idClient = c.idClinet
        join  bank_data.loan l
        on a.idAccount = l.Account_idAccount
        where l.date=> to_iso8601(current_date - interval '3' month)
        ) 
 
"""



loans_avg_result = spark.sql(sqlquery)

# Write Spark Dataframe to S3
loans_avg_result.write.format("csv").option("header", True).mode("append").partitionBy(
    "BankName", "year", "month"
).save(path=output_dir)


job.commit()
