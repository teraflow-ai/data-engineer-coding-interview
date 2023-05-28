##################
# Glue Catalog   #
##################

##################
# Glue Crawler   #
##################

##################
# Glue Job       #
##################

provider "aws" {
  region = "us-east-1"
}

resource "aws_glue_crawler" "bank_data_crawler" {
  name = "bank_data_crawler"
  database_name = "bank_data"
  role = "arn:aws:iam::123456789012:role/glue-crawler-role"
  schedule = "cron(0 0 1 * * ? *)"

  s3_target {
    path = "s3://my-bucket/bank-data/"
  }
}

resource "aws_glue_catalog_database" "bank_data" {
  name = "bank_data"
}

resource "aws_glue_job" "bank_data_job" {
  name = "bank_data_job"
  role_arn = "arn:aws:iam::123456789012:role/glue-job-role"
  description = "This job reads data from the Aurora cluster Data Store and writes it to S3."

  command {
    script_location = "s3://my-bucket/bank-data/etl.py"
  }

  dag {
    nodes {
      name = "read_data"
      action = "ReadFromJdbc"
      arguments {
        query = "SELECT * FROM bank_data"
        connection_name = "mycluster.cluster-123456789012.us-east-1.rds.amazonaws.com"
        username = "postgres"
        password = "5Y67bg#r#"
      }
    }

    nodes {
      name = "write_data"
      action = "WriteToS3"
      arguments {
        path = "s3://my-bucket/bank-data/"
        format = "CSV"
      }
    }

    edges {
      from = "read_data"
      to = "write_data"
    }
  }
}

resource "aws_s3_bucket" "bank_data_bucket" {
  name = "my-bucket"
  region = "us-east-1"
  versioning {
    enabled = true
  }
}