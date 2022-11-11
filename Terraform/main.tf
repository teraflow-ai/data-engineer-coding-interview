#initialize aws providers
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Configure the AWS Provider and set default tags
provider "aws" {
  region = "eu-west-1"
  access_key = "################"
  secret_key = "###############"
  
}

# Create a VPC
resource "aws_vpc" "example" {
  cidr_block = "10.0.0.0/16"
}

#role  
#### Assume this role as all the neccessary permissions
resource "aws_iam_role" "glue_bank_role" {
  name = "glue_bank_role"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    tag-key = "tag-value"
  }
}

# connection  
resource "aws_glue_connection" "db_glue_connection" {
  connection_properties = {
    JDBC_CONNECTION_URL = "jdbc:postgresql://${var.connection_hostname}:${port}/${var.database_name}" 
    USERNAME            = var.user_name
    PASSWORD            = var.password
  }

  name = var.connection_name
}

##################
# Glue Catalog   #
##################
resource "aws_glue_catalog_database" "bank_db_catalog" {
  name = var.glue_bank_db_catalog
}

##################
# Glue Crawler   #
##################

resource "aws_glue_crawler" "bank_crawler" {
  database_name = var.glue_bank_db_catalog
  name          = var.glue_crawler_bank_db
  role          = aws_iam_role.glue_bank_role.arn

  jdbc_target {
    connection_name = var.connection_name
    path            = "${var.database_name}/%"
  }
}


##################
# Glue Job       #
##################



resource "aws_glue_job" "glue_bank_job" {
  name     = "glue_bank_job"
  role_arn = aws_iam_role.glue_bank_role.arn

  command {
    script_location = "s3://${var.s3_bucket_glue_scripts}/etl.py"
  }
}

###############
# S3 Bucket to house the transformed data
###############

resource "aws_s3_bucket" "s3_bucket_store_results" {
    bucket = "s3-bank-bucket"

    tags ={
        Name = "Bank Bucket"
    }
}