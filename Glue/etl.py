import sys
from datetime import datetime
from dateutil.relativedelta import relativedelta
import pyspark.sql.functions as F
from awsglue.context import GlueContext
from pyspark.context import SparkContext
from pyspark.sql import SparkSession
from awsglue.dynamicframe import DynamicFrame

# PySpark Setup and Cloud Watch logger setup
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
logger = glueContext.get_logger()

try:
    # Dynamic Frames for tables we are interested in
    bank_dyf = glueContext.create_dynamic_frame.from_catalog(database="banking_group_database", table_name="bank")
    branch_dyf = glueContext.create_dynamic_frame.from_catalog(database="banking_group_database", table_name="branch")
    client_dyf = glueContext.create_dynamic_frame.from_catalog(database="banking_group_database", table_name="client")
    account_dyf = glueContext.create_dynamic_frame.from_catalog(database="banking_group_database", table_name="account")
    loan_dyf = glueContext.create_dynamic_frame.from_catalog(database="banking_group_database", table_name="loans")

    # Convert dynamic frames to dataframes
    bank_df = bank_dyf.toDF()
    branch_df = branch_dyf.toDF()
    client_df = client_dyf.toDF()
    account_df = account_dyf.toDF()
    loan_df = loan_dyf.toDF()

    # Get unique bank names, removing space to keep to standards
    bank_names = [row[0].replace(" ", "") for row in bank_df.select('name').distinct().collect()]

    #Set the three months ago variable
    three_months_ago = datetime.now() - relativedelta(months=3)

    # Loop through banks, selecting specific bank by pyspark filter
    for bank_name in bank_names:
        joined_df = (
            bank_df
            .join(branch_df, bank_df['idbank'] == branch_df['bank_idbank'])
            .join(client_df, branch_df['idbranch'] == client_df['branch_idbranch'])
            .join(account_df, client_df['idclient'] == account_df['client_idclient'])
            .join(loan_df, account_df['idaccount'] == loan_df['account_idaccount'])
            .filter(F.col('name').replace(" ", "") == bank_name)
        )

        # Select loans taken within the last three months
        filtered_df = joined_df.filter(joined_df['loan_date'] >= three_months_ago)

        # Calculate moving average of loan amounts per branch
        avg_loan_per_branch = filtered_df.groupBy('branch_idbranch').agg(F.avg('Amount').alias('avg_loan_amount'))

        #Filename output setting to specs
        current_date = datetime.now().strftime("%Y%m%d")
        file_name = f"{bank_name}_{current_date}.csv"

        # Convert DataFrame to dynamic frame
        loan_avg_dyf = DynamicFrame.fromDF(avg_loan_per_branch, glueContext, "loan_avg_dyf")

        # Write the dynamic frame as a CSV file with the generated file name, will pass in s3 buccket from created resource
        output_path = f"s3://s3_bucket/{file_name}"
        glueContext.write_dynamic_frame.from_options(
            frame=loan_avg_dyf,
            connection_type="s3",
            connection_options={"path": output_path},
            format="csv",
            transformation_ctx="output"
        )

except Exception as e:
    logger.error(e)
