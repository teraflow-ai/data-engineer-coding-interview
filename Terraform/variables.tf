#=================Setting up an environment for the application =================
variable "aws_region" {
    default =  "eu-west-1"
}
variable "aws_access_key" {
    default = "AWSXXXXXX0978"
}
variable "aws_secret_access_key" {
    default = "AULP0XXXXXXY7US9XXXXOP56JX"
}


# ========= Define Job language========
variable "job-language" {
    default = "python"
}
#=========Variableas for Glue Crawler======

variable "crawler_name" {
    default = "jdbc_crawler"
  
}
variable "db" {
    default = "ODS_db"
}
variable "crawler_role" {
    default = "arn:aws:iam::709880522225:role/ADFS-DMDEVReadOnly"
}
variable "connection_name" {
    default = "postgres"
}
variable "PG_PASSWORD" {
    default = "5Y67bg#r#"
}
variable "PG_USERNAME" {
    default = "postgres"
}
variable "jdbc_path" {
    default = " mycluster.cluster-123456789012.us-east-1.rds.amazonaws.com"
}

#======= Glue Job

variable "glue_job_role_arn" {
    default = "arn:aws:iam::709880522225:role/AWSGLUE"
}
variable "glue-job-name" {
    default = "execute python script"
}
variable "bucket_name" {
  default = "script_bucket"
}
variable "script-file-name" {
    default = "etl.py"
}

#========Glue catalog






#========s3 bucket

variable "bucket_name" {
    default = "my_bucket_name"
}

variable "acl_value" {

    default = "private"

}