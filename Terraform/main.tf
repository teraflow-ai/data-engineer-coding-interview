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

  depends_on = [
    aws_glue_connection.rds_jdbc_connection,
    aws_glue_catalog_database.banks_catalog_database
  ]
}

##########################
# Glue JDBC Connection   #
##########################
resource "aws_glue_connection" "rds_jdbc_connection" {
  connection_properties = {
    JDBC_CONNECTION_URL = local.rds_jdbc_url
    PASSWORD            = local.rds_pwd
    USERNAME            = local.rds_username
    JDBC_ENFORCE_SSL    = true
    CUSTOM_JDBC_CERT    = var.glue_ssl_cert_s3_location
    SKIP_CUSTOM_JDBC_CERT_VALIDATION = true
    CUSTOM_JDBC_CERT_STRING = "Amazon RDS eu-west-1 2019 CA"
  }

  description = "Glue RDS(postgres) JDBC connection"

  name = "rds_jdbc_connection"

  physical_connection_requirements {
    availability_zone      = local.rds_cluster_az
    security_group_id_list = data.aws_db_instance.banks.db_security_groups
    subnet_id                 = local.rds_primary_subnet
  }

}

#resource "aws_glue_" "" {}

##################
# Glue Job       #
##################

