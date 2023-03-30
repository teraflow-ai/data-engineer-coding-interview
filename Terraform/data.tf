# Lookup the RDS cluster
data "aws_rds_cluster" "clusterName" {
  cluster_identifier = var.rds_cluster_identifier
}

# Lookup the VPC
data "aws_vpc" "vpc_banks"{
  id = var.vpc_id
}

# List the subnets for a given vpc_id
data "aws_subnet_ids" "vpc_banks_subnets" {
  vpc_id = var.vpc_id
}

data "aws_subnet" "vpc_banks_subnet" {
  for_each = data.aws_subnet_ids.vpc_banks_subnets.ids
  id       = each.value
}