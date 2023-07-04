from pyspark.sql import SparkSession
from pyspark.sql.window import Window
from pyspark.sql import functions as F
from pyspark.sql.functions import avg, col, concat, lit


# Create SparkSession
spark = SparkSession.builder \
          .appName('SparkByExamples.com') \
          .getOrCreate()

bank = glueContext.create_dynamic_frame.from_catalog(database="my_catalog_database", table_name="bank")
branch = glueContext.create_dynamic_frame.from_catalog(database="my_catalog_database", table_name="branch")
client = glueContext.create_dynamic_frame.from_catalog(database="my_catalog_database", table_name="client")
account = glueContext.create_dynamic_frame.from_catalog(database="my_catalog_database", table_name="account")
loans = glueContext.create_dynamic_frame.from_catalog(database="my_catalog_database", table_name="loans")

# Convert DynamicFrames to DataFrames
bankDF = bank.toDF()
branchDF = branch.toDF()
clientDF = client.toDF()
accountDF = account.toDF()
loanDF = loans.toDF()

newDF = bankDF.withColumnRenamed("name", "BankName").join(branchDF).where(bankDF["idBank"] == branchDF["Bank_idBank"]) \
    .join(clientDF).where(branchDF["idBranch"] == clientDF["Branch_idBranch"]) \
    .join(accountDF).where(clientDF["idClient"] == accountDF["Client_idClient"]) \
    .join(loanDF).where(accountDF["idAccount"] == loanDF["Account_idAccount"]) \

# Add a 'Year' and 'Month' column
newDF = newDF.withColumn('Year', F.year(F.col('loan_date')))
newDF = newDF.withColumn('Month', F.month(F.col('loan_date')))
newDF = newDF.select(col("BankName"), col("idBranch"), col("Year"), col("Month"), col("Amount"))

# Calculate the moving average of loan amounts over the last three months, per branch
window_spec = Window.partitionBy('idBranch').orderBy('Year', 'Month').rowsBetween(-2, 0)
newDF = newDF.withColumn('MovingAverage', F.avg('Amount').over(window_spec))

# Write the transformed dataset to separate monthly output files, partitioned by Bank Name, Year, and Month
output_path = 's3://teraflow-playgroundtf123-dev/output/'
newDF.withColumn("filename", concat(col("BankName"), lit("_"), col("Year"), col("Month"), lit(".csv"))) \
    .write.partitionBy("BankName", "Year", "Month") \
    .mode("append") \
    .csv(output_path, header=True)
