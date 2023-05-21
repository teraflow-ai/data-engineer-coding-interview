import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, avg, date_format
from pyspark.sql.window import Window
from awsglue.context import GlueContext
from pyspark.sql.functions import concat
from pyspark.sql.functions import lit


# Create Spark and Glue contexts
sc = SparkContext()
spark = SparkSession.builder.getOrCreate()
glueContext = GlueContext(sparkContext=sc, sparkSession=spark)

# Extract data from tables using Glue catalog
branch = glueContext.create_dynamic_frame.from_catalog(database="coding_interview_glue_database", table_name="mydatabase_public_branch")
bank = glueContext.create_dynamic_frame.from_catalog(database="coding_interview_glue_database", table_name="mydatabase_public_bank")
loans = glueContext.create_dynamic_frame.from_catalog(database="coding_interview_glue_database", table_name="mydatabase_public_loans")
client = glueContext.create_dynamic_frame.from_catalog(database="coding_interview_glue_database", table_name="mydatabase_public_client")
account = glueContext.create_dynamic_frame.from_catalog(database="coding_interview_glue_database", table_name="mydatabase_public_account")

# Convert DynamicFrames to DataFrames
branch_df = branch.toDF()
bank_df = bank.toDF()
loans_df = loans.toDF()
client_df = client.toDF()
account_df = account.toDF()

# Join tables
joined_df = branch_df.join(bank_df, branch_df["idbank_bank"] == bank_df["idbank"]) \
                    .join(client_df, client_df["idbranch_branch"] == branch_df["idbranch"]) \
                    .join(account_df, (account_df["idclient_client"] == client_df["idclient"]))  \
                    .join(loans_df, loans_df["idaccount_account"] == account_df["idaccount"]) \
                    .select(bank_df["name"].alias("bank_name"),loans_df["amount"],loans_df["loan_data"])
                    
# Calculate moving average of loan amounts per branch over the last three months
window_spec = Window.partitionBy(joined_df["bank_name"]).orderBy(joined_df["loan_data"].desc()).rowsBetween(-2, 0)
loan_avg_df = joined_df.withColumn("moving_avg", avg(col("amount")).over(window_spec))

# Extract Bank Name, Year, and Month from the loan_date column
loan_avg_df = loan_avg_df.withColumn("year_month", date_format(col("loan_data"), "yyyyMM"))

# Write separate monthly output files partitioned by Bank Name, Year, and Month
output_path = "s3://coding-interview-bucket-riaan-annandale/output-folder/"
loan_avg_df.withColumn("file_name", concat(loan_avg_df["bank_name"], lit("_"), loan_avg_df["year_month"], lit(".csv"))) \
           .write.partitionBy("bank_name", "year_month") \
           .mode("append") \
           .csv(output_path, header=True)
