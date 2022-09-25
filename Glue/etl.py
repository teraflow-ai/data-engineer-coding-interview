"""Bank Data ETL Pipeline

Glue ETL script containing scalable business logic to calculate the
moving average of loan amounts taken out over the last three months, per branch.

* Creates a separate monthly output file for each bank in the group.
* Files are partitioned by Bank Name, Year and Month.
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
TARGET_BUCKET = args["TARGET_BUCKET"]

sc = SparkContext.getOrCreate()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
logger = glueContext.get_logger()

job = Job(glueContext)
job.init(args["JOB_NAME"], args)

# add each table that we are going to use to spark schema
# if glue actually worked for me, perhaps
# `glueContext.get_catalog_schema_as_spark_schema`
# would have been much more efficient.

# the database is already introspected by glue, so i realise
# that there is no need to manually specify table names again

for dbtable in ["Loans", "Account", "Client", "Branch", "Bank"]:
    dyf = glueContext.create_dynamic_frame.from_catalog(
        name_space=CATALOG_DATABASE, table_name=dbtable
    )
    df = dyf.toDF()
    df.createOrReplaceTempView(str.lower(dbtable))

rolling_avg_df = spark.sql(
    """
    WITH daily_totals_per_branch AS
      (SELECT bank.Name AS bank_name,
              branch.idBranch AS branch_id,
              loans.loan_date AS loan_date,
              sum(loans.Amount) AS daily_total_loan_amount
       FROM loans
       JOIN account ON loans.Account_idAccount = account.idAccount
       JOIN client ON account.Client_idClient = client.idClient
       JOIN branch ON client.Branch_idBranch = branch.idBranch
       JOIN bank ON bank.idBank = branch.Bank_idBank
       GROUP BY bank_name,
                branch_id,
                loan_date)
    SELECT bank_name,
           branch_id,
           loan_date,
           EXTRACT(YEAR
                   FROM loan_date) || "-" || EXTRACT(MONTH
                                                     FROM loan_date) AS loan_year_month,
           avg(daily_total_loan_amount) OVER (PARTITION BY branch_id
                                              ORDER BY loan_date ROWS BETWEEN 90 preceding AND CURRENT ROW)
                                               AS rolling_three_month_avg
    FROM daily_totals_per_branch;
    """
)

# partition by required fields
rolling_avg_partitioned_df = rolling_avg_df.repartition("bank_name", "loan_year_month")

# write to s3 bucket
# (please see https://stackoverflow.com/questions/71344340/pyspark-write-a-dataframe-to-csv-files-in-s3-with-a-custom-name)
# can't use pyspark alone to rename these files according to specification, name isn't determinable.
rolling_avg_partitioned_df.write.partitionBy("bank_name", "loan_year_month").csv(
    f"s3a://{TARGET_BUCKET}/bankloans/", header=True, mode="overwrite"
)

job.commit()
