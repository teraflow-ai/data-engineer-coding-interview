
import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.dynamicframe import DynamicFrame
from awsglue.job import Job
from datetime import datetime
from pyspark.sql import SQLContext

args = getResolvedOptions(sys.argv, ['JOB_NAME'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)


def fetch_table(database_name,table_name ):
    df = glueContext.create_dynamic_frame.from_catalog(database = database_name,table_name = table_name)
    return df

loans   = fetch_table("bankdb","loans")
account = fetch_table("bankdb","account")
client  = fetch_table("bankdb","client")
branch  = fetch_table("bankdb","branch")
bank    = fetch_table("bankdb","bank")


loans_account = Join.apply(loans,account,'Account_idAccount', 'idAccount')

loans_account_client =  Join.apply(loans_account, client, 'Client_idClient', 'idClient')

loans_account_client_branch = Join.apply(loans_account_client, client, 'Branch_idBranch', 'idBranch')

loans_account_client_branch_bank = Join.apply(loans_account_client_branch, bank, 'Bank_idBank', 'idBank')

df = loans_account_client_branch_bank.toDF()

##### Assuming that all the tables are merged and joined and we already  
df.registerTempTable('table_bank')
df = SQLContext.sql('''
                        SELECT
                            bank_Name,branch_idBranch
                            loans_date,loans_Amount,
                            avg(loans_Amount)  OVER(ORDER BY loans_date ROWS BETWEEN 90 PRECEDING AND CURRENT ROW ) as moving_average
                        FROM 
                            table_bank
                        GROUP BY 
                            ,bank_Name
                            ,branch_idBranch
                    ''' 
)

df.toDF().coalesce(1).write.option("header",True).partitionBy("bank_name", "loan_year", "loan_month").mode("overwrite").csv('bank_data')
job.commit()