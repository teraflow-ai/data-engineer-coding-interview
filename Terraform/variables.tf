|----------------------|
| Database Credentials |
|----------------------|
variable "hostname" {
  type      = string
  sensitive = true
  default   = "mycluster.cluster-123456789012.us-east-1.rds.amazonaws.com"
}

variable "username" {
  type      = string
  sensitive = true
  default   = "postgres" 
}

variable "password" {
  type      = string
  sensitive = true
  default   = "5Y67bg#r#"
}

|----------------------|
| S3 bucket names      |
|----------------------|
variable "s3_data_bucket_name" {
  type      = string
  default   = "data"
}

variable "s3_glue_bucket_name" {
  type      = string
  default   = "glue" 
}

variable "s3_root_bucket_name" {
    type    = string
    default = "glue-etl"
}

|----------------------|
| Glue Crawler         |
|----------------------|

