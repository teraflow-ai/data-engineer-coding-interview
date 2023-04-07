#######################################################
# IAM Policy to allow Secrets Manager access
#######################################################
resource "aws_iam_policy" "glue_secrets_manager_access" {
  name        = "glue_secrets_manager_access"
  path        = "/"
  description = "Policy used by Glue to access Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecretVersionIds"
        ]
        Effect = "Allow"
        Resource = "arn:aws:secretsmanager:*:${data.aws_caller_identity.current.account_id}:secret:${var.secrets_manager_secret_name}*"
      }
    ]
  })
}

#######################################################
# IAM Policy to allow RDS access via IAM
#######################################################
resource "aws_iam_policy" "glue_rds_access" {
  name        = "glue_rds_access"
  path        = "/"
  description = "Policy allowing a database user RDS access via IAM"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "rds-db:connect"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:rds-db:*:${data.aws_caller_identity.current.account_id}:dbuser:${data.aws_db_instance.banks.db_instance_identifier}/${local.rds_username}"
      }
    ]
  })
}

resource "aws_iam_role" "glue_service_linked_role" {

  name = "glue-service-linked-role"

  description = "Glue service-linked role to interact with RDS, S3 and Secrets Manager"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })
}

#################################
# Add postgres user as IAM user
#################################
resource "aws_iam_user" "rds_user" {
  name = local.rds_username
}

######################################
# Attach Secrets Manager permissions
######################################
resource "aws_iam_role_policy_attachment" "glue_secrets_manager_permission" {
  role       = aws_iam_role.glue_service_linked_role.name
  policy_arn = aws_iam_policy.glue_secrets_manager_access.arn
}

######################################
# Attach RDS IAM permissions
######################################
resource "aws_iam_user_policy_attachment" "glue_rds_user_iam_access_permission" {
  policy_arn = aws_iam_policy.glue_rds_access.arn
  user       = aws_iam_user.rds_user.name
}

######################################
# Attach RDS IAM permissions
######################################
resource "aws_iam_role_policy_attachment" "glue_aws_etl_service_permission" {
  role       = aws_iam_role.glue_service_linked_role.name
  policy_arn = aws_iam_policy.glue_etl_access.arn
}

#######################################
# Glue Job permissions to perform ETL
#######################################
resource "aws_iam_policy" "glue_etl_access" {
  name        = "glue_s3_etl_script_access"
  path        = "/"
  description = "Allow AWS Glue access to make API calls to s3, iam, cloudwatch, logs and ec2"

  policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
          {
            Effect = "Allow"
            Action = [
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
              "cloudwatch:PutMetricData"
            ]
            Resource = [
              "*"
            ]
          },
          {
            Effect = "Allow"
            Action = [
              "s3:GetObject",
              "s3:PutObject",
              "s3:DeleteObject"
            ]
            Resource = "arn:aws:s3:::${var.glue_etl_bucket_name}/*"
          },
          {
            Effect = "Allow"
            Action = [
              "logs:CreateLogGroup",
              "logs:CreateLogStream",
              "logs:PutLogEvents"
            ]
            Resource = [
              "arn:aws:logs:*:*:/aws-glue/*"
            ]
          },
          {
            Effect = "Allow"
            Action= [
              "ec2:CreateTags",
              "ec2:DeleteTags"
            ]

            Resource = [
              "arn:aws:ec2:*:*:network-interface/*",
              "arn:aws:ec2:*:*:security-group/*",
              "arn:aws:ec2:*:*:instance/*"
            ]
          }

    ]
  })
}