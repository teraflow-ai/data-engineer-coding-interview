variable "db_name" {
  description = "The RDS database name"
  type        = string
}

variable "db_schema_name" {
  description = "The schema to use within the RDS database"
  type        = string
}

variable "db_instance_identifier" {
  description = "RDS databse instance identifier"
  type        = string
}

variable "vpc_id" {
  description = "The id of the VPC to use"
  type        = string
}

variable "secrets_manager_secret_name" {
  description = "The name of the secret in Secrets Manager"
  type        = string
}

variable "glue_catalog_db_name" {
  description = "The database name in the Glue catalog"
}

variable "glue_crawler_name" {
  description = "The Glue crawler name"
  type        = string
}

variable "glue_ssl_cert_s3_location" {
  description = "The SSL certificate the Glue connection must use when communicating with the RDS database"
  type        = string
}

variable "glue_etl_bucket_name" {
  description = "The name of the S3 bucket where scripts and data is stored"
  type        = string
}

variable "glue_etl_script_name" {
  description = "The pyspark ETL script to perform the aggregation of the data"
}