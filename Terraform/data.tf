# Info on the AWS account where the resources will be created
data "aws_caller_identity" "current" {}

# Lookup the VPC
data "aws_vpc" "vpc_banks"{
  id = var.vpc_id
}

# List the subnets for a given vpc_id
data "aws_subnets" "vpc_subnets" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
}

# Get a list of subnets used by the VPC where the RDS cluster is deployed
data "aws_subnet" "vpc_subnet_banks" {
  for_each = toset(data.aws_subnets.vpc_subnets.ids)
  id       = each.value
}

# lookup RDS cluster
data "aws_rds_cluster" "banks" {
  cluster_identifier = var.rds_cluster_identifier
}

# lookup RDS database aws_db_instance
data "aws_db_instance" "banks" {
  db_instance_identifier = "my-test-database"
}

data "aws_subnet" "subnet_id" {
  filter {
    name   = "subnet-id"
    values = [data.aws_rds_cluster.banks.db_subnet_group_name]
  }
}

# Secrets Manager Secrets
data "aws_secretsmanager_secret" "by_name_rds_credentials" {
  name = var.secrets_manager_secret_name
}

data "aws_secretsmanager_secret_version" "banks_credentials" {
  secret_id = data.aws_secretsmanager_secret.by_name_rds_credentials.id
}

