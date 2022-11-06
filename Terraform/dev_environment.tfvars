########################################################################
# Variable Assignment for Development Environment                      #
########################################################################

##################
# Global Tags    #
##################
environment = "Development"

client = "Big Bank"

##################
# Configuration  #
##################

#S3
s3_bucket_name_results = "big_bank_aurora_analytics_dev"

s3_bucket_name_glue_scripts = "big_bank_glue_scripts_dev"

#Glue
glue_db_name_big_bank_aurora = "big_bank_aurora_ods"

glue_crawler_name_big_bank_aurora = "big_bank_aurora_crawler"

glue_job_name_monthly_loan_value = "big_bank_aurora_to_s3_monthly_loan_value"
