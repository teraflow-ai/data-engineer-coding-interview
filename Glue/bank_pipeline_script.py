##
#################################################################
# Author      : Marli van der Merwe
# Created     : 23 June 2023
# Steps:
# 1. Get the table names from the Aurora database using the Glue catalog API.
# 2. For each table name:
#     a. Read data from the Aurora table.
#     b. Convert the data to a Spark DataFrame.
#     c. Write the DataFrame to the corresponding S3 bucket.
# 3. Repeat the process for all table names.

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
import sys
import boto3
from datetime import datetime
import pandas as pd
import logging
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.context import SparkContext
from pyspark.sql.session import SparkSession
from pyspark.sql.functions import *
import argparse
import aeutils


## @params: [JOB_NAME]
args = getResolvedOptions(sys.argv, ['JOB_NAME'])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
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
        ],
)

# ---------------------------------------------------------------------------------------------#
### GLOBAL VARIABLES -- CONFIG VARIABLES FOR SOLUTION
# ---------------------------------------------------------------------------------------------#

DISCIPLINE = args["DISCIPLINE"]
S3_BUCKET = args["S3_BUCKET"]
USER = args["USER"]
PASSWORD = args["PASSWORD"]
JDBC_URL = args["JDBC_URL"]
CATALOG_DB_NAME = args["CATALOG_DB_NAME"]
SCHEMA = args["SCHEMA"]

# ---------------------------------------------------------------------------------------------#
### FUNCTIONS
# ---------------------------------------------------------------------------------------------#

def get_table_names(CATALOG_DB_NAME):
    
    """
    Retrieve the table names from the Glue catalog database.
    """
    
     # Retrieve the table names using the Glue catalog API
    response = glue_client.get_tables(
        DatabaseName=CATALOG_DB_NAME
    )
    
    # Extract the table names from the response
    table_names = [table['Name'] for table in response['TableList']]
    
    # Loop through the list of table names to extract individual table names
    for table_name in table_names:
        
        # Split the table name by (_)
        table_name_parts = table_name.split('_')  
        
        # Extract the last part of the split table name
        extracted_table_name = table_name_parts[-1]
        
        # Function call to process the current table in the for loop
        process_table(extracted_table_name)
        
    log.debug(f"EXTRACTED THE TABLE NAMES FROM GLUE CATALOG DATABASE NAME: {CATALOG_DB_NAME}")
    
def process_table(extracted_table_name):
    
    """
    Process the table by reading data from the PostgreSQL database and writing to S3.
    """
    
    # Create a DynamicFrame by reading data from the Aurora database
    connection_options = {
            "url": JDBC_URL,
            "dbtable": f"{SCHEMA}.{extracted_table_name}",
            "user": USER,
            "password": PASSWORD,
            "driver": "org.postgresql.Driver"
        }

    # Read data from the Aurora table
    dynamic_frame = glueContext.create_dynamic_frame.from_options(
        connection_type="postgresql",
        connection_options=connection_options
    )

    # Convert the DynamicFrame to Spark DataFrame
    dataframe = dynamic_frame.toDF()

    
    output_path = f"{S3_BUCKET}{extracted_table_name}"
    
    # Write the DataFrame to S3 with partitioning (Overwrite mode)
    dataframe.write.mode("overwrite").parquet(output_path)
    
    log.debug(f"READ THE DATA FROM AURORA CLUSTER TABLE: {extracted_table_name} AND WROTE DATA TO S3 BUCKET: {output_path}")

# 
# ---------------------------------------------------------------------------------------------#
### MAIN
# ---------------------------------------------------------------------------------------------#    
if __name__ == "__main__":
    
    
    log = aeutils.create_logger()
    log.info("Job started")
    job_start_time = datetime.now()
    
    try:

        get_table_names(CATALOG_DB_NAME)
        log.info(
            f"Job completed. Run Time: {aeutils.get_elapsed_time(job_start_time, datetime.now())}"
        )
    
    except:
        
        msg = f"An error occured while running. Please review logs."

        log.critical(
            f"Job failed. Run Time: {aeutils.get_elapsed_time(job_start_time, datetime.now())}"
        )