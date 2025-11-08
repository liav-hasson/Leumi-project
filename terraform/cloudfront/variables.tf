variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "nlb_dns_name" {
  description = "DNS name of the Network Load Balancer"
  type        = string
}

variable "price_class" {
  description = "CloudFront price class (PriceClass_All, PriceClass_200, PriceClass_100)"
  type        = string
  default     = "PriceClass_100"
}

variable "custom_origin_header_value" {
  description = "Custom header value for origin validation (secret)"
  type        = string
  default     = "terraform-generated-secret"
  sensitive   = true
}
