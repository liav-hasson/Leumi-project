output "cloudfront_id" {
  description = "ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.main.id
}

output "cloudfront_arn" {
  description = "ARN of the CloudFront distribution"
  value       = aws_cloudfront_distribution.main.arn
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "cloudfront_url" {
  description = "Full URL to access via CloudFront"
  value       = "https://${aws_cloudfront_distribution.main.domain_name}"
}

output "cloudfront_prefix_list_id" {
  description = "AWS managed prefix list ID for CloudFront"
  value       = data.aws_ec2_managed_prefix_list.cloudfront.id
}
