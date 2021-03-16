resource "aws_lb" "consul" {
  name               = "consul-lb"
  internal           = false
  load_balancer_type = "network"
  subnets            = var.subnets
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.consul.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.consul_http.arn
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.consul.arn
  port              = "443"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.consul_https.arn
  }
}