

provider "aws" {
    region = "us-west-2"
}

###################
# Glue Catalog   #
##################

resource "aws_glue_catalog_database" "aws_glue_catalog_database" {
  name = "OperationalDataStoreDatabase"
}

##################
# Glue Crawler   #
##################

resource "aws_glue_crawler" "GlueCrawlerODD" {
  database_name = aws_glue_catalog_database.example.name
  name          = "glue_crawl"
  role          = aws_iam_role.glue_crawler.arn
  jdbc_target {
    connection_name = aws_glue_connection.example.name
    path            = "mycluster.cluster-123456789012.us-east-1.rds.amazonaws.com"
    PASSWORD            = "5Y67bg#r#"
    USERNAME            = "postgres"
  }
}

##################
# Glue Job       #
##################

resource "aws_glue_job" "GlueJobODD" {
  name     = "glue_job"
  role_arn = aws_iam_role.glue_job.arn

  command {
    script_location = "s3://${aws_s3_bucket.glue_job.bucket}/boto_script.py"
  }
}