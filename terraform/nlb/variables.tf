variable "nlb_name" {
  description = "Name for the Network Load Balancer"
  type        = string
}

variable "nlb_internal" {
  description = "Whether the NLB is internal (false for internet-facing)"
  type        = bool
  default     = false
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for the NLB"
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC ID where the target group will be created"
  type        = string
}

variable "ec2_instance_id" {
  description = "EC2 instance ID to register with the target group"
  type        = string
}

variable "target_port" {
  description = "Port on the target (EC2) to route traffic to"
  type        = number
  default     = 80
}

variable "listener_port" {
  description = "Port for the NLB listener"
  type        = number
  default     = 80
}

variable "enable_cross_zone_load_balancing" {
  description = "Enable cross-zone load balancing"
  type        = bool
  default     = true
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}
