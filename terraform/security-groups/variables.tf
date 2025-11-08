variable "vpc_id" {
  description = "VPC ID where security groups will be created"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block for internal traffic rules"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "leumi_proxy_ip" {
  description = "IP address of Leumi Proxy (CIDR notation)"
  type        = string
}

variable "web_server_port" {
  description = "Web server port (default 80)"
  type        = number
  default     = 80
}
