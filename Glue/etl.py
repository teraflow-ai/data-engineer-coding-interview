import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue import DynamicFrame
from datetime import datetime

##################
# Setup      #
##################

# Define spark configuration for job to execute correctly

## @params: [JOB_NAME]
args = getResolvedOptions(sys.argv, ['JOB_NAME'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)


# Standard function used by Glue Studio to perform a generic SQL query on a DynamicFrame
# Requires transformation to a DataFrame and back
def sparkSqlQuery(glueContext, query, mapping, transformation_ctx) -> DynamicFrame:
    for alias, frame in mapping.items():
        frame.toDF().createOrReplaceTempView(alias)
    result = spark.sql(query)
    return DynamicFrame.fromDF(result, glueContext, transformation_ctx)


##################
# Load Data      #
##################
# Load catalog tables into Glue DynamicFrames for processing

# Load Bank table
aurora_bank = glueContext.create_dynamic_frame.from_catalog(
    database            = "big_bank_aurora_ods",
    table_name          = "Bank",
    transformation_ctx  = "aurora_bank",
)

#Load Branch table
aurora_branch = glueContext.create_dynamic_frame.from_catalog(
    database            = "big_bank_aurora_ods",
    table_name          = "Branch",
    transformation_ctx  = "aurora_branch",
)

#Load Client table
aurora_client = glueContext.create_dynamic_frame.from_catalog(
    database            = "big_bank_aurora_ods",
    table_name          = "Client",
    transformation_ctx  = "aurora_client",
)

#Load Account table
aurora_account = glueContext.create_dynamic_frame.from_catalog(
    database            = "big_bank_aurora_ods",
    table_name          = "Account",
    transformation_ctx  = "aurora_account",
)

#Load Loans table
aurora_loans = glueContext.create_dynamic_frame.from_catalog(
    database            = "big_bank_aurora_ods",
    table_name          = "Loans",
    transformation_ctx  = "aurora_loans",
)

##################
# Query Data     #
##################
# Join and aggregate loan data to output a total monthly loan value per bank, per branch
# Only data for the last three months is included, with the behaviour defined to include all months in entirety (not partial months) 
# Can result in up to 4 months of data being outputted

# End date set to run date by default, but can be configured for historical execution
end_date = 'current_date()'

monthly_average_bank_loan_query = """
SELECT
     Bank.Name
    ,Bank.idBank
    ,Branch.idBranch
    ,YEAR(CAST(Loans.loan_date AS date)) AS loan_year
    ,MONTH(CAST(Loans.loan_date AS date)) AS loan_month
    ,SUM(Loans.amount) AS total_monthly_loan_amount
FROM
    Bank 
LEFT JOIN  --Join down to loans level to get loan book per bank 
    Branch
ON
    Bank.idBank = Branch.Bank_idBank
LEFT JOIN 
    Client
ON
    Branch.idBranch = Client.Branch_idBranch
LEFT JOIN 
    Account
ON
    Client.idClient = Account.Client_idClient
LEFT JOIN 
    Loans
ON
    Account.idAccount = Loans.Account_idAccount

WHERE --Filter for the last 3 month of loans, as of the given end date
    
    -- Same year, 3 months ago or more recent
    (
    YEAR(CAST(Loans.loan_date AS date)) = YEAR(add_months(""" + end_date + """, -3))
    AND
    MONTH(CAST(Loans.loan_date AS date)) >= MONTH(add_months(""" + end_date + """, -3))
    )
    OR
    -- Current year, where 3 months back falls into the previous year
    YEAR(CAST(Loans.loan_date AS date)) > YEAR(add_months(""" + end_date + """, -3))

GROUP BY --Aggregate per bank ID and bank name (avoids assumption that each bank has a unique name)
     Bank.idBank
    ,Bank.Name
    ,Branch.idBranch
    ,YEAR(CAST(Loans.loan_date AS date))
    ,MONTH(CAST(Loans.loan_date AS date))
"""

monthly_average_bank_loan = sparkSqlQuery(
    glueContext,
    query=monthly_average_bank_loan_query,
    mapping={"Bank": aurora_bank
            ,"Branch": aurora_branch
            ,"Client": aurora_client
            ,"Account": aurora_account
            ,"Loans": aurora_loans},
    transformation_ctx="monthly_average_bank_loan",
)


########################
# Write Output Files   #
########################
# Write to S3, paritioning by bank name, year, and month
# The output files have combined into a single CSV for useability, though this may degrade performance on a very large dataset 
# The client has requested that the files be written into CSVs in a defined naming convention (BankName_YYYYMMDD.csv)
#     this cannot be easily achieved with native spark functionality, and would require iterating through an extracted list of bank names from the data (or hardcoding of bank names) along with a loop through the last 3/4 months 
#     this has not been implemented due to time constraints, and the file information must be infered from the partition structure
# The entire folder structure will be overwritten on each run, therefore not storing history (previous months will be overwritten if not included in current run)

s3_location = "s3://big_bank_aurora_analytics_dev/monthly_loan_average/"

current_month = datetime.today().replace(day=1)

for month in current_date


moving_average_bank_loan.toDF().coalesce(1).write.option("header",True).partitionBy("bank_name", "loan_year", "loan_month").mode("overwrite").csv(s3_location)


job.commit()