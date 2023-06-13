##################
# Glue Catalog   #
##################

# Based on the bank having a co.za domain, we'll they'll probably be in the AF region in AWS
# But since I'm testing with an always free account -- we'll have to settle for eu west
# Configure the AWS Provider
provider "aws" {
    region = "eu-west-2"
}

# Using a VPC to keep everyting together
resource "aws_vpc" "test_control" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "My Testing VPC"
  }
}

# Create an internet gateway so we can access the database
 resource "aws_internet_gateway" "public_internet_gateway" {
   vpc_id = aws_vpc.test_control.id
   tags = {
     Name = "An Internet Gateway"
   }
 }

#Create a subnet within the VPC
resource "aws_subnet" "testing_subnet_1" {
  vpc_id            = aws_vpc.test_control.id
  availability_zone = "eu-west-2b"
  cidr_block        = "10.0.16.0/24"

  tags = {
    Name = "Testing Subnet"
  }
}

resource "aws_subnet" "testing_subnet_2" {
  vpc_id     = aws_vpc.test_control.id
  availability_zone = "eu-west-2c"
  cidr_block = "10.0.18.0/24"

  tags = {
    Name = "Testing Subnet 2"
  }
}

resource "aws_db_subnet_group" "default" {
  name       = "default-group"
  subnet_ids = [aws_subnet.testing_subnet_1.id, aws_subnet.testing_subnet_2.id]
}

###################
#  AWS S3 Config  #
###################
resource "aws_kms_key" "s3_encryption_key" {
  description             = "Key for Encryption"
  deletion_window_in_days = 10
}

resource "aws_s3_bucket" "bank_data_object_storage" {
  bucket = "dev-test-bank-loan-data-output"
  region = "eu-west-2"

  versioning {
    enabled = true   # Enable versioning for the bucket
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "aws_s3_encryption" {
  bucket = aws_s3_bucket.bank_data_object_storage.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_encryption_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# Manage passwords - no passwords in source!
# We'll use this secret to keep the default password as part of the tech assement.
# Passoword in this case would be 5Y67bg#r#
data "aws_secretsmanager_secret" "db_credentials" {
  name = "dev-testing-master-password"
}

############################
# Glue Catalog & Crawler   #
############################

resource "aws_glue_connection" "aws_rds_connection" {
  name              = "rds_banking_db_connection"
  physical_connection_requirements {
    availability_zone      = "eu-west-2b"
    security_group_id_list = [aws_security_group.rds_security_group_terraform.id] 
    subnet_id              = aws_subnet.testing_subnet_1.id
  }
  connection_properties = {
    USERNAME            = "postgres",
    PASSWORD            = "${aws_secretsmanager_secret_version.db_credentials.secret_string}",
    JDBC_CONNECTION_URL = "jdbc:postgresql://mycluster.cluster-123456789012.us-east-1.rds.amazonaws.com:5432/the_db_name" #In the ideal world we'll use a terraform var here
    #JDBC_CONNECTION_URL = "jdbc:postgresql://${aws_db_instance.bank_data_db.endpoint}/postgres"
    }

}

resource "aws_glue_catalog_database" "bank_loan_data_db" {
  name = "bank_loan_data_db"
}

# Create a Glue crawler
resource "aws_glue_crawler" "loan_data_crawler" {
  name                 = "bank_loan_data_crawler"
  database_name        = aws_glue_catalog_database.bank_loan_data_db.name
  role                 = aws_iam_role.glue_crawler_role.arn

  jdbc_target {
    connection_name   = aws_glue_connection.aws_rds_connection.name
    path              = "postgres/public/%"
    exclusions        = []
  }
}

# Create an IAM role for Glue crawler
resource "aws_iam_role" "glue_crawler_role" {
  name = "GlueCrawlerRole"

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
}

# Attach Glue service policy to the IAM role
resource "aws_iam_role_policy_attachment" "glue_service_policy_attachment" {
  role       = aws_iam_role.glue_crawler_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Create a VPC endpoint for Glue to access the RDS database
resource "aws_vpc_endpoint" "glue_rds_endpoint" {
  vpc_id              = aws_vpc.test_control.id
  service_name        = "com.amazonaws.eu-west-2.s3"
  vpc_endpoint_type   = "Gateway"

  tags = {
    Name = "Glue RDS Endpoint"
  }
}

##################
# Glue Job       #
##################
resource "aws_s3_object" "etl_script" {
  bucket = aws_s3_bucket.bank_data_object_storage.id
  key    = "src/etl.py"
  source = "../Glue/etl.py"
}

resource "aws_glue_job" "bank_loan_data" {
  name     = "bank_loan_data_ma"
  role_arn = aws_iam_role.glue_crawler_role.arn

  command {
    name        = "glue_etl_job"
    script_location = "s3://${aws_s3_bucket.bank_data_object_storage.bucket}/src/etl.py"
  }
}

################
# Extra Config #
################

# Creating the SFTP Instance on EC2:
resource "aws_instance" "sftp_server" {
  ami           = "ami-appropirate-ami-id"  
  instance_type = "t2.micro"               
  key_name      = "SSH_KEY_MASTER"

  # Security group allowing SSH (port 22) and SFTP (port 22 for TCP and UDP)
  security_groups = ["sftp_security_group"]

  # User data script to install OpenSSH server and configure SFTP
  user_data = <<-EOT
    #!/bin/bash
    sudo apt-get update
    sudo apt-get install -y openssh-server

    # Configure OpenSSH for SFTP-only access
    sudo echo 'Match User sftpuser' >> /etc/ssh/sshd_config
    sudo echo 'ForceCommand internal-sftp' >> /etc/ssh/sshd_config
    sudo echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config
    sudo echo 'ChrootDirectory /home/sftpuser' >> /etc/ssh/sshd_config
    sudo echo 'PermitTunnel no' >> /etc/ssh/sshd_config
    sudo echo 'AllowAgentForwarding no' >> /etc/ssh/sshd_config
    sudo echo 'AllowTcpForwarding no' >> /etc/ssh/sshd_config
    sudo echo 'X11Forwarding no' >> /etc/ssh/sshd_config

    # Create SFTP user and set password
    sudo useradd sftpuser -m -s /usr/sbin/nologin
    sudo echo '#####:#####' | sudo chpasswd
    sudo mkdir /home/sftpuser/upload
    sudo mount /mnt/${aws_s3_bucket.bank_data_object_storage.bucket}/bank_loan_data
    sudo ln -s '/mnt/${aws_s3_bucket.bank_data_object_storage.bucket}/bank_loan_data' '/home/sftpuser/upload'
    sudo chown sftpuser:sftpuser /home/sftpuser/upload
    sudo chmod 700 /home/sftpuser/upload

    # Restart OpenSSH service
    sudo service ssh restart
  EOT
}

# Create security group allowing SSH (port 22) and SFTP (port 22 for TCP and UDP)
resource "aws_security_group" "sftp_security_group" {
  name        = "sftp_security_group"
  description = "Security group for SFTP server"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

######################################
# Cloudwatch Logging & Orchestration #
######################################

resource "aws_cloudwatch_event_rule" "bank_loan_etl_scheduler" {
  name        = "job_schedule"
  description = "Schedule for triggering the job"

  schedule_expression = "cron(30 03 * * ? *)" # Daily run @ 03h30 UTC
}

resource "aws_sns_topic" "loan_data_failure_notification" {
  name = "loan_data_failure_notification"
}

resource "aws_sns_topic_subscription" "failure_notification_sub" {
  topic_arn = aws_sns_topic.loan_data_failure_notification.arn
  protocol  = "email"
  endpoint  = "data-support@mybigbank.co.za"
}

resource "aws_cloudwatch_event_target" "job_schedule_target" {
  rule      = aws_cloudwatch_event_rule.bank_loan_etl_scheduler.name
  target_id = "job_schedule_target"
  arn       = aws_sfn_state_machine.job_orchestration.id
}

# Create Step Functions State Machine:
resource "aws_sfn_state_machine" "glue_job_orchestration" {
  name     = "glue_job_orchestration"
  role_arn = aws_iam_role.step_functions_role.arn

  definition = <<EOF
{
  "Comment": "Glue Job Orchestration Workflow",
  "StartAt": "RunGlueJob",
  "States": {
    "RunGlueJob": {
      "Type": "Task",
      "Resource": "arn:aws:states:::glue:startJobRun.sync",
      "Parameters": {
        "JobName": "bank_loan_data",
        "Arguments": {}
      },
      "End": true,
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "Next": "NotifyFailure"
        }
      ]
    },
    "NotifyFailure": {
      "Type": "Task",
      "Resource": "arn:aws:states:::sns:publish",
      "Parameters": {
        "Message": "Glue job failed. Please check logs for details.",
        "TopicArn": "${failure_notification_sub.arn}"
      },
      "End": true
    }
  }
}
EOF
}

##########
# Errata #
##########

# This was for testing -- moved to the end of the terraform file as deleting seemed to be wasteful #

# Generate a random password, which will be used in testing!
#resource "random_password" "db_credentials" {
#  length           = 18
#  special          = false
#}

#resource "aws_secretsmanager_secret_version" "db_credentials" {
#  secret_id     = data.aws_secretsmanager_secret.db_credentials.id
#  secret_string = random_password.db_credentials.result
#}

# Security group for the RDS database
#resource "aws_security_group" "rds_security_group_terraform" {
#  vpc_id = aws_vpc.test_control.id

#  ingress {
#    from_port   = 5432
#    to_port     = 5432
#    protocol    = "tcp"
#    cidr_blocks = ["160.119.224.0/20", "160.119.248.0/21"]
#    description = "Making sure I can access the DB from my home connection"
#  }
#  ingress {
#    from_port   = 0
#    to_port     = 65535
#    protocol    = "tcp"
#   cidr_blocks = ["0.0.0.0/0"]
#   description = "All TCP"
#  }

#  egress {
#    from_port   = 0
#    to_port     = 0
#    protocol    = "-1"
#    cidr_blocks = ["0.0.0.0/0"]
#    description = "Everything out!"
#  }

#  tags = {
#    Name = "RDS Security Group"
#  }
#}

# Create the testing RDS Postgres Database
# Again, this is only to test the ETL Script in AWS Glue

#resource "aws_db_instance" "bank_data_db" {
#  identifier             = "dev-test-banking-db"
#  engine                 = "postgres"
#  engine_version         = "13.11"
#  instance_class         = "db.t3.micro"
#  allocated_storage      = 20
#  storage_type           = "gp2"
#  username               = "diesal"
#  password               = aws_secretsmanager_secret_version.db_credentials.secret_string
#  publicly_accessible    = true
#  vpc_security_group_ids = [aws_security_group.rds_security_group_terraform.id]
#  db_subnet_group_name   = aws_db_subnet_group.default.name
#  skip_final_snapshot    = true

#  tags = {
#    Name = "Test Banking Database"
#  }
#}