output "nlb_id" {
  description = "ID of the Network Load Balancer"
  value       = aws_lb.test_nlb.id
}

output "nlb_arn" {
  description = "ARN of the Network Load Balancer"
  value       = aws_lb.test_nlb.arn
}

output "nlb_dns_name" {
  description = "DNS name of the Network Load Balancer"
  value       = aws_lb.test_nlb.dns_name
}

output "nlb_zone_id" {
  description = "Zone ID of the Network Load Balancer"
  value       = aws_lb.test_nlb.zone_id
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.test_ec2_tg.arn
}

output "target_group_name" {
  description = "Name of the target group"
  value       = aws_lb_target_group.test_ec2_tg.name
}
