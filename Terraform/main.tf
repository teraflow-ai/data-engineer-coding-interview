terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-1"
}


# Glue Catalog

resource "aws_iam_role" "bankingrole" {
  name = "bankservadmin"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = [
            "vpc-flow-logs.amazonaws.com",
            "glue.amazonaws.com",
            "states.amazonaws.com"
          ]
        }
      },
    ]
  })

  inline_policy {
    name = "my_inline_policy"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action   = "*"
          Effect   = "Allow"
          Resource = "*"
        },
      ]
    })
  }
}


# Glue Catalog
resource "aws_glue_catalog_database" "aws_glue_catalog_database" {
  name = "bank_data"
}


# Glue Connection and Crawler
resource "aws_glue_connection" "banking_connection" {
  connection_properties = {
    JDBC_CONNECTION_URL = "jdbc:postgresql://mycluster.cluster-123456789012.us-east-1.rds.amazonaws.com:5432/bank_data"
    PASSWORD            = "5Y67bg#r#"
    USERNAME            = "postgres"
  }

  name = "bank_connection"

  physical_connection_requirements {
    availability_zone      = "us-east-1e"
    security_group_id_list = ["sg-0b8fceff13339705f"]
    subnet_id              = "subnet-0ff945865ca5a1cda"
  }
}

resource "aws_glue_crawler" "banking_crawler" {
  database_name = "bank_data"
  name          = "banking_crawler"
  role          = aws_iam.bankingrole.arn

  jdbc_target {
    connection_name = aws_glue_connection.banking_connection.name
    path            = "bank_data"
  }
}


##################
# Glue Crawler   #
# Glue Job       #
##################
resource "aws_glue_job" "banking_job" {
  name              = "banking_job"
  role_arn          = aws_iam.bankingrole.arn
  glue_version      = "3.0"
  worker_type       = "G.1X"
  number_of_workers = 3

  command {
    script_location = "s3://aws-glue-assets-123456789-us-east-1/scripts/"
  }

  connections =  [aws_glue_connection.banking_connection.name]

  default_arguments = {
    "--additional-python-modules"        = "s3-concat"
    "--enable-continuous-cloudwatch-log" = "true"
  }
}


# S3 Bucket with SSE
resource "aws_s3_bucket" "banking_output" {
  bucket = "banking_data/"

  tags = {
    Name        = "Banking output bucket to share"
    Environment = "Dev"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "banking_output_encrypt" {
  bucket = aws_s3_bucket.banking_output.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}




