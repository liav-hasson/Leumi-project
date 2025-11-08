variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "ec2_ami_id" {
  description = "AMI ID for the EC2 instance (leave empty for latest Amazon Linux 2023)"
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "subnet_id" {
  description = "Subnet ID where EC2 will be launched"
  type        = string
}

# auto assing if not provided in terraform.tfvars
variable "private_ip" {
  description = "Fixed private IP for the EC2 instance"
  type        = string
  default     = ""
}

variable "security_group_ids" {
  description = "List of security group IDs to attach to EC2"
  type        = list(string)
}

variable "volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 20
}

variable "enable_elastic_ip" {
  description = "Whether to create and attach an Elastic IP"
  type        = bool
  default     = true
}

