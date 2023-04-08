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
  database_name = var.db_name
  name          = var.glue_crawler_name
  role          = aws_iam_role.glue_service_linked_role.name

  jdbc_target {
    connection_name = aws_glue_connection.rds_jdbc_connection.name
    path            = "${var.db_schema_name}/${var.db_name}/Account"
  }

  jdbc_target {
    connection_name = aws_glue_connection.rds_jdbc_connection.name
    path            = "${var.db_schema_name}/${var.db_name}/Branch"
  }

  jdbc_target {
    connection_name = aws_glue_connection.rds_jdbc_connection.name
    path            = "${var.db_schema_name}/${var.db_name}/Client"
  }

  jdbc_target {
    connection_name = aws_glue_connection.rds_jdbc_connection.name
    path            = "${var.db_schema_name}/${var.db_name}/Loans"
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
    JDBC_CONNECTION_URL              = local.rds_jdbc_url
    PASSWORD                         = local.rds_pwd
    USERNAME                         = local.rds_username
    JDBC_ENFORCE_SSL                 = true
    CUSTOM_JDBC_CERT                 = var.glue_ssl_cert_s3_location
    SKIP_CUSTOM_JDBC_CERT_VALIDATION = true
    CUSTOM_JDBC_CERT_STRING          = "Amazon RDS eu-west-1 2019 CA"
  }

  description = "Glue RDS(postgres) JDBC connection"

  name = "rds_jdbc_connection"

  physical_connection_requirements {
    availability_zone      = local.rds_cluster_az
    security_group_id_list = data.aws_db_instance.banks.vpc_security_groups
    subnet_id              = local.rds_primary_subnet
  }

}

##################
# Glue Job       #
##################
resource "aws_glue_job" "banks_3_month_moving_avg" {
  name     = "banks_3_month_moving_avg"
  role_arn = aws_iam_role.glue_service_linked_role.arn

  command {
    script_location = "s3://${var.glue_etl_bucket_name}${var.glue_etl_script_obj_key}"
  }

  glue_version = "3.0"

}

