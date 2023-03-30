##################
# Glue Catalog   #
##################
resource "aws_glue_catalog_database" "banks_catalog_database" {
  name = "Banks"
}

##################
# Glue Crawler   #
##################
resource "aws_glue_crawler" "monthly_loan_amounts" {
  database_name = var.database_name
  name          = "monthly_loan_amounts"
  role          = aws_iam_role.glue_rds_service_role.arn

  jdbc_target {
    connection_name = aws_glue_connection.monthly_loan_amounts_conn.name
    path            = var.jdbc_target_path
  }
}

resource "aws_glue_connection" "monthly_loan_amounts_conn" {
  name = "monthly_loan_amounts_conn"
}


##################
# Glue Job       #
##################

