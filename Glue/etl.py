import sys
from aws_cdk.awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.functions import *
from pyspark.sql import Row, Window
from datetime import date


## @params: [JOB_NAME]
args = getResolvedOptions(sys.argv, ['JOB_NAME', 'S3_PATH', 'GLUE_DB', 'GLUE_HIST_TBL', 'GLUE_AVG_TBL'])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)
current_month = date.today().strftime("%m")
s3_base_path = args['S3_BASE_PATH']
glue_db = args['GLUE_DB']
glue_hist_tbl = args['GLUE_HIST_TBL']
glue_avg_tbl = args['GLUE_AVG_TBL']

# get current month
current_month = today.strftime("%m")

# existing branch montly loan totals
existing_totals = glueContext.create_dynamic_frame.from_catalog(database=glue_db, table_name=glue_hist_tbl)

## filter source data and project cols required
SQL = """
SELECT l.*, c.Branch_idBranch
FROM loans l, client c, account a
WHERE l.Account_idAccount = a.idAccount AND a.Client_idClient = c.idClient
"""

# calculate the current months totals
new_totals = spark.sql(SQL)\
    .withColumn("loan_month", date_format(col("loan_date"), "MM"))\
    .filter(col("loan_month") == current_month)\
    .groupBy("Branch_idBranch", "loan_month")\
    .agg(sum("Amount").alias("loan_total"))


# union the existing and new totals to form one dataset
all_totals = existing_totals.union(new_totals)

# calculate the 3 month moving average
windowSpec = Window.partitionBy("loan_month").orderBy("Branch_idBranch")

three_mnth_mv_avg = all_totals \
    .withColumn("dense_rank", rank().over(windowSpec)) \
    .orderBy("loan_month", "Branch_idBranch") \
    .withColumn("tmp", avg("loan_total").over(Window.partitionBy("Branch_idBranch").rowsBetween(-2, 0))) \
    .withColumn("moving avg", sum("tmp").over(Window.partitionBy("Branch_idBranch").rowsBetween(0, 1)) - col("tmp")) \
    .drop("tmp", "dense_rank")


# persist the new totals to history table
new_totals_sink = glueContext.getSink(
    connection_type="s3",
    path=f"{s3_base_path}/{glue_hist_tbl}/",
    enableUpdateCatalog=True,
    partitionKeys=["processed_date"])
new_totals_sink.setFormat("parquet")
new_totals_sink.setCatalogInfo(catalogDatabase=glue_db, catalogTableName=glue_hist_tbl)
new_totals_sink.writeFrame(new_totals)


# persist new thre month average calculation to average table
three_mnth_mv_avg_sink = glueContext.getSink(
    connection_type="s3",
    path=f"{s3_base_path}/{glue_avg_tbl}/",
    enableUpdateCatalog=True,
    partitionKeys=["processed_date"])
three_mnth_mv_avg_sink.setFormat("parquet")
three_mnth_mv_avg_sink.setCatalogInfo(catalogDatabase=glue_db, catalogTableName=glue_avg_tbl)
three_mnth_mv_avg_sink.writeFrame(three_mnth_mv_avg)

job.commit()