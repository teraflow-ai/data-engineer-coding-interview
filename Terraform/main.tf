#-----------------------------------
#-----------------------------------
# CONSIDERATIONS/ TO DO
# 3. Cleanup and Review
# 3. Add readme
#-----------------------------------
#-----------------------------------


#########################################################################
# ASSUMPTIONS
# 1. Appropriate network connectivity (VPC endpoints, etc.) has been setup to allow Glue to access the Aurora database 
# 2. The user/role executing the teraform code has sufficient permissions to create all the required objects
# 3. 
########################################################################


########################################################################
# Setup                                                                #
########################################################################

#Import AWS provider
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

  default_tags {
    tags = {
      Environment = var.environment
      Client      = var.client
    }
  }
}

########################################################################
# IAM                                                                  #
########################################################################

##################
# Glue Role      #
##################

resource "aws_iam_role" "glue_analytics_role" {
  name = "glue_analytics_role"

  assume_role_policy = jsonencode({  #Allow AWS Glue to use the role
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "glue.amazonaws.com"
        }
      },
    ]
  })

  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole" # Provide basic access required for Glue to function correctly
                        ,"arn:aws:iam::aws:policy/AmazonRDSFullAccess"             # Provide Glue access to read RDS source database
                        ,"arn:aws:iam::aws:policy/AmazonS3FullAccess"              # Provide Glue access to write to S3 target
                        ]

}


########################################################################
# S3                                                                   #
########################################################################

##################
# S3 Buckets     #
##################
# Create S3 bucket for results
resource "aws_s3_bucket" "glue_output" {
  bucket = var.s3_bucket_name_results

}

# Create S3 bucket for glue scripts
resource "aws_s3_bucket" "glue_scripts" {
  bucket = var.s3_bucket_name_glue_scripts
}


##################
# Encryption     #
##################
# Note that simple server side AWS managed keys (SSE-S3) have been used 
# For more sophistication/more advanced security KMS (AWS managed or Client managed) could be used

# Encrypt results bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "output_sse" {
  bucket = aws_s3_bucket.glue_output.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "AES256"
    }
  }
}

# Encrypt glue scripts bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "output_sse" {
  bucket = aws_s3_bucket.glue_scripts.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "AES256"
    }
  }
}


########################################################################
# GLUE                                                                 #
########################################################################

##################
# Glue Catalog   #
##################

# Create Glue database - Aurora Source
resource "aws_glue_catalog_database" "big_bank_aurora" {
  name = var.glue_db_name_big_bank_aurora
}


###################
# Glue Connection #
###################
resource "aws_glue_connection" "big_bank_aurora_jdbc_connection" {
  connection_properties = {
    JDBC_CONNECTION_URL = "jdbc:postgresql://${var.aurora_db_connection_hostname}:5432/${var.aurora_db_database_name}" #JDBC connection string based on 

    USERNAME            = var.aurora_db_username
    PASSWORD            = var.aurora_db_password
  }

  name = "big_bank_aurora_jdbc_connection"
}

##################
# Glue Crawler   #
##################
resource "aws_glue_crawler" "big_bank_aurora_crawler" {
  database_name = aws_glue_catalog_database.big_bank_aurora.name
  name          = var.glue_crawler_name_big_bank_aurora
  role          = aws_iam_role.glue_analytics_role.arn

  jdbc_target {
    connection_name = aws_glue_connection.big_bank_aurora_jdbc_connection.name
    path            = "${var.aurora_db_database_name}/%"
  }
}


##################
# Glue Job       #
##################
resource "aws_glue_job" "monthly_loan_value" {
  name     = var.glue_job_name_monthly_loan_value
  role_arn = aws_iam_role.example.arn

  command {
    script_location = "s3://${aws_s3_bucket.glue_output.bucket}/monthly_loan_value.py"
  }
}