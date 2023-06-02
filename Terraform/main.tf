# The AWS Secrets Manager retrieval

data "aws_secretsmanager_secret_version" "creds" {
  secret_id = "bank-creds"
}

locals {
  creds = jsondecode(
    data.aws_secretsmanager_secret_version.creds.secret_string
  )
}

# example retrieval username= local.db_creds.username

##################
# Glue Catalog   #
##################

##################
# Glue Crawler   #
##################

##################
# Glue Job       #
##################

