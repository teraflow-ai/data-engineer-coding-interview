"""Bank Data Load Script

Read tables from bank database and writes as parquet files into s3 bucket
"""

import sys

from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext

args = getResolvedOptions(
    sys.argv,
    [
        "JOB_NAME",
        "CATALOG_DATABASE",
        "CATALOG_TABLE",
        "TARGET_BUCKET",
    ],
)

CATALOG_DATABASE = args["CATALOG_DATABASE"]
CATALOG_TABLE = args["CATALOG_TABLE"]
TARGET_BUCKET = args["TARGET_BUCKET"]

sc = SparkContext.getOrCreate()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
logger = glueContext.get_logger()

job = Job(glueContext)
job.init(args["JOB_NAME"], args)

dyf = glueContext.create_dynamic_frame.from_catalog(
    name_space=CATALOG_DATABASE, table_name=CATALOG_TABLE
)

sink = glueContext.write_dynamic_frame.from_options(
    frame=dyf,
    connection_type="s3",
    connection_options={
        "path": f"s3://{TARGET_BUCKET}/{CATALOG_DATABASE}/{CATALOG_TABLE}"
    },
    format="parquet",
)

job.commit()
