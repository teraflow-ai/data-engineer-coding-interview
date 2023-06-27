##
#################################################################
# Author      : Marli van der Merwe
# Created     : 23 June 2023
# Steps:
# The code initializes the Spark session and sets up logging.
# Temporary views are created for different tables using JDBC options.
# A SQL query is executed to retrieve distinct bank names, and the results are stored in a DataFrame.
# The code defines a function called calculate_moving_average that takes a row as input.
# For each row in the DataFrame, the code extracts the bank name and executes a SQL query using Spark to calculate the moving average for the specified bank.
# The query results are converted to a Pandas DataFrame.
# A file name is generated based on the bank name, year, and month.
# The DataFrame is written to a CSV file in an S3 bucket partitioned by year and month.

# Note: The script assumes that the necessary configurations, such as the Aurora connection details, S3 bucket, and Glue catalog database, are provided as command-line arguments.

##
##

# -------------------------------------------------------------
# Ammended by :
# Date        :
# Reason      :
#################################################################




#---------------------------------------------------------------------------------------------#
### PACKAGE IMPORTS
#---------------------------------------------------------------------------------------------#
import os
import sys
import boto3
from botocore.exceptions import ClientError
from datetime import datetime, timedelta
import pandas as pd
import logging
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.context import SparkContext
from pyspark.sql.session import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.window import Window
import argparse
import aeutils





## @params: [JOB_NAME]
args = getResolvedOptions(sys.argv, ['JOB_NAME'])

sc = SparkContext()
glueContext = GlueContext(sc)

job = Job(glueContext)
job.init(args['JOB_NAME'], args)
glue_client = boto3.client('glue')
job.commit()

args = getResolvedOptions(
        sys.argv,
        [
            "JOB_NAME",
            "DISCIPLINE",
            "S3_BUCKET",
            "USER",
            "PASSWORD",
            "JDBC_URL",
            "CATALOG_DB_NAME",
            "SCHEMA",
            "BUCKET_NAME",
            "DIRECTORY",
        ],
)

# ---------------------------------------------------------------------------------------------#
### GLOBAL VARIABLES -- CONFIG VARIABLES FOR SOLUTION
# ---------------------------------------------------------------------------------------------#

JOB_NAME = args["JOB_NAME"]
DISCIPLINE = args["DISCIPLINE"]
S3_BUCKET = args["S3_BUCKET"]
USER = args["USER"]
PASSWORD = args["PASSWORD"]
JDBC_URL = args["JDBC_URL"]
CATALOG_DB_NAME = args["CATALOG_DB_NAME"]
SCHEMA = args["SCHEMA"]
BUCKET_NAME = args["BUCKET_NAME"]
DIRECTORY = args["DIRECTORY"]


# ---------------------------------------------------------------------------------------------#
### FUNCTIONS
# ---------------------------------------------------------------------------------------------#

def calculate_moving_average(row):
    
    bank = row['name']
    
    moving_average_df = spark.sql(f"""
          SELECT
              b.idBranch,
              bn.Name AS BankName,
              EXTRACT(YEAR FROM l.loan_date) AS LoanYear,
              EXTRACT(MONTH FROM l.loan_date) AS LoanMonth,
              AVG(l.Amount) OVER (PARTITION BY b.idBranch ORDER BY l.loan_date) AS MovingAverage
            FROM
              branch_view b
            JOIN
              client_view c ON c.Branch_idBranch = b.idBranch
            JOIN
              account_view a ON a.Client_idClient = c.idClient
            JOIN
              loans_view l ON l.Account_idAccount = a.idAccount
            JOIN
              bank_view bn ON bn.idBank = b.Bank_idBank
            WHERE
              l.loan_date >= (CURRENT_DATE - INTERVAL '3 months') AND
              bn.Name = '{bank}'
            ORDER BY
              b.idBranch,
              l.loan_date
    """)
    
    print("print")
    moving_average_df.show()
    df = moving_average_df.toPandas()
    
      # Generate a timestamp for the file name
    timestamp = datetime.now().strftime("%Y-%m-%d-%H-%M-%S")
    year = timestamp.split('-')[0]  # Extract year
    month = timestamp.split('-')[1]  # Extract month
    
    # Generate the file name with the desired naming convention
    file_name = f"{bank}_{year}_{month}.csv"

    # Write CSV to S3 bucket
    s3 = boto3.resource('s3')
    bucket_name = BUCKET_NAME
    
    # Create directories for year and month
    year_directory = f"marli_test/postgres_test/moving_ave/{year}/"
    month_directory = f"{DIRECTORY}{month}/"

    # Export DataFrame to CSV
    csv_buffer = df.to_csv(index=False)
    
    object_key = f"{month_directory}{file_name}" 
    
    s3.Object(bucket_name, object_key).put(Body=csv_buffer)
    
    log.debug(f"Processed CSV file: {file_name}")
    
# 
# ---------------------------------------------------------------------------------------------#
### MAIN
# ---------------------------------------------------------------------------------------------#    
if __name__ == "__main__":
    
    spark = glueContext.spark_session
    log = aeutils.create_logger()
    log.info("Job started")
    job_start_time = datetime.now()
    
    try:
        
        # spark.sql(f"CREATE OR REPLACE TEMPORARY VIEW bank_view USING jdbc OPTIONS (url '{JDBC_URL}', dbtable '{SCHEMA}.bank', user '{USER}', password '{PASSWORD}')")
        spark.sql(f"CREATE OR REPLACE TEMPORARY VIEW branch_view USING jdbc OPTIONS (url '{JDBC_URL}', dbtable '{SCHEMA}.branch', user '{USER}', password '{PASSWORD}')")
        spark.sql(f"CREATE OR REPLACE TEMPORARY VIEW client_view USING jdbc OPTIONS (url '{JDBC_URL}', dbtable '{SCHEMA}.client', user '{USER}', password '{PASSWORD}')")
        spark.sql(f"CREATE OR REPLACE TEMPORARY VIEW account_view USING jdbc OPTIONS (url '{JDBC_URL}', dbtable '{SCHEMA}.account', user '{USER}', password '{PASSWORD}')")
        spark.sql(f"CREATE OR REPLACE TEMPORARY VIEW loans_view USING jdbc OPTIONS (url '{JDBC_URL}', dbtable '{SCHEMA}.loans', user '{USER}', password '{PASSWORD}')")
        
        log.debug(f"Created temporary views")
        
        # Query to retrieve distinct bank names
        bank_names_query = "SELECT DISTINCT(b.name) FROM bank_view b JOIN branch_view br ON b.idBank = br.Bank_idBank JOIN client_view c ON c.Branch_idBranch = br.idBranch JOIN account_view a ON a.Client_idClient = c.idClient JOIN loans_view l ON l.Account_idAccount = a.idAccount WHERE l.loan_date >= CURRENT_DATE - INTERVAL '3 months' AND l.loan_date <= CURRENT_DATE - INTERVAL '1 day'"
        
        # Execute the query and retrieve the result as DataFrame
            bank_names_df = spark.sql(bank_names_query)
        
        #Collect the rows from the DataFrame as a list
        bank_rows = bank_names_df.collect()
        
        # Iterate over each row and invoke the calculate_moving_average function
        # for row in bank_rows:
        #     calculate_moving_average(row)
        #     log.debug(f"Processed {row}")
        
        
        log.info(
            f"Job completed. Run Time: {aeutils.get_elapsed_time(job_start_time, datetime.now())}")
        
    
    except:

        log.critical(
            f"Job failed. Run Time: {aeutils.get_elapsed_time(job_start_time, datetime.now())}"
         )
