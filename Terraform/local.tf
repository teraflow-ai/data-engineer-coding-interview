locals {

  rds_cluster_az = data.aws_rds_cluster.banks.availability_zones
  rds_jdbc_url = "jdbc:postgresql://${data.aws_rds_cluster.banks.endpoint}/${var.database_name}"
  rds_username = jsondecode(data.aws_secretsmanager_secret_version.banks_credentials.secret_string)["username"]
  rds_pwd = jsondecode(data.aws_secretsmanager_secret_version.banks_credentials.secret_string)["password"]
}