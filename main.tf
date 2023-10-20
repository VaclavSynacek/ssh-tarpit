terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.region
}

# no need for custom ami, everyting can be cutomized with cloud-init user-data
data "cloudinit_config" "full-cloud-init" {

  # the whole tarpit script is short so it fits within user data section
  # if packed as x-shellscript it will be run when the instance starts
  # logs can be found in /var/log/cloud-init-output.log
  part {
    filename     = "ssh.clj"
    content_type = "text/x-shellscript"
    content = file("${path.module}/ssh-tarpit.clj")
  }

  # standard cloud-config yaml where:
  #  * sshd is uninstalled
  #  * Amazon SSM Agent is installed and enabled
  part {
    filename     = "cloud-config.yaml"
    content_type = "text/cloud-config"
    content = file("${path.module}/cloud-config.yaml")
  }
}

resource "aws_instance" "tarpit" {
  
  # t4g.small 750 hours/month free until 31st Dec 2023 - let's use it
  instance_type = "t4g.small"
  
  #aarm64 Debian 12
  ami           = "ami-06dc2b03e8c5b01a8"

  # two very important bits, see definitions further down
  vpc_security_group_ids = [aws_security_group.ssh_in_all_out.id]
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name

  tags = {
    Name = "tarpit"
  }

  root_block_device {
    volume_size           = "8"
    volume_type           = "gp2"
    encrypted             = false
    delete_on_termination = true
  }
  
  associate_public_ip_address = true

  # this is where the instance gets all the software
  user_data = data.cloudinit_config.full-cloud-init.rendered
  
  # this is needed if you want changes to tarpit script to trigger
  # instance recreation - very handy for different tarpit logic tests
  user_data_replace_on_change = true
}

resource "aws_security_group" "ssh_in_all_out" {
  egress = [
    {
      cidr_blocks      = [ "0.0.0.0/0", ]
      description      = "needed for the instalation of SSM Agent and babashka and also for SSM sessions"
      from_port        = 0
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "-1"
      security_groups  = []
      self             = false
      to_port          = 0
    }
  ]
 ingress                = [
   {
     cidr_blocks      = [ "0.0.0.0/0", ]
     description      = "allow the trafic to reach tarpit, on the usual port"
     from_port        = 22
     ipv6_cidr_blocks = []
     prefix_list_ids  = []
     protocol         = "tcp"
     security_groups  = []
     self             = false
     to_port          = 22
  },
  {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    description = "Allow ping from anywhere"
     ipv6_cidr_blocks = []
     prefix_list_ids  = []
     security_groups  = []
     self             = false
  }

  ]
}


# Create IAM role for EC2 instance
resource "aws_iam_role" "ec2_role" {
  name = "EC2_SSMInstance_plus_PutMetricData_Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach AmazonSSMManagedInstanceCore policy to the IAM role
# As this instance will now have sshd running, SSM sessions will be the only way
# to get in and inspect logs or troubleshoot.
resource "aws_iam_role_policy_attachment" "ec2_role_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.ec2_role.name
}


# Also the tarpit will log custom metrics into CLoudWatch
# so the EC2 needs this one action allowed.
resource "aws_iam_role_policy" "metric_access" {
  name = "PutMetricDataAccess"
  role = aws_iam_role.ec2_role.name

    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "cloudwatch:PutMetricData"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}
 
# Create an instance profile for the EC2 instance and associate the IAM role
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "EC2_SSM_plus_PutMetricData_Instance_Profile"
  role = aws_iam_role.ec2_role.name
}
