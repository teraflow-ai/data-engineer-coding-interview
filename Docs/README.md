# Solution Architecture:

* Glue Crawler to crawl the Aurora Cluster (JDBC Connection). 
* A Glue Database for the metadata.
* A Glue ETL Job to transform and load the data into an S3 Bucket. Scheduled monthly.
* S3 Bucket for transformed dataset.
* Create the IAM roles with necessary permissions to interact with these resources.
* (SFTP server on EC2)
* (CloudWatch Event Rule and SNS Topic to update support)

# Security:

* Will configure an AWS Secrets Manager to store all variable names and passwords.
