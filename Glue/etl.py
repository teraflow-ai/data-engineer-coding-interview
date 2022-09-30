#########################################
### IMPORT LIBRARIES AND SET VARIABLES
#########################################

#Import python modules
from datetime import datetime

#Import pyspark modules
from pyspark.context import SparkContext
import pyspark.sql.functions as f

#Import glue modules
from awsglue.utils import getResolvedOptions
from awsglue.context import GlueContext
from awsglue.dynamicframe import DynamicFrame
from awsglue.job import Job

#Initialize contexts and session
spark_context = SparkContext.getOrCreate()
glue_context = GlueContext(spark_context)
session = glue_context.spark_session

#Parameters
glue_db = "glue-blog-tutorial-db"
glue_tbl = "read"
s3_write_path = "s3://aws_s3_bucket.glue_job.bucket/write"

#########################################
### EXTRACT (READ DATA)
#########################################

#Log starting time
dt_start = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
print("Start time:", dt_start)

#Read movie data to Glue dynamic frame
dynamic_frame_read = glueContext.create_dynamic_frame_from_options(
    connection_type="s3", format="csv",
    connection_options={"paths": ["s3://aws_s3_bucket.glue_job.bucket/data.csv"], "recurse": True})

#Convert dynamic frame to data frame to use standard pyspark functions
data_frame = dynamic_frame_read.toDF()

#########################################
### TRANSFORM (MODIFY DATA)
#########################################

#Selecting the columns bank_name, loan_date, amount

#Moving average function

#

#########################################
### LOAD (WRITE DATA)
#########################################

#Create just partitions for the banks
data_frame_aggregated = data_frame_aggregated.repartition()

#Convert back to dynamic frame
dynamic_frame_write = DynamicFrame.fromDF(data_frame_aggregated, glue_context, "dynamic_frame_write")

#Write data back to S3
glue_context.write_dynamic_frame.from_options(
    frame = dynamic_frame_write,
    connection_type = "s3",
    connection_options = {
        "path": s3_write_path/{bank_name}_{date}.csv,
        "partitionKeys": ["bank_name"]
    },
    format = "csv"
)

#Log end time
dt_end = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
print("Start time:", dt_end)
