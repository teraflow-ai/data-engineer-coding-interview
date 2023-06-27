## Developed by : Marli van der Merwe
## Description: Variables used by main.tf

#AWS ACCESS
region = "us-east-1"
# access_key_id = "test123456"
# secret_key = "123456test"

#AWS SUBCRIPTION EMAIL
email = "data-support@mybigbank.co.za"

##AWS GLUE CONNECTION
connection_url = "jdbc:postgresql://mycluster.cluster-123456789012.us-east-1.rds.amazonaws.com:5432"
# password = "5Y67bg#r#"
username = "postgres"
#aurorapath = "database/schema%" 

#ADDITIONAL AWS GLUE PARAMETERS
glue_catalog_db = "marli-terraform-database"
glue_aurora_jdbc_url = "jdbc:postgresql://bi-datalab-instance.cyc0tmf63pu6.eu-west-1.rds.amazonaws.com:5432/datalab"
# glue_aurora_schema = "schema"
glue_aurora_user = "pgadmin"
# glue_aurora_password = "5Y67bg#r#"
glue_s3_directory = "moving_ave_outputs/"

#AWS TAG
tag_team = "Teraflow.ai"