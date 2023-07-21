import sys
from datetime import datetime, timedelta
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from awsglue.context import GlueContext
from awsglue.utils import getResolvedOptions
import boto3

args = getResolvedOptions(sys.argv, ['BlahBlahJob', 'file_dump'])

# Initialize the Spark session and GlueContext
spark = SparkSession.builder \
    .appName(args['BlahBlahJob']) \
    .getOrCreate()
glueContext = GlueContext(spark)

# Input data: Change this to the appropriate JDBC URL for your AWS Aurora PostgreSQL
jdbc_url = "jdbc:postgresql://mycluster.cluster-123456789012.us-east-1.rds.amazonaws.com"
properties = {
    "user": "postgres",
    "password": "5Y67bg#r#",
    "driver": "org.postgresql.Driver"
}

# Output S3 bucket for the processed data
output_bucket = args['file_dump']

# Get the current date
current_date = datetime.now()

# Calculate the start and end dates for the three-month period
end_date = current_date.replace(day=1)  # Move to the first day of the current month
end_date -= timedelta(days=1)  # Move back one day to the last day of the previous month
start_date = end_date.replace(day=1)  # Move to the first day of the month, three months ago
start_date -= timedelta(days=1)  # Move back one day to cover the full three-month period

# Convert dates to string format (YYYYMMDD) for partitioning
start_date_str = start_date.strftime("%Y%m%d")
end_date_str = end_date.strftime("%Y%m%d")

# Read the input data from AWS Aurora PostgreSQL tables using Spark JDBC
account_df = spark.read.jdbc(jdbc_url, "account", properties=properties)
loan_df = spark.read.jdbc(jdbc_url, "loan", properties=properties)
client_df = spark.read.jdbc(jdbc_url, "client", properties=properties)
branch_df = spark.read.jdbc(jdbc_url, "branch", properties=properties)
bank_df = spark.read.jdbc(jdbc_url, "bank", properties=properties)

# Calculate the moving average of loan amounts per branch
moving_avg_df = loan_df.join(account_df, loan_df.account_idAccount == account_df.idAccount) \
    .join(client_df, account_df.client_idClient == client_df.idClient) \
    .join(branch_df, client_df.branch_idBranch == branch_df.idBranch) \
    .join(bank_df, branch_df.bank_idBank == bank_df.idBank) \
    .filter(
        (F.col("loan_date") >= start_date_str) & (F.col("loan_date") <= end_date_str)
    ) \
    .groupBy("bank.name", "branch.idBranch") \
    .agg(
        F.avg("amount").alias("moving_avg_loan_amount")
    )

# Prepare the output filename format (BankName_YYYYMMDD.csv)
output_filename = "{}_{}.csv".format(moving_avg_df.select("name").first()["name"], current_date.strftime("%Y%m%d"))

# Partition the data by Bank Name, Year, and Month
output_df = moving_avg_df.withColumn("year", F.year(F.current_date())) \
    .withColumn("month", F.month(F.current_date()))

# Save DataFrame to a CSV file in the specified output location
output_df.coalesce(1).write \
    .format("csv") \
    .option("header", "true") \
    .mode("overwrite") \
    .save(f"s3://{output_bucket}/{output_filename}")

# Stop the Spark session
spark.stop()

# Notify the Glue job that the ETL is complete
client = boto3.client("glue")
client.put_job_run_result(
    JobRunId=args["JOB_RUN_ID"],
    JobName=args["JOB_NAME"],
    RunState="SUCCEEDED",
    Message="ETL job completed successfully."
)