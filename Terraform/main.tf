##################
# Glue Catalog   #
##################
provider "aws" {
  region = "eu-west-1" 
}

resource "aws_glue_catalog_database" "blahblahBase" {
  name = "BankDtl"  
}

resource "aws_s3_bucket" "output_bucket" {
  bucket = "file_dump" 
  acl    = "private"                

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}


##################
# Glue Crawler   #
##################
provider "aws" {
  region = "eu-west-1"  
}

resource "aws_glue_crawler" "example_crawler" {
  name = "example_crawler"  # Replace with your preferred crawler name
  role = aws_iam_role.example_glue_crawler.arn
  database_name = aws_glue_catalog_database.example_db.name
  targets {
    s3_targets {
      path = "s3://your-bucket-name/crawler-output/"  # Replace with your S3 bucket path for crawler output
    }
  }
  schedule {
    schedule_expression = "cron(0 0 * * ? *)"  # Replace with your desired crawler schedule (e.g., daily at midnight)
  }
  configuration = <<EOF
    {
      "Version": 1.0,
      "CrawlerOutput": {
        "Partitions": { "AddOrUpdateBehavior": "InheritFromTable" }
      }
    }
  EOF
}

resource "aws_iam_role" "example_glue_crawler" {
  name = "example_glue_crawler_role"  # Replace with your preferred role name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "example_glue_crawler_attachment" {
  name = "example_glue_crawler_attachment"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"  
  roles = [aws_iam_role.example_glue_crawler.name]
}
##################
# Glue Job       #
##################

provider "aws" {
  region = "eu-west-1" 
}

# Create an AWS Glue job
resource "aws_glue_job" "etl_job" {
  name         = "my-kryptonite-etl-job"
  role_arn     = "arn:aws:iam::123456789012:role/glue-role"  # Change to your Glue job IAM role ARN
  command {
    name        = "glueetl"
    script_location = "s3://file_dump/scripts/etl.py" 
  }

}

# Create a CloudWatch event rule to schedule the Glue job daily at 4 AM UTC
resource "aws_cloudwatch_event_rule" "schedule_rule" {
  name        = "glue-job-schedule-rule"
  description = "Schedule Glue job daily at 4 AM UTC"
  schedule_expression = "cron(0 4 * * ? *)" 
}

# Associate the CloudWatch event rule with the Glue job
resource "aws_cloudwatch_event_target" "target" {
  rule      = aws_cloudwatch_event_rule.schedule_rule.name
  target_id = "target-glue-job"
  arn       = aws_glue_job.etl_job.arn
}

# Give permissions to the CloudWatch event rule to invoke the Glue job
resource "aws_lambda_permission" "permission" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_glue_job.etl_job.arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule_rule.arn
}