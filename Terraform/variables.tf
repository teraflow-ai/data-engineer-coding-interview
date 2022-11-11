# DB Credientials

variable "connection_hostname" {
  description = "Connection hostname establishes the connection string to connect to the database"
  type      = string
  sensitive = true
  default   = "mycluster.cluster-123456789012.us-east-1.rds.amazonaws.com"
}

variable "user_name" {
    description = "Username to the database"
    type      = string
    sensitive = true
    default   = "postgres" 
}

variable "password" {
    description = "Password to the database"
    type      = string
    sensitive = true
    default   = "5Y67bg#r#"
} 

variable "database_name" {
    description = "Database name to access the database in the cluster"
    type      = string
    sensitive = true
    default   = "bankdb"
}

variable "port" {
  
   description = "Database port number"
    type      = string
    sensitive = true
    default   = "5432"
}

variable "connection_name" {
  description = "Database name to access the database in the cluster"
    type      = string

  default= "db_glue_connection"
}


# S3 Bucket valriables

variable "s3_bucket_data" {
    description = "S3 bucket to store data"
    type      = string
    default   = "data"
}
variable "s3_bucket_glue_scripts" {
    description = "S3 bucket to house glue scripts"
    type      = string
    default   = "glue" 
}

# variable "s3_bucket_glue_etl" {
#         description = "The name of the S3 bucket to store glue ETL scripts in"

#     type    = string
#     default = "glue-etl"
# }

# Crawler variables
variable "glue_bank_db_catalog" {
  description = "Glue database to persist metadata"
  type        = string
  default = "bank_db_catalog"
}

variable "glue_crawler_bank_db" {
  description = "Glue crawler to crawl bank db"
  type        = string
  default = "bank_db_crawler"
}


