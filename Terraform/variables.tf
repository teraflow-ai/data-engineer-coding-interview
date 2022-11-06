########################################################################
# Variable Definition for Big Bank AWS Infrastructure                  #
########################################################################

##################
# DB Credentials #
##################
# Sensitive parameters to be secured

variable "aurora_db_connection_hostname" {
  description = "The hostname to form pat of the JDBC connection string for the operational Aurora database"
  type        = string
  sensitive   = true
}

variable "aurora_db_username" {
  description = "The username for the operational Aurora database"
  type        = string
  sensitive   = true
}

variable "aurora_db_password" {
  description = "The password for the operational Aurora database"
  type        = string
  sensitive   = true
}

variable "aurora_db_database_name" {
  description = "The Aurora database in which the tables of interest are stored"
  type        = string
  sensitive   = true
}

##################
# Global Tags    #
##################
variable "environment" {
    description = "The deployment environment being used"
    type        = string
}

variable "client" {
    description = "The client for which infrastructure is being deployed"
    type        = string
}

##################
# Configuration  #
##################

#S3
variable "s3_bucket_name_results" {
  description = "The name of the S3 bucket to extract data to"
  type        = string
}

variable "s3_bucket_name_glue_scripts" {
  description = "The name of the S3 bucket to store glue ETL scripts in"
  type        = string
}


#Glue 
variable "glue_db_name_big_bank_aurora" {
  description = "The name of the glue database to store Aurora source system metadata"
  type        = string
}

variable "glue_crawler_name_big_bank_aurora" {
  description = "The name of the glue crawler to scan Aurora for bank loan information"
  type        = string
}

variable "glue_job_name_monthly_loan_value" {
  description = "The name of the glue crawler to scan Aurora for bank loan information"
  type        = string
}
