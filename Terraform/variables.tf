variable "source_db_host_name" {
  type        = string
  sensitive   = true
}

variable "source_db_username" {
  type        = string
  sensitive   = true
}

variable "source_db_password" {
  type        = string
  sensitive   = true
}

variable "source_db_name" {
  type        = string
  sensitive   = true
}

variable "db_name_glue" {
  type        = string
}

variable "s3_glue_job" {
  type        = string
}


variable "s3_glue_data_output" {
  type        = string
}