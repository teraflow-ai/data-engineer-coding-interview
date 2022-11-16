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

##################
# Glue Catalog   #
##################
resource "aws_glue_catalog_database" "aws_glue_catalog_database" {
  name = "banking_group"
}


#################################
# Glue Connection and Crawler   #
#################################
resource "aws_glue_connection" "banking_connection" {
  connection_properties = {
    JDBC_CONNECTION_URL = "jdbc:postgresql://aurora-pgress.cluster-cm6elvieiaiz.us-east-1.rds.amazonaws.com:5432/finance"
    PASSWORD            = "2486Okebe."
    USERNAME            = "postgres"
  }

  name = "banking_connection"

  physical_connection_requirements {
    availability_zone      = "us-east-1e"
    security_group_id_list = ["sg-0b8fceff13339705f"]
    subnet_id              = "subnet-0ff945865ca5a1cda"
  }
}

resource "aws_glue_crawler" "banking_crawler" {
  database_name = "banking_group"
  name          = "banking_crawler"
  role          = "arn:aws:iam::370310570296:role/big-boss-man"

  jdbc_target {
    connection_name = aws_glue_connection.banking_connection.name
    path            = "finance/%"
  }
}


##################
# Glue Job       #
##################
resource "aws_glue_job" "banking_job" {
  name              = "banking_job"
  role_arn          = "arn:aws:iam::370310570296:role/big-boss-man"
  glue_version      = "3.0"
  worker_type       = "G.1X"
  number_of_workers = 3

  command {
    script_location = "s3://aws-glue-assets-370310570296-us-east-1/scripts/test-delete.py"
  }

  default_arguments = {
    "--additional-python-modules"        = "s3-concat"
    "--job-bookmark-option"              = "job-bookmark-enable"
    "--enable-continuous-cloudwatch-log" = "true"
  }
}

############################
# S3 Bucket with SSE       #
############################
resource "aws_s3_bucket" "banking_output" {
  bucket = "my-edokemwa-tf-test-bucket"

  tags = {
    Name        = "Banking output bucket to share"
    Environment = "Dev"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "banking_output_encrypt" {
  bucket = aws_s3_bucket.banking_output.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "AES256"
    }
  }
}


##################
# SFTP server    #
##################
resource "aws_instance" "sftp_server" {
  ami           = "ami-05d15be56f7c1ea2f"
  instance_type = "t2.micro"

  tags = {
    Name = "SftpS3MountServer"
  }
}


#########################
# SNS Subscription      #
#########################
resource "aws_sns_topic" "banking_job_update" {
  name = "banking-job-topic"
}

resource "aws_sns_topic_subscription" "banking_job_failure" {
  topic_arn = aws_sns_topic.banking_job_update.arn
  protocol  = "email"
  endpoint  = "data-support@mybigbank.co.za"
}

#############################################################
# STEP Functions for orchestration and notification         #
#############################################################
resource "aws_sfn_state_machine" "banking_state_machine" {
  name     = "banking-state-machine"
  role_arn = "arn:aws:iam::370310570296:role/service-role/StepFunctions-test-delete-glue-role-d6b9a3df"

  definition = <<EOF
{
  "Comment": "Workflow to run Glue Job",
  "StartAt": "Glue StartJobRun",
  "States": {
    "Glue StartJobRun": {
      "Type": "Task",
      "Resource": "arn:aws:states:::glue:startJobRun.sync",
      "Parameters": {
        "JobName": "test-delete"
      },
      "Comment": "Run Glue Job",
      "Next": "Choice"
    },
    "Choice": {
      "Type": "Choice",
      "Choices": [
        {
          "Not": {
            "Variable": "$.JobRunState",
            "StringEquals": "SUCCEEDED"
          },
          "Next": "Publish"
        }
      ],
      "Default": "Pass"
    },
    "Publish": {
      "Type": "Task",
      "Resource": "arn:aws:states:::sns:publish",
      "Parameters": {
        "Message.$": "$",
        "TopicArn": "arn:aws:sns:us-east-1:370310570296:amplify_codecommit_topic"
      },
      "End": true
    },
    "Pass": {
      "Type": "Pass",
      "End": true
    }
  }
}
EOF
}