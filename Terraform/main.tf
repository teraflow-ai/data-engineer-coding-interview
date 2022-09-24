provider "aws" {
  region = "af-south-1"
  default_tags {
    tags = {
      assessment = "teraflow.ai"
    }
  }
}

variable "db_username" {
  description = "Aurora db username"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Aurora db password"
  type        = string
  sensitive   = true
}

variable "db_endpoint" {
  description = "Aurora db endpoint"
  type        = string
}

variable "db_port" {
  description = "Aurora db port"
  type        = number
}

variable "target_bucket_name" {
  description = "Bucket name where ETL results are stored"
  type        = string
}


# access management
data "aws_iam_policy" "AWSGlueServiceRole" {
  name = "AWSGlueServiceRole"
}
data "aws_iam_policy" "AmazonS3FullAccess" {
  name = "AmazonS3FullAccess" # too broad of an access policy, but I'm not a SecOps engineer so 🤷🏻‍️
}

resource "aws_iam_role" "glue-role" {
  name = "glue-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach-glue-service" {
  role       = aws_iam_role.glue-role.name
  policy_arn = data.aws_iam_policy.AWSGlueServiceRole.arn
}

resource "aws_iam_role_policy_attachment" "attach-glue-s3" {
  role       = aws_iam_role.glue-role.name
  policy_arn = data.aws_iam_policy.AmazonS3FullAccess.arn
}

resource "aws_s3_bucket" "crawlresults" {
  bucket        = var.target_bucket_name
  force_destroy = true
}

# secrets management
resource "aws_secretsmanager_secret" "bank_db_password_secret" {
  name = "bank_db_password_secret"
}
resource "aws_secretsmanager_secret" "bank_db_username_secret" {
  name = "bank_db_username_secret"
}
resource "aws_secretsmanager_secret_version" "bank_db_username" {
  secret_id     = aws_secretsmanager_secret.bank_db_username_secret.id
  secret_string = var.db_username
}
resource "aws_secretsmanager_secret_version" "bank_db_password" {
  secret_id     = aws_secretsmanager_secret.bank_db_password_secret.id
  secret_string = var.db_password
}

resource "aws_glue_connection" "bank_conn" {
  connection_properties = {
    JDBC_CONNECTION_URL = "jdbc:postgresql://${var.db_endpoint}:${var.db_port}"
    PASSWORD            = aws_secretsmanager_secret_version.bank_db_password.secret_string
    USERNAME            = aws_secretsmanager_secret_version.bank_db_username.secret_string
  }
  name = "bank_conn"
}

# upload script to s3 bucket so glue job can read it
resource "aws_s3_object" "object" {
  bucket = aws_s3_bucket.crawlresults.bucket
  key    = "etl.py"
  source = "../Glue/etl.py"

}

# logging
resource "aws_cloudwatch_log_group" "banklogger" {
  name = "banklogger"

  tags = {
    Environment = "development"
  }
}
# logging
resource "aws_cloudwatch_log_group" "glue_errors" {
  name = "/aws-glue/jobs/error"

  tags = {
    Environment = "development"
  }
}

##################
# Glue Catalog   #
##################
resource "aws_glue_catalog_database" "bank_db" {
  name = "bank_db"
}
##################
# Glue Crawler   #
##################
resource "aws_glue_crawler" "bank_crawler" {
  database_name = aws_glue_catalog_database.bank_db.name
  name          = "bank_crawler"
  role          = aws_iam_role.glue-role.arn

  jdbc_target {
    connection_name = aws_glue_connection.bank_conn.name
    path            = "banks/%"
  }
}
##################
# Glue Job       #
##################
resource "aws_glue_job" "read_tables_into_s3" {
  name        = "read_tables_into_s3"
  role_arn    = aws_iam_role.glue-role.arn
  description = "Reads each table of bank database into target s3 bucket"
  connections = [aws_glue_connection.bank_conn.arn]


  command {
    script_location = "s3//${aws_s3_bucket.crawlresults.bucket}/etl.py"
  }
  default_arguments = {
    "--JOB_NAME"                         = "load_tables_into_s3_job"
    "--CATALOG_DATABASE"                 = aws_glue_catalog_database.bank_db.name
    "--CATALOG_TABLE"                    = "Loans"
    "--TARGET_BUCKET"                    = aws_s3_bucket.crawlresults.bucket
    "--continuous-log-logGroup"          = aws_cloudwatch_log_group.banklogger.name
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-continuous-log-filter"     = "true"
  }
}
