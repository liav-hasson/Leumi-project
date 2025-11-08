# data source for CloudFront prefix list
# the list contains 1+ CIDR blocks of the edge locations
# used to reference in the security groups
data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

# CloudFront main
resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront distribution for TEST EC2 Apache"
  default_root_object = "index.html"
  price_class         = var.price_class

  origin {
    domain_name = var.nlb_dns_name
    origin_id   = "nlb-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    # Custom header for additional security (optional)
    custom_header {
      name  = "X-Custom-Origin-Header"
      value = var.custom_origin_header_value
    }
  }

  # Default cache behavior
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "nlb-origin"

    forwarded_values {
      query_string = false
      headers      = []

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  tags = {
    Name        = "${var.project_name}-cloudfront"
    Environment = var.environment
    Project     = var.project_name
    Purpose     = "CDN-for-Apache"
  }
}
