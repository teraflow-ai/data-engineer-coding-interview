##################
# Glue Catalog   #
##################
resource "aws_glue_catalog_database" "banks_catalog_database" {
  name = var.glue_catalog_db_name
}

##################
# Glue Crawler   #
##################
resource "aws_glue_crawler" "monthly_loan_amounts" {
  database_name = var.database_name
  name          = var.glue_crawler_name
  role          = aws_iam_role.glue-service-linked-role.arn

  jdbc_target {
    connection_name = aws_glue_connection.rds_jdbc_connection.name
    path            = var.jdbc_target_path
  }
}

##########################
# Glue JDBC Connection   #
##########################
resource "aws_glue_connection" "rds_jdbc_connection" {
  connection_properties = {
    JDBC_CONNECTION_URL = local.rds_jdbc_url
    PASSWORD            = local.rds_pwd
    USERNAME            = local.rds_username
  }

  description = "Glue JDBC connection"

  name = "rds_jdbc_connection"

  physical_connection_requirements {
    availability_zone      = local.rds_cluster_az
    security_group_id_list = data.aws_rds_cluster.banks.db_subnet_group_name
    subnet_id              = data.aws_subnet.subnet_id.id
  }

}

##################
# Glue Job       #
##################

