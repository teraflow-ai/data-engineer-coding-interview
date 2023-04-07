resource "aws_s3_object" "upload_etl_script" {
  bucket = "aws-glue-assets-953443259787-eu-west-1"
  key    = var.glue_etl_script_obj_key
  source = "${path.cwd}/../Glue/etl.py"

}