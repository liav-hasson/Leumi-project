# =============================================================================
# VPC Module
# =============================================================================
module "vpc" {
  source = "./vpc"

  vpc_name             = var.vpc_name
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  environment          = var.environment
  project_name         = var.project_name
}

# =============================================================================
# Security Groups Module
# =============================================================================
module "security_groups" {
  source = "./security-groups"

  vpc_id          = module.vpc.vpc_id
  vpc_cidr        = var.vpc_cidr
  environment     = var.environment
  project_name    = var.project_name
  leumi_proxy_ip  = var.leumi_proxy_ip
  web_server_port = var.web_server_port

  depends_on = [module.vpc]
}

# =============================================================================
# EC2 Instance Module - Apache TEST EC2  
# =============================================================================
module "test_ec2" {
  source = "./ec2"

  project_name       = var.project_name
  environment        = var.environment
  ec2_ami_id         = var.ec2_ami_id
  instance_type      = var.ec2_instance_type
  subnet_id          = module.vpc.public_subnet_ids[0]  # must be in public subnet for elastic IP
  private_ip         = var.ec2_private_ip
  security_group_ids = [module.security_groups.test_ec2_security_group_id]
  volume_size        = var.ec2_volume_size
  enable_elastic_ip  = var.enable_elastic_ip

  depends_on = [module.security_groups]
}

# =============================================================================
# NLB Module
# =============================================================================
module "nlb" {
  source = "./nlb"

  nlb_name                         = var.nlb_name
  nlb_internal                     = var.nlb_internal
  public_subnet_ids                = module.vpc.public_subnet_ids
  vpc_id                           = module.vpc.vpc_id
  ec2_instance_id                  = module.test_ec2.instance_id
  target_port                      = var.web_server_port
  listener_port                    = var.web_server_port
  enable_cross_zone_load_balancing = var.enable_cross_zone_load_balancing
  environment                      = var.environment
  project_name                     = var.project_name

  depends_on = [module.test_ec2]
}

# =============================================================================
# CloudFront Module - CDN for Public Web Access
# =============================================================================
module "cloudfront" {
  source = "./cloudfront"

  project_name                 = var.project_name
  environment                  = var.environment
  nlb_dns_name                 = module.nlb.nlb_dns_name
  price_class                  = var.cloudfront_price_class
  custom_origin_header_value   = var.cloudfront_custom_header

  depends_on = [module.nlb]
}
