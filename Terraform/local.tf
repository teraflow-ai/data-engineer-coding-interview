locals {

  rds_cluster_az = data.aws_db_instance.banks.availability_zone
  rds_jdbc_url   = "jdbc:postgresql://${data.aws_db_instance.banks.endpoint}/${var.database_name}"
  rds_username   = jsondecode(data.aws_secretsmanager_secret_version.banks_credentials.secret_string)["username"]
  rds_pwd        = jsondecode(data.aws_secretsmanager_secret_version.banks_credentials.secret_string)["password"]

  # Find the private Subnet linked to the AZ where the DB instance is running from
  rds_subnet_ids     = data.aws_subnet.rds_primary_subnet
  rds_az_subnets     = [for v in local.rds_subnet_ids : v if v.availability_zone == local.rds_cluster_az && v.map_public_ip_on_launch == true]
  rds_primary_subnet = local.rds_az_subnets[0].id
}