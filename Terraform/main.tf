terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# The AWS Secrets Manager retrieval

data "aws_secretsmanager_secret_version" "creds" {
  secret_id = "bank-creds"
}

locals {
  creds = jsondecode(
    data.aws_secretsmanager_secret_version.creds.secret_string
  )
}

# example retrieval username= local.db_creds.username

##################
# Glue Catalog   #
##################

resource "aws_glue_catalog_database" "banking_database" {
  name = "banking_group_database"
  description = "Database for banking group"
}

##################
# Glue Crawler   #
##################

# Default port for postgres is 5432
resource "aws_glue_catalog_crawler" "database_crawler" {
  name              = "database_crawler"
  role              = aws_iam_role.glue_crawler_role.arn
  database_name     = aws_glue_catalog_database.banking_database.name
  targets {
    jdbc_targets {
      connection_string = "jdbc:postgresql://${local.creds.db_host}:5432/${local.creds.db_name}"
      jdbc_username    = local.creds.db_username
      jdbc_password    = local.creds.db_password
      path             = ""
      exclusions       = []
    }
  }
}

# Create the IAM role for the Glue Jobs, glue service role seems good enough
resource "aws_iam_role" "glue_service_role" {
  name        = "AWSGlueServiceRole"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "glue.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "glue_service_role_policy" {
  role       = aws_iam_role.glue_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

##################
# S3 bucket      #
##################

resource "aws_s3_bucket" "output_bucket" {
  bucket = "banking_data/"
}

# S3 encrption
resource "aws_s3_bucket_encryption" "bucket_encryption" {
  bucket = aws_s3_bucket.output_bucket.id

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

# CloudWatch alarm
resource "aws_cloudwatch_metric_alarm" "job_failure_alarm" {
  alarm_name          = "job_failure_alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "JobRunFailed"
  namespace           = "AWS/Glue"
  period              = 60
  statistic           = "SampleCount"
  threshold           = 0
  alarm_description   = "Glue job failure alarm"
  alarm_actions       = [aws_sns_topic.my_topic.arn]
}

# Create the SNS topic
resource "aws_sns_topic" "my_topic" {
  name = "my_topic"
}

# SNS topic subscription for emails
resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.my_topic.arn
  protocol  = "email"
  endpoint  = local.creds.support_email
}

##################
# Glue Job       #
##################

resource "aws_glue_job" "my_job" {
  name           = "my_job"
  role           = aws_iam_role.glue_service_role.arn
  glue_version   = "3.0"
  command {
    python_version  = "3"
    script_location = "s3://${local.creds.s3_bucket_url}/etl.py"
  }
  default_arguments = {
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-auto-scaling"              = "true"
  }

  # Schedule job for first day of the month
  schedule {
    schedule_expression = "cron(0 0 1 * ? *)"
    state               = "ENABLED"
  }

  # CloudWatch trigger for failed job 
  triggers {
    type             = "CONDITIONAL"
    predicate {
      logical = "AND"
      conditions {
        job_run_state = "FAILED"
      }
    }
  }
}

##################
# SFTP Server    #
##################

#For this will create an ec2 instance and setup transfer service
# IAM role for the EC2 instance
resource "aws_iam_role" "sftp_instance_role" {
  name = "sftp_instance_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::${aws_s3_bucket.output_bucket.bucket}/*"
    }
  ]
}
EOF

}

# EC2 instance for the SFTP server
resource "aws_instance" "sftp_instance" {
  ami           = "ami-03025bb25a1de0fc2"
  instance_type = "t2.micro"      

  iam_instance_profile = aws_iam_instance_profile.sftp_instance_profile.name

  tags = {
    Name = "SFTP Instance"
  }
}

# IAM instance profile for the EC2 instance
resource "aws_iam_instance_profile" "sftp_instance_profile" {
  name = "sftp_instance_profile"
  role = aws_iam_role.sftp_instance_role.arn
}
