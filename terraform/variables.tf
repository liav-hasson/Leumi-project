# general configurations
variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "eu-north-1"
}

variable "project_name" {
  description = "Name of the project (used for resource naming and tagging)"
  type        = string
}

variable "environment" {
  description = "Environment name (test, dev, production)"
  type        = string
  default     = "test"
}

# VPC Configuration - TEST VPC (10.181.242.0/24)
variable "vpc_name" {
  description = "Name of the TEST SPOKE VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the TEST SPOKE VPC"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones to use"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

# EC2 Configuration - TEST EC2 Instance
variable "ec2_ami_id" {
  description = "AMI ID for TEST EC2 instance"
  type        = string
}

variable "ec2_instance_type" {
  description = "Instance type for TEST EC2"
  type        = string
  default     = "t3.micro"
}

variable "ec2_volume_size" {
  description = "Root volume size for TEST EC2"
  type        = number
  default     = 20
}

variable "ec2_private_ip" {
  description = "Fixed private IP address for TEST EC2"
  type        = string
  default     = "10.181.242.10"
}

variable "enable_elastic_ip" {
  description = "create and attach an Elastic IP to TEST EC2"
  type        = bool
  default     = true
}

# Security Configuration - Leumi Proxy Whitelist
variable "leumi_proxy_ip" {
  description = "IP address of Leumi Proxy allowed to access the web server"
  type        = string
  default     = "91.231.246.50/32"
}

variable "web_server_port" {
  description = "Port for Apache web server"
  type        = number
  default     = 80
}

# Network Load Balancer Configuration
variable "nlb_name" {
  description = "Name for the Network Load Balancer"
  type        = string
}

variable "nlb_internal" {
  description = "Whether the NLB should be internal (false for internet-facing)"
  type        = bool
  default     = false
}

variable "enable_cross_zone_load_balancing" {
  description = "Enable cross-zone load balancing for NLB"
  type        = bool
  default     = true
}

# CloudFront Configuration
variable "cloudfront_price_class" {
  description = "CloudFront price class (PriceClass_All, PriceClass_200, PriceClass_100)"
  type        = string
  default     = "PriceClass_100"
}

variable "cloudfront_custom_header" {
  description = "Custom header value for CloudFront origin validation"
  type        = string
  default     = "terraform-secret-header-value"
  sensitive   = true
}


# Common Tags
variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
