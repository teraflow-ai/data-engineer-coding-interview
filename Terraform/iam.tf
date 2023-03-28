# Create service role to allow Glue to access RDS
resource "aws_iam_role" "glue_rds_service_role" {
  assume_role_policy = ""
}