# Create service role to allow Glue to access RDS
resource "aws_iam_policy" "glue-service-linked-role-policy" {
  name        = "glue_service_linked_role_permissions"
  path        = "/"
  description = "Policy used by Glue Service-linked role to access RDS, S3 and Secrets Manager"

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
        Resource = "arn:aws:secretsmanager:*:${data.aws_caller_identity.current.account_id}:secret:${secrets_manager_secret_name}"
      },
      {
        Action = [
          "s3:List*",
          "s3:Get*"
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:s3:::${var.s3_etl_bucket_name}/",
          "arn:aws:s3:::${var.s3_etl_bucket_name}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "glue-rds-iam-connect-policy" {
  name        = "glue_service_linked_role_permissions"
  path        = "/"
  description = "Policy allowing a user RDS access via IAM"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "rds-db:connect",
        ]
        Effect   = "Allow"
        Resource = "arn:aws:rds-db:*:${data.aws_caller_identity.current.account_id}:dbuser:${data.aws_db_instance.banks.db_instance_identifier}/${local.rds_username}"
      }
    ]
  })
}

resource "aws_iam_role" "glue-service-linked-role" {
  name = "glue-service-linked-role"

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
      },
    ]
  })
}

resource "aws_iam_policy_attachment" "glue_service_linked_role_policy_attach" {
  name       = aws_iam_role.glue-service-linked-role.name
  policy_arn = aws_iam_policy.glue-service-linked-role-policy.arn
}

resource "aws_iam_user" "rds_user" {
  name = local.rds_username
}

resource "aws_iam_user_policy_attachment" "rds_user_iam_access" {
  policy_arn = aws_iam_policy.glue-rds-iam-connect-policy.arn
  user       = aws_iam_user.rds_user.name
}