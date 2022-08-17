# senior-data-engineer-coding-interview

In Git, please create a `feature/` branch with your name and surname as the identifier and submit a pull request into the `development` branch once you're done coding.

# Problem Statement

You are consulting on a Banking group's Data Engineering project and need to write an extract from their Aurora cluster into a CSV file on S3.

There are three different banks in the group.

Given the following data model in an Amazon Aurora PostrgeSQL cluster:

![](DataModel_ERD.png)

# Perform the following tasks

1. Write code to deploy the following resources via Terraform:

(Put this code in the file `Terraform/main.tf`)

* A Glue Crawler to crawl this datasource
* A Glue Catalog Database to persist the metadata
* A Glue Job which will read data from this datasource and write it to S3
* An S3 bucket to house the transformed dataset

2. Write a Glue ETL script (use the file `main.tf`), which calculates the moving average of loan amounts taken out over the last three months, per branch. Create a separate file for each bank in the group. Files need to be partitioned by Bank Name, Year and Month and the filename needs to be of the format BankName_YYYYMMDD.csv
   
3. Bonus points if you can build in a form of scheduling/ an orchestration layer and ensure idempotency of the ETL system.