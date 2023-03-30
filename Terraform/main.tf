##################
# Glue Catalog   #
##################
resource "aws_glue_catalog_database" "banks_catalog_database" {
  name = "banks"
}

##################
# Glue Crawler   #
##################
resource "aws_glue_crawler" "monthly_loan_amounts" {
  database_name = var.database_name
  name          = "monthly_loan_amounts"
  role          = aws_iam_role.glue_rds_service_role.arn

  jdbc_target {
#    connection_name = aws_glue_connection.rds_jdbc_connection.name
    connection_name = "test"
    path            = var.jdbc_target_path
  }
}

##########################
# Glue JDBC Connection   #
##########################
#resource "aws_glue_connection" "rds_jdbc_connection" {
#  connection_properties = {
#    JDBC_CONNECTION_URL = "jdbc:mysql://${data.aws_rds_cluster.clusterName.endpoint}/${var.database_name}"
#    PASSWORD            = "examplepassword"
#    USERNAME            = "exampleusername"
#  }
#
#  name = "rds_jdbc_connection"
#
#  physical_connection_requirements {
#    availability_zone      = data.aws_vpc.vpc_banks.s#aws_subnet.example.availability_zone
#    security_group_id_list = [aws_security_group.example.id]
#    subnet_id              = aws_subnet.example.id
#  }
#}

##################
# Glue Job       #
##################

