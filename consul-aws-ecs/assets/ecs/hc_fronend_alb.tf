#
#  Service ALB
#
resource "aws_alb" "alb_frontend" {
  name               = "alb-hc-frontend" # Naming our load balancer
  load_balancer_type = "application"
  subnets = data.terraform_remote_state.vpc.outputs.public_subnets
  # Referencing the security group
  security_groups = ["${module.ecs-cluster.sg_ecs_id}"]
}
resource "aws_lb_target_group" "lb_tg_frontend" {
  name        = "alb-tg-hc-frontend"
  port        = 80
  protocol    = "HTTP"
  #target_type = "ip"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id
  health_check {
    matcher = "200,301,302"
    path = "/"
    #healthy_threshold   = "3"
    #interval            = "10"
    #protocol            = "HTTP"
    #unhealthy_threshold = "3"
  }
}
resource "aws_lb_listener" "listener_frontend" {
  load_balancer_arn = "${aws_alb.alb_frontend.arn}" # Referencing our load balancer
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.lb_tg_frontend.arn}" # Referencing our tagrte group
  }
}