# NLB
resource "aws_lb" "test_nlb" {
  name               = var.nlb_name
  internal           = var.nlb_internal
  load_balancer_type = "network"
  subnets            = var.public_subnet_ids

  enable_deletion_protection       = false
  enable_cross_zone_load_balancing = var.enable_cross_zone_load_balancing

  tags = {
    Name        = var.nlb_name
    Environment = var.environment
    Project     = var.project_name
    Purpose     = "TEST-EC2-LoadBalancer"
  }
}

# Target Group
resource "aws_lb_target_group" "test_ec2_tg" {
  name        = "${var.project_name}-test-ec2-tg"
  port        = var.target_port
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
    protocol            = "TCP"
    port                = "traffic-port"
  }

  deregistration_delay = 30

  tags = {
    Name        = "${var.project_name}-test-ec2-tg"
    Environment = var.environment
    Project     = var.project_name
  }
}

# atach TEST EC2 to target group
resource "aws_lb_target_group_attachment" "test_ec2_attachment" {
  target_group_arn = aws_lb_target_group.test_ec2_tg.arn
  target_id        = var.ec2_instance_id
  port             = var.target_port
}

# Listener for HTTP traffic
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.test_nlb.arn
  port              = var.listener_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.test_ec2_tg.arn
  }

  tags = {
    Name        = "${var.project_name}-nlb-http-listener"
    Environment = var.environment
    Project     = var.project_name
  }
}