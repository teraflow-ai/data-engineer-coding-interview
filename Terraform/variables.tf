variable "database_name" {
  description = "The RDS database name"
  type = string
}

variable "jdbc_target_path" {
  description = "The path of the jdbc target"
  type = string
}

variable "rds_cluster_identifier" {
  description = "The RDS Cluster identifier"
  type = string
}

variable "vpc_id" {
  description = "The id of the VPC to use"
  type = string
}