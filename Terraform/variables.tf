variable "database_name" {
  description = "The RDS database name"
  type        = string
}

variable "jdbc_target_path" {
  description = "The Glue crawler's jdbc target path"
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

variable "s3_etl_bucket_name" {
  description = "The name of the S3 bucket where scripts and data is stored"
  type        = string
}

