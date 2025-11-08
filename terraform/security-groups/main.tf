# Data source for CloudFront managed prefix list
data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

# Security Group for TEST EC2 - Allow CloudFront, Leumi Proxy, and VPC traffic
resource "aws_security_group" "test_ec2" {
  name        = "${var.project_name}-test-ec2-sg"
  description = "Security group for TEST EC2 - allows CloudFront (public), Leumi Proxy (management), and VPC internal traffic"
  vpc_id      = var.vpc_id

  # Ingress: Allow HTTP from CloudFront (public web access)
  ingress {
    description     = "HTTP from CloudFront for public access"
    from_port       = var.web_server_port
    to_port         = var.web_server_port
    protocol        = "tcp"
    prefix_list_ids = [data.aws_ec2_managed_prefix_list.cloudfront.id]
  }

  # Ingress: Allow all traffic from Leumi Proxy (management/admin access)
  ingress {
    description = "Management access from Leumi Proxy"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.leumi_proxy_ip]
  }

  # Ingress: Allow HTTP from VPC (for NLB health checks)
  ingress {
    description = "HTTP from VPC for NLB health checks"
    from_port   = var.web_server_port
    to_port     = var.web_server_port
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Egress: Allow all outbound traffic (for updates, etc.)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-test-ec2-sg"
    Environment = var.environment
    Project     = var.project_name
    Purpose     = "TEST-EC2-Apache"
  }

  # security group is deleted only after all dependent resources
  lifecycle {
    create_before_destroy = false
  }
}

# Security Group for NLB 
resource "aws_security_group" "nlb_to_ec2" {
  name        = "${var.project_name}-nlb-to-ec2-sg"
  description = "Allow NLB health checks and traffic to TEST EC2"
  vpc_id      = var.vpc_id

  # Note: NLB uses source IPs from the clients, so we need to allow proxy IP
  # Health checks come from NLB's IP in the VPC CIDR
  ingress {
    description = "Health checks from NLB"
    from_port   = var.web_server_port
    to_port     = var.web_server_port
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Lifecycle: Ensure security group is deleted only after all dependent resources
  lifecycle {
    create_before_destroy = false
  }

  tags = {
    Name        = "${var.project_name}-nlb-to-ec2-sg"
    Environment = var.environment
    Project     = var.project_name
    Purpose     = "NLB-HealthChecks"
  }
}
