## Developed by : Marli van der Merwe
## Description: This Terraform configuration sets up AWS resources required for running Python scripts and provides monitoring capabilities.

##########################################################################################
# VARIABLES  #
##########################################################################################

#ACCESS
variable "region" {
  description = "email addrress"
}

 variable "access_key_id"{
  description = "AWS access key ID"
}
 variable "secret_key" {
  description = "AWS secret key"
}

provider "aws" {
  region     = var.region
  # access_key_id = var.access_key_id
  # secret_key = var.secret_key
}

#AWS SUBCRIPTION EMAIL
variable "email" {
  description = "Support email addrress for job failures"
}


#AURORA CONNECTION
variable "connection_url" {
  description = "JDBC connection URL"
}
variable "password" {
  description = "Database password for Glue connection"
}
variable "username" {
  description = "Database username"
}
variable "aurorapath" {
  description = "Database path (database/schema%)"
}

#ADDITIONAL GLUE PARAMETERS
variable "glue_catalog_db" {
  description = "Glue catalog database name"
}
variable "glue_aurora_jdbc_url" {
  description = "JDBC URL for Aurora database"
}

variable "glue_aurora_schema" {
  description = "Schema name in Aurora database"
}
variable "glue_aurora_user" {
  description = "Username for Aurora database"
}
variable "glue_aurora_password" {
  description = "Password for Aurora database for additional Glue parameters"
}
# variable "glue_s3_bucket_name" {
#   description = "Name of the S3 bucket"
# }
variable "glue_s3_directory" {
  description = "Directory in the S3 bucket"
}

variable "tag_team" {
  description = "Name of the team"
}

##########################################################################################
# S3 BUCKETS, OBJECTS AND ENCRYPTION  #
##########################################################################################
# Module      : AWS S3 BUCKET
# Description : Provides an AWS S3 bucket resource.

# Module      : AWS S3 BUCKET SERVER SIDE ENCRYPTION CONFIGURATION
# Description : Provides server-side encryption configuration for an AWS S3 bucket.

resource "aws_s3_bucket" "bank-bucket-1" {
  bucket = "bank-bucket-1"

  tags = {
    "Team" = var.tag_team
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bank-bucket-1-encryption" {
  bucket = aws_s3_bucket.bank-bucket-1.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket" "moving-average-bucket-2" {
  bucket = "moving-average-bucket-2"

  tags = {
    "Team" = var.tag_team
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "moving-average-bucket-2" {
  bucket = aws_s3_bucket.moving-average-bucket-2.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket" "script-bucket-3" {
  bucket = "script-bucket-3"

  tags = {
    "Team" = var.tag_team
  }
}

resource "aws_s3_object" "script-bucket-3-python-script" {
  bucket = aws_s3_bucket.script-bucket-3.id
  key    = "scripts/bank_pipeline_script.py"
  source = "${path.module}/../Glue/bank_pipeline_script.py"
  
}

resource "aws_s3_object" "script-moving-average-python-script" {
  bucket = aws_s3_bucket.script-bucket-3.id
  key    = "scripts/etl.py"
  source = "${path.module}/../Glue/etl.py"
  
}

resource "aws_s3_bucket_server_side_encryption_configuration" "script-bucket-3" {
  bucket = aws_s3_bucket.script-bucket-3.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

##########################################################################################
# KEYS, CONNECTION, IAM ROLE, IAM ROLE POLICY  #
##########################################################################################
# Module      : AWS KMS KEY
# Description : Provides an AWS KMS key resource.
resource "aws_kms_key" "t-key" {
  description             = "Example KMS key"
  enable_key_rotation = true

  tags = {
    "Team" = var.tag_team
  }
}

# Module      : AWS KMS ALIAS
# Description : Provides an AWS KMS alias resource.
resource "aws_kms_alias" "t-key-alias" {
  name          = "alias/t-key"
  target_key_id = aws_kms_key.t-key.key_id

}

# Module      : AWS GLUE CONNECTION
# Description : Provides an AWS Glue connection resource.
resource "aws_glue_connection" "marli-terraform-connection" {
  connection_properties = {
    JDBC_CONNECTION_URL = var.connection_url
    PASSWORD            = var.password
    USERNAME            = var.username
  }

  name = "marli-terraform-connection"

  tags = {
    "Team" = var.tag_team
  }
}


# Module      : AWS IAM ROLE
# Description : Provides an AWS IAM role for Glue service.
resource "aws_iam_role" "glue_service_role" {
  name = "glue_service_role"

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

# Module      : AWS IAM ROLE POLICY
# Description : Provides an AWS IAM role policy for Glue service.
resource "aws_iam_role_policy" "glue_service_role_policy_m_test" {
  name   = "glue_service_role_policy_m_test"
  role   = aws_iam_role.glue_service_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "glue:*",
        "s3:GetBucketLocation",
        "s3:ListBucket",
        "s3:ListAllMyBuckets",
        "s3:GetBucketAcl",
        "ec2:DescribeVpcEndpoints",
        "ec2:DescribeRouteTables",
        "ec2:CreateNetworkInterface",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSubnets",
        "ec2:DescribeVpcAttribute",
        "iam:ListRolePolicies",
        "iam:GetRole",
        "iam:GetRolePolicy",
        "cloudwatch:PutMetricData",
        "kms:GetKeyPolicy",
        "kms:ListKeyPolicies"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "s3:CreateBucket",
      "Resource": "arn:aws:s3:::aws-glue-*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::aws-glue-*/*",
        "arn:aws:s3:::*/*aws-glue-*/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": [
        "arn:aws:s3:::crawler-public*",
        "arn:aws:s3:::aws-glue-*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:/aws-glue/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateTags",
        "ec2:DeleteTags"
      ],
      "Condition": {
        "ForAllValues:StringEquals": {
          "aws:TagKeys": [
            "aws-glue-service-resource"
          ]
        }
      },
      "Resource": [
        "arn:aws:ec2:*:*:network-interface/*",
        "arn:aws:ec2:*:*:security-group/*",
        "arn:aws:ec2:*:*:instance/*"
      ]
    }
  ]
}
EOF
}

##########################################################################################
# SNS TOPIC AND SUBCRIPTION  #
##########################################################################################

# Module      : AWS SNS TOPIC
# Description : Provides an AWS SNS topic resource.
resource "aws_sns_topic" "marli_example_topic" {
  name = "marli_example_topic"

  tags = {
    "Team" = var.tag_team
  }
}

# Module      : AWS SNS TOPIC SUBSCRIPTION
# Description : Provides an AWS SNS topic subscription resource.
resource "aws_sns_topic_subscription" "marli_example_subscription" {
  topic_arn = aws_sns_topic.marli_example_topic.arn
  protocol  = "email"
  endpoint  = var.email
}

##########################################################################################
# AWS GLUE CATALOG DATABASE  #
##########################################################################################
# Module      : AWS GLUE CATALOG DATABASE
# Description : Provides an AWS Glue catalog database resource.
resource "aws_glue_catalog_database" "marli-terraform-database" {
  name = "marli-terraform-database"

  tags = {
    "Team" = var.tag_team
  }
}

##########################################################################################
# AWS GLUE CRAWLER  #
##########################################################################################
# Module      : AWS GLUE CRAWLER
# Description : Provides an AWS Glue crawler resource.
resource "aws_glue_crawler" "marli-example" {
  database_name = aws_glue_catalog_database.marli-terraform-database.name
  name          = "marli-example"
  role          = aws_iam_role.glue_service_role.arn
  schedule        = "cron(0 0 * * ? *)"  # Schedule for everyday at 12am

  jdbc_target {
    connection_name = aws_glue_connection.marli-terraform-connection.name
    path            = var.aurorapath
  }

    tags = {
    "Team" = var.tag_team
  }
}

# Module      : AWS GLUE SECURITY CONFIGURATION
# Description : Provides an AWS Glue security configuration resource.
resource "aws_glue_security_configuration" "marli-example" {
  name = "marli-example-security-config"

  encryption_configuration {
    cloudwatch_encryption {
      cloudwatch_encryption_mode = "DISABLED"
    }

    job_bookmarks_encryption {
      job_bookmarks_encryption_mode = "DISABLED"
    }

    s3_encryption {
      kms_key_arn        = aws_kms_key.t-key.arn
      s3_encryption_mode = "SSE-KMS"
    }
  }
}

##########################################################################################
# AWS GLUE JOBS AND TRIGGERS  #
##########################################################################################

# Module      : AWS GLUE JOB 1
# Description : Provides an AWS Glue job resource.
resource "aws_glue_job" "bank-pipeline-glue-job" {
  name                    = "bank-pipeline-glue-job"
  role_arn                = aws_iam_role.glue_service_role.arn
  connections             = [aws_glue_connection.marli-terraform-connection.name]
  security_configuration = aws_glue_security_configuration.marli-example.name

  command {
    script_location = "s3://${aws_s3_bucket.script-bucket-3.id}/scripts/bank_pipeline_script.py" 
  }

  glue_version             = "3.0"
  description              = "This job reads data from the Aurora instance and writes it to S3 every day"
  worker_type              = "G.1X"
  number_of_workers        = 10
  timeout                  = 2400

  tags = {
    "Team" = var.tag_team
  }

  default_arguments = {
    "--CATALOG_DB_NAME" = var.glue_catalog_db
    "--JDBC_URL" = var.glue_aurora_jdbc_url
    "--S3_BUCKET" = aws_s3_bucket.bank-bucket-1.bucket
    "--SCHEMA" = var.glue_aurora_schema
    "--USER" = var.glue_aurora_user
    "--PASSWORD" = var.glue_aurora_password
  }
}

# Module      : AWS GLUE TRIGGER 1
# Description : Provides an AWS Glue trigger resource.
resource "aws_glue_trigger" "marli-terraform-trigger" {
  name        = "marli-terraform-trigger"
  schedule    = "cron(30 0 * * ? *)"  # Run every day at 12:30 AM
  type        = "SCHEDULED"

  actions {
    job_name = aws_glue_job.bank-pipeline-glue-job.id
  }
}

# Module      : AWS GLUE JOB 2
# Description : Provides an AWS Glue job resource.
resource "aws_glue_job" "moving-average-glue-job" {
  name                    = "moving-average-glue-job"
  role_arn                = aws_iam_role.glue_service_role.arn
  connections             = [aws_glue_connection.marli-terraform-connection.name]
  security_configuration = aws_glue_security_configuration.marli-example.name

  command {
    script_location = "s3://${aws_s3_bucket.script-bucket-3.id}/scripts/etl.py" 
  }

  glue_version             = "3.0"
  description              = "This job calculates the moving average per branch and writes the data to S3 once a month"
  worker_type              = "G.1X"
  number_of_workers        = 10
  timeout                  = 2400

  tags = {
    "Team" = var.tag_team
  }

  default_arguments = {
    "--BUCKET_NAME" = aws_s3_bucket.moving-average-bucket-2.bucket
    "--DIRECTORY" = var.glue_s3_directory
    "--CATALOG_DB_NAME" = var.glue_catalog_db
    "--JDBC_URL" = var.glue_aurora_jdbc_url
    "--S3_BUCKET" = aws_s3_bucket.moving-average-bucket-2.bucket
    "--SCHEMA" = var.glue_aurora_schema
    "--USER" = var.glue_aurora_user
    "--PASSWORD" = var.glue_aurora_password
  }
}

# Module      : AWS GLUE TRIGGER 2
# Description : Provides an AWS Glue trigger resource.
resource "aws_glue_trigger" "marli-terraform-trigger-2" {
  name        = "marli-terraform-trigger-2"
  schedule    = "cron(0 0 1 * ? *)"  # Run on the first of every month
  type        = "SCHEDULED"

  actions {
    job_name = aws_glue_job.moving-average-glue-job.id
  }
}

##########################################################################################
# AWS CLOUDWATCH EVENT RULE  #
##########################################################################################

# Module      : CLOUDWATCH EVENT RULE
# Description : Provides an AWS CloudWatch Event rule resource.
resource "aws_cloudwatch_event_rule" "marli_example_rule" {
  name        = "marli-example-glue-job-failure-rule"
  description = "CloudWatch Events rule for Glue job failure"

  event_pattern = <<EOF
{
  "source": [
    "aws.glue"
  ],
  "detail-type": [
    "Glue Job State Change"
  ],
  "detail": {
    "state": [
      "FAILED", "ERROR", "STOPPED"
    ],
    "jobName": [
      "${aws_glue_job.bank-pipeline-glue-job.name}", "${aws_glue_job.moving-average-glue-job.name}"
    ]
  }
}
EOF
}

##########################################################################################
# DONE  #
##########################################################################################
