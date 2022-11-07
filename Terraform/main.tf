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
    region = "us-east-1"

        default_tags {
            tags = {
                Environment = var.environment
            }
        }
}
##################
# S3             #
##################
resource "aws_s3_bucket" "s3_data_etl_bucket" {
    bucket = var.s3_root_bucket_name
}
resource "aws_s3_bucket_acl" "s3_data_etl_bucket_acl" {
    bucket = aws_s3_bucket.s3_data_etl_bucket.id
        acl    = "private"
}
resource "aws_s3_bucket_object" "s3_glub_job_object"{
    key = var.s3_glue_bucket_name
        bucket = aws_s3_bucket.s3_data_etl_bucket.id
}
resource "aws_s3_bucket_object" "s3_data_object"{
    key = var.s3_data_bucket_name
        bucket = aws_s3_bucket.s3_data_etl_bucket.id 
        server_side_encryption = aws_kms_key.data_kms.arn
}
resource "aws_s3_bucket_server_side_encryption_configuration" "data_s3_encryption" {
    bucket = aws_s3_bucket.s3_data_object.bucket
        rule {
            apply_server_side_encryption_by_default {
                sse_algorithm     = "AES256"
            }
        }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "glue_s3_encryption" {
    bucket = aws_s3_bucket.s3_glub_job_object.bucket
        rule {
            apply_server_side_encryption_by_default {
                sse_algorithm     = "AES256"
            }
        }
}
##################
# Glue Catalog   #
##################
resource "aws_glue_catalog_database" "aurora_glue_catalog_database" {
    name = "AuroraCatalogDatabse"
        create_table_default_permission {
            permissions = ["SELECT"]
                principal {
                    data_lake_principal_identifier = "IAM_ALLOWED_PRINCIPALS"
                }
        }
}
##################
# Glue Crawler   #
##################
resource "aws_glue_connection" "aurora_glue_connection" {
    connection_properties = {
        JDBC_CONNECTION_URL = "jdbc:postgresql://${var.hostname}:5432"
            PASSWORD            = var.password
            USERNAME            = var.username
    }
    name = "example"
}
resource "aws_iam_role" "glue_role" {
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
resource "aws_glue_crawler" "aws_glue_aurora_crawler" {
    database_name = aws_glue_catalog_database.aurora_glue_catalog_database.name
        name          = "example"
        role          = aws_iam_role.glue_role.arn
        jdbc_target {
            connection_name = aws_glue_connection.aurora_glue_connection.name
                path            = "bankdb/%"
        }
    depends_on = [aws_glue_catalog_database.aurora_glue_catalog_database]
}
##################
# Glue Job       #
##################
resource "aws_glue_job" "etl_job" {
    name     = "etl_job"
        role_arn = aws_iam_role.glue_role.arn
        command {
            script_location = "s3://${aws_s3_bucket.s3_glub_job_object.bucket}/etl_job.py"
        }
}
