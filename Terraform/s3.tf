######################################
# Upload ETL script to S3 location
######################################
resource "aws_s3_object" "upload_etl_script" {
  bucket = var.glue_etl_bucket_name
  key    = var.glue_etl_script_obj_key
  source = "${path.cwd}/../Glue/etl.py"
}

#########################################################
# Seed some data for moving averages on loans per branch
#########################################################
resource "aws_s3_object" "upload_seed_data" {
  bucket = var.glue_dl_bucket_name
  key    = "${var.glue_dl_branch_montly_loan_totals_key}/processed_date=${formatdate("YYYY-MM-DD", timestamp())}/seed.csv"
  source = "${path.cwd}/../seed/branch_monthly_loan_total.csv"
}

