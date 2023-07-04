##################
# S3 Bucket      #
##################

resource "aws_s3_bucket" "playground_s3_bucket" {
  bucket = "${var.prefix}-playgroundtf123-${var.env}"
  lifecycle {
    prevent_destroy = false
  }
}

##################
# IAM            #
##################

data "aws_iam_policy_document" "glue_policy_document" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["glue.amazonaws.com"]
      type        = "Service"
    }
  }
}

data "aws_iam_policy_document" "crawler_policy_document" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["ec2.amazonaws.com"]
      type        = "Service"
    }
  }
}

data "aws_iam_policy_document" "s3_policy_document" {
  statement {
    effect  = "Allow"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.playground_s3_bucket.arn,
      "${aws_s3_bucket.playground_s3_bucket.arn}/*"
    ]
  }
}

resource "aws_iam_role" "glue_service_role" {
  name               = "${var.prefix}-glue-service-role-${var.env}"
  assume_role_policy = data.aws_iam_policy_document.glue_policy_document.json
}

resource "aws_iam_role_policy_attachment" "glue_service_role_policy_attachment" {
    role = aws_iam_role.glue_service_role.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_service_role_policy" {
  name   = "${var.prefix}-glue-service-role-policy-${var.env}"
  policy = data.aws_iam_policy_document.s3_policy_document.json
  role   = aws_iam_role.glue_service_role.id
}

resource "aws_iam_role_policy" "crawler_role_policy" {
  name = "crawler-role-policy"
  role = aws_iam_role.crawler_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Action = [
                "glue:GetConnection",
                "glue:GetConnections",
                "ec2:DescribeSubnets",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeVpcEndpoints",
                "ec2:DescribeRouteTables",
                "logs:PutLogEvents",
                "logs:CreateLogStream",
                "s3:GetObject",
                "s3:PutObject",
                "glue:GetConnection",
                "glue:StartCrawler",
                "glue:StopCrawler",
                "glue:CreateCrawler",
                "glue:DeleteCrawler",
                "glue:GetCrawler",
                "glue:UpdateCrawler",
                "glue:GetCrawlerMetrics"
                ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role" "crawler_role" {
  name               = "${var.prefix}-glue-crawler-role-${var.env}"
  assume_role_policy = data.aws_iam_policy_document.crawler_policy_document.json
}

##################
# Glue Catalog   #
##################

resource "aws_glue_catalog_database" "my_catalog_database" {
  name = "my_catalog_database"
}

##################
# Glue Connection#
##################

resource "aws_glue_connection" "aurora_connection" {
  connection_properties = {
    JDBC_CONNECTION_URL = "jdbc:postgresql://mycluster.cluster-123456789012.us-east-1.rds.amazonaws.com:5432/mydatabase", 
    PASSWORD            = "5Y67bg#r#"
    USERNAME            = "postgres"
  }

  name = "aurora-connection"
}

##################
# Glue Crawler   #
##################

resource "aws_glue_crawler" "my_glue_crawler" {
  database_name = aws_glue_catalog_database.my_catalog_database.name
  name          = "my-glue-crawler"
  role          = aws_iam_role.crawler_role.arn

    jdbc_target {
        connection_name = aws_glue_connection.aurora_connection.name
        path            = "mydatabase/%"
        exclusions      = []
    }
}

##################
# Glue Job       #
##################

resource "aws_glue_job" "my_glue_job" {
  name     = "my-glue-job"
  role_arn = "${aws_iam_role.glue_service_role.arn}"
  glue_version = "3.0"
  number_of_workers = 2
  worker_type = "G.1X"
  max_retries = "1"
  timeout = 2880

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.playground_s3_bucket.bucket}/glue-jobs/example.py"
    python_version  = "3"
  }

  default_arguments = {
    "--enable-auto-scaling" = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-job-insights" = "true",
    "--library-set" = "analytics",
  }
}
