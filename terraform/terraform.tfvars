# =============================================================================
# AWS general
# =============================================================================
aws_region = "eu-north-1"

# =============================================================================
# Project general
# =============================================================================
project_name = "leumi-test"
environment  = "test"

# =============================================================================
# VPC configuration
# =============================================================================
vpc_name             = "test-spoke-vpc"
vpc_cidr             = "10.181.242.0/24" # 256 Total addresses
availability_zones   = ["eu-north-1a", "eu-north-1b"]
public_subnet_cidrs  = ["10.181.242.0/26", "10.181.242.64/26"]    # First half for public (/26 means 64 addresses)
private_subnet_cidrs = ["10.181.242.128/26", "10.181.242.192/26"] # Second half for private (/26 means 64 addresses)

# =============================================================================
# EC2 Configuration - TEST EC2 Instance
# =============================================================================
ec2_ami_id        = "" # if needed. fall back to latest Amazon linux.
ec2_instance_type = "t3.micro"
ec2_volume_size   = 20
ec2_private_ip    = "" # if empty, will auto assign
enable_elastic_ip = true

# =============================================================================
# Apache server security groups
# =============================================================================
leumi_proxy_ip  = "84.229.79.41/32" # using personal ip for testing
web_server_port = 80

# =============================================================================
# NLB configuration
# =============================================================================
nlb_name                         = "test-ec2-nlb"
nlb_internal                     = false # Internet-facing
enable_cross_zone_load_balancing = true

# =============================================================================
# CloudFront configuration
# =============================================================================
cloudfront_price_class   = "PriceClass_100"  # Use only North America and Europe edge locations
cloudfront_custom_header = "my-secret-origin-header-12345"  # Change this to a random value

# =============================================================================
# Common Tags
# =============================================================================
common_tags = {
  Department = "DevOps"
  CostCenter = "Infrastructure"
  Compliance = "Leumi-Standard"
}
