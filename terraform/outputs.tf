# =============================================================================
# VPC 
# =============================================================================
output "vpc_id" {
  description = "ID of the TEST SPOKE VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the TEST SPOKE VPC"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

# =============================================================================
# EC2 
# =============================================================================
output "test_ec2_instance_id" {
  description = "Instance ID of TEST EC2"
  value       = module.test_ec2.instance_id
}

output "test_ec2_private_ip" {
  description = "Private IP address of TEST EC2"
  value       = module.test_ec2.private_ip
}

output "test_ec2_elastic_ip" {
  description = "Elastic IP of TEST EC2"
  value       = module.test_ec2.public_ip
}

# =============================================================================
# NLB 
# =============================================================================
output "nlb_dns_name" {
  description = "DNS name of the Network Load Balancer"
  value       = module.nlb.nlb_dns_name
}

output "nlb_id" {
  description = "ID of the Network Load Balancer"
  value       = module.nlb.nlb_id
}

output "nlb_arn" {
  description = "ARN of the Network Load Balancer"
  value       = module.nlb.nlb_arn
}

# =============================================================================
# Security Groups 
# =============================================================================
output "test_ec2_security_group_id" {
  description = "Security group ID for TEST EC2"
  value       = module.security_groups.test_ec2_security_group_id
}

# =============================================================================
# CloudFront 
# =============================================================================
output "cloudfront_id" {
  description = "CloudFront distribution ID"
  value       = module.cloudfront.cloudfront_id
}

output "cloudfront_domain_name" {
  description = "CloudFront domain name"
  value       = module.cloudfront.cloudfront_domain_name
}

output "cloudfront_url" {
  description = "URL to access Apache via CloudFront"
  value       = module.cloudfront.cloudfront_url
}

# =============================================================================
# Access Info
# =============================================================================
output "apache_url_via_cloudfront" {
  description = "Access Apache via CloudFront"
  value       = module.cloudfront.cloudfront_url
}

output "apache_url_via_nlb" {
  description = "NLB access (for testing, production uses cloudfront)"
  value       = "http://${module.nlb.nlb_dns_name}"
}

output "apache_url_via_eip" {
  description = "access via Elastic IP (Leumi Proxy only)"
  value       = "http://${module.test_ec2.public_ip}"
}