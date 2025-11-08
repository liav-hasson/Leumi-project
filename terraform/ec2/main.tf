# Data source for latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  # hvm - "hardware virtual machine", modern 
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# create IAM Role for an EC2 instance
resource "aws_iam_role" "test_ec2_role" {
  name = "${var.project_name}-test-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-test-ec2-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

# attach SSM policy to the IAM role
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.test_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Binds role to the TEST EC2 
resource "aws_iam_instance_profile" "test_ec2_profile" {
  name = "${var.project_name}-test-ec2-profile"
  role = aws_iam_role.test_ec2_role.name

  tags = {
    Name        = "${var.project_name}-test-ec2-profile"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Elastic IP
resource "aws_eip" "test_ec2_eip" {
  count  = var.enable_elastic_ip ? 1 : 0
  domain = "vpc"

  tags = {
    Name        = "${var.project_name}-test-ec2-eip"
    Environment = var.environment
    Project     = var.project_name
    Purpose     = "VIP"
  }
}

# Elastic IP Association
resource "aws_eip_association" "test_ec2_eip_assoc" {
  count         = var.enable_elastic_ip ? 1 : 0
  instance_id   = aws_instance.test_ec2.id
  allocation_id = aws_eip.test_ec2_eip[0].id
}

# main EC2 Instance
resource "aws_instance" "test_ec2" {
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  iam_instance_profile   = aws_iam_instance_profile.test_ec2_profile.name

  # check for values from terraform.tfvars and fall back if needed
  ami                    = var.ec2_ami_id != "" ? var.ec2_ami_id : data.aws_ami.amazon_linux_2023.id
  private_ip             = var.private_ip != "" ? var.private_ip : null  

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.volume_size
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name        = "${var.project_name}-test-ec2-root-volume"
      Environment = var.environment
      Project     = var.project_name
    }
  }

  user_data                   = local.user_data
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  tags = {
    Name        = "${var.project_name}-test-ec2"
    Environment = var.environment
    Project     = var.project_name
    Purpose     = "Apache-WebServer"
    IP          = var.private_ip
  }
}

# User Data script to install and configure Apache
# Run a simple HTML
locals {
  user_data = <<-EOF
#!/bin/bash
exec > /var/log/user-data.log 2>&1
set -x

# Install Apache
yum install -y httpd

# Create index page
echo "<h1>Hello from $(hostname)</h1><h2>Time: $(date)</h2>" > /var/www/html/index.html

# Start Apache
systemctl start httpd
systemctl enable httpd

# Start firewalld 
systemctl start firewalld
systemctl enable firewalld 

echo "DONE"
EOF
}
