resource "aws_lb" "admin-alb" {
  name     = "admin-alb-${var.Env-Name}"
  internal = false
  subnets  = var.subnet-ids

  security_groups = [
    aws_security_group.admin-alb-in.id,
    aws_security_group.admin-alb-out.id,
  ]

  load_balancer_type = "application"

  tags = {
    Name = "admin-alb-${var.Env-Name}"
  }
}

resource "aws_alb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.admin-alb.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate_validation.certificate.certificate_arn
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"

  default_action {
    target_group_arn = aws_alb_target_group.admin-tg.arn
    type             = "forward"
  }
}

