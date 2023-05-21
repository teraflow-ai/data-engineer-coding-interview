#af-south-1 cuz local is lekker
provider "aws" {
  region = "af-south-1"
}

data "aws_vpc" "main" {
  id = "vpc-c322c7aa" # my personal VPC
}


variable "email_endpoint" {
  description = "Email address to receive Glue job failure notifications"
  type        = string
  default     = "riaana@mundane.co.za" # my personal email
}

# Some extra vars in order to meet the spec
variable "client_aurora_endpoint" {
  description = "The client's aurora cluster"
  type        = string
  default     = "mycluster.cluster-123456789012.us-east-1.rds.amazonaws.com"
}

##################
# Aurora Cluster #
##################
# I know I didn't have to make an aurora cluster of my own, but if I don't, how will I know if my etl script works?
# I have left the terraform pertaining to the cluster in here. But I have commented it out, because we're using the client cluster 
# as part of the scope of work


# Let's rather use a secret that's not in the code... 
# right now it contains something else, but to make this "work" with the client's aurora cluster, 
# this secret would have to get updated to contain the value `5Y67bg#r#`
data "aws_secretsmanager_secret" "aurora_master_password" {
  name = "aurora_master_password"
}



# This was used to instantiate the passwords. But the above stanza has been changed to "data" so that I don't have to worry about
# destroying it all the time (by accident mostly...)

# How we made up the password
resource "random_password" "aurora_master_password" {
  length           = 16
  special          = true
  override_special = "!@#$%^&*()_+-="
}

resource "aws_secretsmanager_secret_version" "aurora_master_password" {
  secret_id     = data.aws_secretsmanager_secret.aurora_master_password.id
  secret_string = random_password.aurora_master_password.result
}

# # TODO:
# # The security group(s) need some more thought/ splitting up. 
resource "aws_security_group" "aurora_sg" {
  name        = "aurora-access"
  description = "Allow access to Aurora from specific IP"
  
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["196.209.244.241/32"]
    description = "Access from Riaan Home"
  }
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All TCP"
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}


# resource "aws_rds_cluster" "aurora_cluster" {
#   cluster_identifier            = "coding-interview-aurora"
#   engine                        = "aurora-postgresql"
#   engine_mode                   = "provisioned"
#   engine_version                = "13.10" #Interestingly, the glue crawler does not like 14.6...
#   availability_zones            = ["af-south-1a","af-south-1b","af-south-1c"]
#   database_name                 = "mydatabase"
#   master_username               = "postgres"
#   master_password               = aws_secretsmanager_secret_version.aurora_master_password.secret_string
#   preferred_backup_window       = "07:00-09:00"
#   backup_retention_period       = 1
#   preferred_maintenance_window  = "mon:03:00-mon:04:00"
#   deletion_protection           = false
#   skip_final_snapshot           = true
#   vpc_security_group_ids        = [aws_security_group.aurora_sg.id]

#   serverlessv2_scaling_configuration {
#     max_capacity = 1.0
#     min_capacity = 0.5
#   }
# }


# resource "aws_rds_cluster_instance" "aurora_instance" {
#   cluster_identifier    = aws_rds_cluster.aurora_cluster.id
#   publicly_accessible   = true
#   instance_class        = "db.t3.medium"
#   engine                = aws_rds_cluster.aurora_cluster.engine
#   engine_version        = aws_rds_cluster.aurora_cluster.engine_version
#   identifier            = "coding-interview-aurora-instance"
# }


##################
# Glue Catalog   #
##################
resource "aws_glue_catalog_database" "coding_interview_database" {
  name = "coding_interview_glue_database"
}

resource "aws_glue_connection" "aurora_connection" {
  name              = "coding_interview_aurora_connection"
  physical_connection_requirements {
    availability_zone      = "af-south-1a"
    security_group_id_list = [aws_security_group.aurora_sg.id] # this SG is still configured as if it's _our_ aurora cluster. But the values are pretty similar
    subnet_id              = "subnet-10d93c79"
  }
  connection_properties = {
    USERNAME            = "postgres",
    PASSWORD            = "${aws_secretsmanager_secret_version.aurora_master_password.secret_string}",
    #JDBC_CONNECTION_URL = "jdbc:postgresql://${aws_rds_cluster.aurora_cluster.endpoint}:5432/mydatabase",
    JDBC_CONNECTION_URL = "jdbc:postgresql://${var.client_aurora_endpoint}:5432/mydatabase", 
    #The requirement doesn't explicitly state the database name, so I'm just leaving it as 'mydatabase'
    }

}

##################
# Glue Crawler   #
##################

resource "aws_glue_crawler" "crawler" {
  name            = "my_glue_crawler"
  database_name   = aws_glue_catalog_database.coding_interview_database.name
  role            = aws_iam_role.crawler_role.arn

  configuration = <<CONFIG
    {
      "Version": 1.0,
      "CrawlerOutput": {
        "Partitions": {
          "AddOrUpdateBehavior": "InheritFromTable"
        },
        "Tables": {
          "AddOrUpdateBehavior": "MergeNewColumns"
        }
      }
    }
  CONFIG

  jdbc_target {
    connection_name = aws_glue_connection.aurora_connection.name
    path            = "mydatabase/%"
    exclusions      = []
  }
}


resource "aws_iam_role" "crawler_role" {
  name = "my_glue_crawler_role"

  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "glue.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  })


}


##################
# Glue Job       #
##################
resource "aws_glue_job" "job" {
  name                      = "my_glue_job"
  role_arn                  = aws_iam_role.job_role.arn
  number_of_workers         = 2
  worker_type               = "G.1X"
  glue_version              = "3.0"
  command {
    name        = "glueetl"
    script_location = "s3://${aws_s3_bucket.coding_interview_bucket_riaan_annandale.id}/glue-scripts/etl.py"
  }

  default_arguments = {
    "--job-bookmark-option": "job-bookmark-disable"
    "--enable-continuous-cloudwatch-log": "true"
    "--enable-job-insights": "true"
    "--job-language": "python"
  }
}

# Schedule to run once a month at 3AM UTC (completely arbitrary time slot, but seeing as our exctracts are pinned to months...)
resource "aws_glue_trigger" "my_glue_job_shedule" {
  name     = "glue_job_schedule"
  schedule = "cron(0 3 1 * ? *)"
  type     = "SCHEDULED"

  actions {
    job_name = aws_glue_job.job.name
  }
}


# Hmmmm, this doesn't seem pick up that the job has failed... I wonder if it has something to do with my "cloudwatch on a budget" setup
resource "aws_cloudwatch_metric_alarm" "glue_job_failure_alarm" {
  alarm_name          = "glue_job_failure_alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "JobRunState"
  namespace           = "AWS/Glue"
  period              = 60
  statistic           = "SampleCount"
  threshold           = 0

  dimensions = {
    JobName      = aws_glue_job.job.name
    ResourceType = "JOB"
  }

  alarm_description = "Triggered when the Glue job fails"
  alarm_actions     = [aws_sns_topic.glue_job_failure_topic.arn]
}

# SNS topic for email notifications
resource "aws_sns_topic" "glue_job_failure_topic" {
  name = "glue_job_failure_topic"
}

# Subscription to the SNS topic (replace with your email address)
resource "aws_sns_topic_subscription" "glue_job_failure_subscription" {
  topic_arn = aws_sns_topic.glue_job_failure_topic.arn
  protocol  = "email"
  endpoint  = var.email_endpoint
  }

# Right now, the same policy is used for the crawler and the glue job. Major difference ITO over permission is
# that the crawler doesn't need S3 access and the glue job doesn't need the ec2 access
resource "aws_iam_policy" "job-role-policy" {
  name        = "job-role-policy"
  description = "Policy that lets glue jobs fetch connections from Glue"
  #policy      = data.aws_iam_policy_document.job_role.json
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "glue:GetConnection",
          "glue:GetConnections",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeVpcEndpoints",
          "ec2:DescribeRouteTables",
          "logs:PutLogEvents",
          "logs:CreateLogStream",
          "s3:GetObject",
          "s3:PutObject",
          "glue:GetConnection",
          "glue:StartCrawler",
          "glue:StopCrawler",
          "glue:CreateCrawler",
          "glue:DeleteCrawler",
          "glue:GetCrawler",
          "glue:UpdateCrawler",
          "glue:GetCrawlerMetrics"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role" "job_role" {
  name = "gluejobrole"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "glue.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole", "arn:aws:iam::149608333506:policy/job-role-policy"]
}

resource "aws_iam_policy_attachment" "crawler_role" {
  name       = "crawler-role-policy-attachment"
  roles      = [aws_iam_role.crawler_role.name,aws_iam_role.job_role.name]
  policy_arn = aws_iam_policy.job-role-policy.arn
}

resource "aws_s3_bucket" "coding_interview_bucket_riaan_annandale" {
  bucket = "coding-interview-bucket-riaan-annandale"
}

resource "aws_s3_object" "etl_file" {
  bucket = aws_s3_bucket.coding_interview_bucket_riaan_annandale.id
  key    = "glue-scripts/etl.py"
  source = "../Glue/etl.py"
}

# SFTP stuff
# Create an IAM role for the SFTP server
resource "aws_iam_role" "sftp_role" {
  name = "sftp-server-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "transfer.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# Attach the necessary policies to the SFTP role
resource "aws_iam_role_policy_attachment" "sftp_role_policy_attachment" {
  role       = aws_iam_role.sftp_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSTransferLoggingAccess"
}

# Create the SFTP server
resource "aws_transfer_server" "sftp_server" {
  identity_provider_type = "SERVICE_MANAGED"
  endpoint_type          = "PUBLIC"

  tags = {
    Name = "sftp-server"
  }
}

# Create an SFTP user
# I have not included any keys for the user. They need to be added via the console
resource "aws_transfer_user" "sftp_user" {
  server_id        = aws_transfer_server.sftp_server.id
  user_name        = "sftpuser"
  home_directory  = "/${aws_s3_bucket.coding_interview_bucket_riaan_annandale.id}/output-folder"
  role             = aws_iam_role.sftp_role.arn
  policy           = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3Permissions",
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetObject"
      ],
      "Resource": [
        "arn:aws:s3:::${aws_s3_bucket.coding_interview_bucket_riaan_annandale.id}",
        "arn:aws:s3:::${aws_s3_bucket.coding_interview_bucket_riaan_annandale.id}/*"
      ]
    }
  ]
}
EOF
}


# Don't need this is we're using the client specified endpoint
# output "aurora_cluster_endpoint" {
#     value = aws_rds_cluster.aurora_cluster.endpoint
# }
