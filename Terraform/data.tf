# Info on the AWS account where the resources will be created
data "aws_caller_identity" "current" {}

#############################
# Availability Zone info
#############################
data "aws_availability_zones" "rds_cluster_az" {
  filter {
    name   = "group-name"
    values = [local.rds_cluster_az]
  }
}

#############################
# VPC info
#############################
data "aws_vpc" "vpc_banks" {
  id = var.vpc_id
}



# List the subnets for a given vpc_id
data "aws_subnets" "rds_cluster_subnets" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
}

data "aws_subnet" "rds_primary_subnet" {

  for_each = toset(data.aws_subnets.rds_cluster_subnets.ids)
  id       = each.value

}


################################################################
# lookup RDS database aws_db_instance
data "aws_db_instance" "banks" {
  db_instance_identifier = var.db_instance_identifier
}

data "aws_db_subnet_group" "database" {
  name = data.aws_db_instance.banks.db_subnet_group
}

# Secrets Manager Secrets
data "aws_secretsmanager_secret" "by_name_rds_credentials" {
  name = var.secrets_manager_secret_name
}

data "aws_secretsmanager_secret_version" "banks_credentials" {
  secret_id = data.aws_secretsmanager_secret.by_name_rds_credentials.id
}
