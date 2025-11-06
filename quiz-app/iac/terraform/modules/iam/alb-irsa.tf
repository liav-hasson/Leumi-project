## IRSA for AWS Load Balancer Controller (prod EKS)

resource "aws_iam_role" "alb_controller" {
  name        = "${var.project_name}-alb-controller-irsa"
  description = "IRSA role for AWS Load Balancer Controller on prod EKS"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = local.oidc_provider_arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "${local.oidc_provider_url}:sub" = "system:serviceaccount:${var.alb_service_account_namespace}:${var.alb_service_account_name}",
            "${local.oidc_provider_url}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "alb_controller" {
  name = "AWSLoadBalancerControllerPolicy"
  role = aws_iam_role.alb_controller.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "iam:CreateServiceLinkedRole",
          "ec2:Describe*",
          "ec2:GetCoipPoolUsage",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "elasticloadbalancing:*",
          "cognito-idp:DescribeUserPoolClient",
          "acm:ListCertificates",
          "acm:DescribeCertificate",
          "iam:GetServerCertificate",
          "iam:ListServerCertificates",
          "waf-regional:GetWebACL",
          "waf-regional:GetWebACLForResource",
          "waf-regional:AssociateWebACL",
          "waf-regional:DisassociateWebACL",
          "wafv2:GetWebACL",
          "wafv2:GetWebACLForResource",
          "wafv2:AssociateWebACL",
          "wafv2:DisassociateWebACL",
          "shield:DescribeProtection",
          "shield:GetSubscriptionState",
          "shield:ListProtections",
          "shield:CreateProtection",
          "shield:DeleteProtection",
          "tag:GetResources"
        ],
        Resource = "*"
      }
    ]
  })
}
