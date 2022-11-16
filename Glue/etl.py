import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from s3_concat import S3Concat

"""
This Glue Job will process data from the Banking Group Aurora database and generate a monthly file of the moving average loan amounts.
The results will be written to S3 in a path partitioned by Bank name, year and month.
"""

sc = SparkContext.getOrCreate()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
# Create source DynamicFrames from the Glue Data Catalog tables
src_loan = glueContext.create_dynamic_frame.from_catalog(database = "aurora", table_name = "finance_public_loans", transformation_ctx = "src_loan")
src_account = glueContext.create_dynamic_frame.from_catalog(database = "aurora", table_name = "finance_public_account", transformation_ctx = "src_account")
src_client = glueContext.create_dynamic_frame.from_catalog(database = "aurora", table_name = "finance_public_client", transformation_ctx = "src_client")
src_branch = glueContext.create_dynamic_frame.from_catalog(database = "aurora", table_name = "finance_public_branch", transformation_ctx = "src_branch")
src_bank =  glueContext.create_dynamic_frame.from_catalog(database = "aurora", table_name = "finance_public_bank", transformation_ctx = "src_bank")


# Join the Bank and Branch
bank_branch = src_bank.join(paths1=["idBank"], paths2=["Bank_idBank"], frame2=src_branch)
# Join the bank_branch to Clients
bank_client = src_client.join(paths1=["Branch_idBranch"], paths2=["idBranch"], frame2=bank_branch)
# Join the bank_branch_clients to Account
bank_account = src_account.join(paths1=["Client_idClient"], paths2=["idClient"], frame2=bank_client)

# Get the final DynamicFrame and use ApplyMapping to eliminate unnecessary columns
bank_loans= src_loan.join(paths1=["Account_idAccount"], paths2=["idAccount"], frame2=bank_account)
fn_bank_loans = bank_loans.apply_mapping(
    [
        ("Name", "String", "BankName", "String"),
        ("idBranch", "long", "idBranch", "long"),
        ("Amount", "Double", "Amount", "Double"),
        ("loan_date", "Date", "loan_date", "Date"),
    ]
)
fn_bank_loans.printSchema()
fn_bank_loans.count()
# Calculate the moving average using spark sql
SqlQuery = """
select BankName, idBranch, year, month, 
         avg(amount) over (partition by BankName, idBranch order by year, month rows between 2 preceding and current row) rolling_average
from
(    select BankName, idBranch,            
             date_format(loan_date, "yyyy") year,
             date_format(loan_date, "MM") month,
             sum(amount) amount
     from myDataSource 
     group by BankName, idBranch,
             date_format(loan_date, "yyyy"),
             date_format(loan_date, "MM")
)
"""
fn_bank_loans.toDF().createOrReplaceTempView('myDataSource')
results = spark.sql(SqlQuery)
#results.count()
#results.printSchema()
## Write Spark Dataframe results to S3
results.count()
results.write.format('csv') \
             .mode("append") \
             .partitionBy("BankName", "year", "month") \
             .save(path="s3://aws-edokemwa-csv/test-data/")

# Loop through dest to merge and rename file
bucket = 'aws-edokemwa-csv'
for row in results.select("BankName", "year", "month").distinct().collect():
    path_to_concat = 'test-data/BankName='+row['BankName']+'/year='+row['year']+'/month='+row['month']+'/'
    concatenated_file = path_to_concat+row['BankName']+'_'+row['year']+row['month']+'01.csv'
    min_file_size = None
    # Init the concat_job
    concat_job = S3Concat(bucket, concatenated_file, min_file_size, content_type='application/csv')
    concat_job.add_files(path_to_concat)
    concat_job.concat(small_parts_threads=4)
job.commit()