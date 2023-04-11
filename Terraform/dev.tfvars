vpc_id                                = "vpc-aae401d3"
db_name                               = "postgres"
db_schema_name                        = "public"
db_instance_identifier                = "database-1"
secrets_manager_secret_name           = "rds_glue"
glue_catalog_db_name                  = "banks"
glue_crawler_name                     = "banks_monthly"
glue_ssl_cert_s3_location             = "s3://milliondolla-dl/rds-ca-2019-eu-west-1.pem"
glue_etl_bucket_name                  = "aws-glue-assets-953443259787-eu-west-1"
glue_etl_script_obj_key               = "scripts/etl.py"
glue_dl_bucket_name                   = "milliondolla-learn-euw1"
glue_dl_branch_montly_loan_totals_key = "/data/branch_monthly_loan_total"