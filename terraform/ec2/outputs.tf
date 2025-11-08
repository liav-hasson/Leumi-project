output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.test_ec2.id
}

output "private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.test_ec2.private_ip
}

output "public_ip" {
  description = "Elastic IP (VIP) address"
  value       = var.enable_elastic_ip ? aws_eip.test_ec2_eip[0].public_ip : null
}

output "instance_state" {
  description = "Current state of the instance"
  value       = aws_instance.test_ec2.instance_state
}
