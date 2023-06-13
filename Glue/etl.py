import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from pyspark.sql import functions as F
from pyspark.sql.window import Window
from datetime import datetime
from awsglue import Job
  
sc = SparkContext.getOrCreate()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)

'''
Nathan Brown
'''

# Get the Glue logger
logger = glueContext.get_logger()

# Create dynamic frame from the source tables
bank_dyf = glueContext.create_dynamic_frame.from_catalog(
    database="bank_loan_data_db", table_name="postgres_public_tbl_bank"
)
branch_dyf = glueContext.create_dynamic_frame.from_catalog(
    database="bank_loan_data_db", table_name="postgres_public_tbl_branch"
)
client_dyf = glueContext.create_dynamic_frame.from_catalog(
    database="bank_loan_data_db", table_name="postgres_public_tbl_client"
)
account_dyf = glueContext.create_dynamic_frame.from_catalog(
    database="bank_loan_data_db", table_name="postgres_public_tbl_account"
)
loan_dyf = glueContext.create_dynamic_frame.from_catalog(
    database="bank_loan_data_db", table_name="postgres_public_tbl_loans"
)

# Convert dynamic frames to a data frame
bank_df = bank_dyf.toDF()
branch_df = branch_dyf.toDF()
client_df = client_dyf.toDF()
account_df = account_dyf.toDF()
loan_df = loan_dyf.toDF()

# Smash everything into a huge dataframe and start business logic:
loan_data_matrix = (
    branch_df.join(bank_df, branch_df["bank_id_bank"] == bank_df["id_bank"])
    .join(client_df, client_df["branch_id_branch"] == branch_df["id_branch"])
    .join(account_df, account_df["client_client_id"] == client_df["id_client"])
    .join(loan_df, loan_df["account_id_account"] == account_df["id_account"])
    .select(bank_df["name"].alias("Bank Name"), branch_df["address"].alias("Branch Name"), loan_df["amount"].alias("Loan Amount"), loan_df["loan_date"].alias("Loan Date"))
)

# Calculate the moving average per branch over the last three months
window_spec = (
    Window.partitionBy(loan_data_matrix["Branch Name"]).orderBy(loan_data_matrix["Loan Date"]).rowsBetween(-2, 0)
)

moving_average_df = loan_data_matrix.withColumn("Moving Average", F.avg(F.col("Loan Amount")).over(window_spec))

# Extract data from dataframe for output: 
moving_average_df = moving_average_df.withColumn("Year", F.date_format(F.col("Loan Date"), "yyyy"))
moving_average_df = moving_average_df.withColumn("Month", F.date_format(F.col("Loan Date"), "MM"))

# Set S3 location and write out DataFrame to S3
output_path_s3 = 's3://dev-test-bank-loan-data-output/bank_loan_data/'
moving_average_df.write.partitionBy("Bank Name", "Year", "Month").csv(output_path_s3, mode="overwrite", header=True)

# Commit the job
job.commit()
