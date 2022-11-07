import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.dynamicframe import DynamicFrame
from awsglue.job import Job
import  pyspark.sql.functions as F
from pyspark.sql.window import Window
from datetime import datetime


def get_table(table_name):
    return spark.read.format("jdbc").option(
        "url",
        "jdbc:postgresql://mycluster.cluster-123456789012.us-east-1.rds.amazonaws.com:5432/bankdb"
        ).option(
            "dbtable",
            table_name
        ).option(
            "driver",
            "org.postgresql.Driver"
        ).option(
            "user",
            "postgres"
        ).option(
            "password",
            "5Y67bg#r#"
        ).load()

def get_tables(tables = ['Worker','Bank','Branch','Client','Loans','Account']):
    df_dict = {}
    for table in table_names:
        df_dict[table] =  glueContext.create_dynamic_frame.from_catalog(
                 database="bankdb",
                 table_name=table
                 )# Read Data from Salesforce using DataDirect JDBC driver in to DataFram
    return df_dict

days = lambda i: i * 86400
args = getResolvedOptions(sys.argv, ['JOB_NAME'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)
df_dict = get_tables()
df_bank_branch_loan = df_dict['Branch']\
                    .select(F.col('idBranch'),F.col('Bank_idBank'))\
                    .withColumnRenamed('Bank_idBank','idBank')\
                    .join(
                        df_dict['Bank'].select(F.col('Name'),F.col('idBank')),
                        ['idBank'],
                        'left'
                    )\
                    .join(
                        df_dict['Client'].select(F.col('idClient'),F.col('Branch_idBranch'))\
                                .withColumnRenamed('Branch_idBranch','idBranch'),
                        ['idBranch'],
                        'right'
                    )\
                    .join(
                        df_dict['Account'].select(F.col('idAccount'),F.col('Client_idClient'))\
                                .withColumnRenamed('Client_idClient','idClient'),
                        ['idClient'],
                        'left'
                    )\
                    .join(
                        df_dict['Loans'].filter(
                            F.months_between(F.current_date(),F.col('loan_date')
                        ) <=3)\
                        .withColumnRenamed('Account_idAccount','idAccount'),
                        ['idAccount'],
                        'right'
                    )\
                    .groupBy(
                        F.col('Name'),F.year('loan_date').alias('Year'),F.month('loan_date').alias('Month')
                    )\
                    .agg(
                        F.avg('Amount').alias('avg_month')
                    )\
                    .withColumn(
                         "timestamp", 
                         F.concat(F.col("Month"), F.lit("/"), F.lit("1"), F.lit("/"), F.col("Year")).cast('timestamp')
                    )
w = (Window().partitionBy(F.col("Name")).orderBy(F.col("timestamp").cast('long')).rangeBetween(-days(90), 0))
df = df_bank_branch_loan.withColumn('rolling_average_3_months',F.avg('avg_month').over(w))
today = datetime.now()
for bank in df.select('Name').distinct().collect().toPandas().column.to_list():
    source_df = df.filter(F.col('Name') == bank).orderBy('timestamp')
    source_df.coalesce(1).write.option("header",True).partitionBy("bank_name", "loan_year", "loan_month").mode("overwrite").csv(s3_location)
    #dynamic_dframe = DynamicFrame.fromDF(source_df, glueContext, "dynamic_df")
    #datasink4 = glueContext.write_dynamic_frame.from_options(frame = dynamic_dframe, connection_type = "s3", connection_options = {"path": f"s3://data/{bank}_{today.year}{today.month}{today.day}"}, format = "csv", transformation_ctx = "datasink4")
job.commit()

