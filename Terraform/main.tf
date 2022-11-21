######################################
#Initilize the Terraform 

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

#Terraform to know what provider to use 
provider "aws" {
  region  = "eu-west-1"
}

#Initilize the Terraform 
######################################


######################################
#IAM Policies

resource "aws_iam_role_policy" "banking_full_role" {
    name = "bank-developer"
      policy = <<EOF
        {
        "Version": "2012-10-17",
        "Statement": [
            {
            "Effect": "Allow",
            "Action": [
                "s3:*"
            ],
            "Resource": [
                "arn:aws:s3:::bank_data",
                "arn:aws:s3:::bank_data/*"
            ]
            }
        ]
        }
        EOF
}

resource "aws_iam_role" "glue_full_role" {
  name = "glue_full_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "glue.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role" "glue_state_machine" {
  name = "glue_state_machine"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = [
            "states.amazonaws.com"
          ]
        }
      },
    ]
  })
  }


#IAM Policies
######################################



######################################
#Creating static resources

#S3 bucket for data outputs
resource "aws_s3_bucket" "glue_data_output" {
  bucket = var.s3_glue_data_output

}

#S3 bucket for glue job .py 
resource "aws_s3_bucket" "glue_job_location" {
  bucket = var.s3_glue_job
}

resource "aws_secretsmanager_secret" "rotation_secret" {
  name                = "rotation_secret"
  rotation_lambda_arn = aws_lambda_function.example.arn

  rotation_rules {
    automatically_after_days = 7
  }
}


#Creating static resources
######################################



##################
# Glue Catalog   #
##################


#Glue Catalog
resource "aws_glue_catalog_database" "bank_data" {
  name = var.db_name_glue
}

#Creating the connection so the crawler can read the data from the JDBC connection
resource "aws_glue_connection" "source_db_bank_jdbc" {
  connection_properties = {
    JDBC_CONNECTION_URL = "jdbc:postgresql://${var.source_db_host_name}:5432/${var.source_db_name}"

    USERNAME            = var.source_db_username
    PASSWORD            = var.source_db_password
  }

  name = "source_db_bank_jdbc"
}

##################
# Glue Crawler   #
##################

# Since we created the glue connection we can then create the glue crawler
resource "aws_glue_crawler" "db_data_crawler" {
  database_name = aws_glue_catalog_database.name
  name          = "db_data_crawler"
  role          = aws_iam_role.glue_full_role.arn

  jdbc_target {
    connection_name = aws_glue_connection.source_db_bank_jdbc.name
    path            = "{var.source_db_host_name}/%"
  }
}


##################
# Glue Job       #
##################

resource "aws_glue_job" "s3_glue_job" {
  name     = var.s3_glue_job
  role_arn = aws_iam_role.glue_full_role

  command {
    script_location = "s3://${aws_s3_bucket.glue_job_location.bucket_domain_name}/etl.py"
  }
}




#########################
# SNS Subscription      

resource "aws_sns_topic" "banking_email_fail" {
  name = "banking_email_fail"
}

resource "aws_sns_topic_subscription" "bank_email_sending" {
  topic_arn = aws_sns_topic.banking_job_update.arn
  protocol  = "email"
  endpoint  = "data-support@mybigbank.co.za"
}


# SNS Subscription 
#########################
     


#########################
#Step Function

resource "aws_sfn_state_machine" "glue_bank" {
  name     = "glue_bank"
  role_arn = aws_iam_role.glue_state_machine.arn

  definition = <<EOF
{
  "Comment": "This is the State machine for the Bank Data Glue job",
  "StartAt": "Glue StartJobRun",
  "States": {
    "Glue StartJobRun": {
      "Type": "Task",
      "Resource": "arn:aws:states:::glue:startJobRun.sync",
      "Parameters": {
        "JobName": "${aws_glue_job.banking_job.name}"
      },
      "Next": "Choice"
    },
    "Choice": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.JobRunState",
          "StringEquals": "FAILED",
          "Next": "SNS Publish"
        },
        {
          "End": true
        }
      ],
      "Default": "Success"
    },
    "SNS Publish": {
      "Type": "Task",
      "Resource": "arn:aws:states:::sns:publish",
      "Parameters": {
        "Message.$": "The Glue Job failed!",
        "TopicArn": "${aws_sns_topic.banking_job_update.arn}"
      },
      "Next": "Fail"
    },
    "Fail": {
      "Type": "Fail"
    },
    "Success": {
      "Type": "Succeed"
    }
  }
}
EOF
}

#So the state machine run every month
resource "aws_glue_trigger" "monthly_run_glue_job" {
  name     = "monthly_runner"
  schedule = "cron(0 0 1 * *)"
  type     = "SCHEDULED"

  actions {
    job_name = aws_sfn_state_machine.glue_bank
  }
}

#Step Function
#########################


##########################################################################################

#ATTEMPT TO THE SFTP SERVER

##########################################################################################

resource "aws_vpc" "main_vpc" {
  cidr_block       = "10.0.1.0/24"
  instance_tenancy = "default"

  tags = {
    Name = "main"
  }
}

resource "aws_subnet" "main_subnet" {
  vpc_id     = aws_vpc.main_vpc.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "Main"
  }
}

resource "aws_acm_certificate" "cert_bank" {
  domain_name       = "bankdata.com"
  validation_method = "DNS"

  tags = {
    Environment = "prod"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_rest_api" "rest_api_data_bank" {
  body = jsonencode({
    openapi = "3.0.1"
    info = {
      title   = "get_monthly_data"
      version = "1.0"
    }
    paths = {
      "/get_data" = {
        get = {
          x-amazon-apigateway-integration = {
            httpMethod           = "GET"
            payloadFormatVersion = "1.0"
            type                 = "HTTP_PROXY"
            uri                  = "https://ip-ranges.amazonaws.com/ip-ranges.json"
          }
        }
      }
    }
  })

  name = "get_monthly_data"
}

resource "aws_api_gateway_deployment" "monthly_data" {
  rest_api_id = aws_api_gateway_rest_api.rest_api_data_bank.id

  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.rest_api_data_bank.body))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "bank_api_stage_gateway" {
  deployment_id = aws_api_gateway_deployment.monthly_data.id
  rest_api_id   = aws_api_gateway_rest_api.rest_api_data_bank.id
  stage_name    = "bank_api_stage_gateway"
}


resource "aws_api_gateway_rest_api" "bank_api" {
  name        = "Bank_API"
  description = "API for bank monthly data"
}

resource "aws_api_gateway_resource" "BankAPI" {
  rest_api_id = aws_api_gateway_rest_api.rest_api_data_bank.id
  parent_id   = aws_api_gateway_rest_api.bank_api.root_resource_id
  path_part   = "bank"
}

resource "aws_transfer_server" "sftp_server_s3" {
  endpoint_type = "VPC"

  endpoint_details {
    subnet_ids = [aws_subnet.main_subnet.id]
    vpc_id     = aws_vpc.main_vpc.id
  }

  protocols   = ["FTP", "FTPS"]
  certificate = aws_acm_certificate.cert_bank.arn

  identity_provider_type = "API_GATEWAY"
  url                    = "${aws_api_gateway_deployment.monthly_data.invoke_url}${aws_api_gateway_resource.BankAPI.path}"
}




##########################################################################################

#ATTEMPT TO THE SFTP SERVER

##########################################################################################