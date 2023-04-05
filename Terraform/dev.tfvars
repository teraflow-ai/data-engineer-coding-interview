vpc_id                      = "vpc-aae401d3"
database_name               = "postgres"
db_instance_identifier      = "database-1"
jdbc_target_path            = "postgres/%"
secrets_manager_secret_name = "rds_glue"
glue_catalog_db_name        = "banks"
glue_crawler_name           = "banks_monthly"
glue_ssl_cert_s3_location   = "s3://milliondolla-dl/rds-ca-2019-eu-west-1.pem"
s3_etl_bucket_name          = ""
