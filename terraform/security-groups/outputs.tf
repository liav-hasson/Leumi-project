output "test_ec2_security_group_id" {
  description = "Security group ID for TEST EC2 instance"
  value       = aws_security_group.test_ec2.id
}

output "nlb_security_group_id" {
  description = "Security group ID for NLB health checks"
  value       = aws_security_group.nlb_to_ec2.id
}
