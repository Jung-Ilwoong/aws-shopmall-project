# ---------- 백엔드 HTTPS 종단 (ALB + ACM, woong.shop 도메인) ----------
# 프론트엔드가 CloudFront(HTTPS)로 서빙되는데 백엔드가 HTTP면 브라우저가 Mixed Content로 요청을
# 차단한다. 그래서 백엔드도 도메인 기반 HTTPS 엔드포인트가 필요함.
#
# EKS 앞에 ALB를 붙이는 표준 방법은 AWS Load Balancer Controller + Ingress지만, 이 프로젝트는
# "kubectl로 만든 리소스는 Terraform에 안 보여서 destroy가 막힌다"를 이미 한 번 겪었기 때문에
# (k8s LoadBalancer Service로 생긴 고아 ELB 이슈), 이번엔 ALB를 Terraform이 직접 관리하고
# EKS 노드의 NodePort로 트래픽을 전달하는 방식을 쓴다. 전부 Terraform 안에서 생성/삭제됨.

data "aws_route53_zone" "main" {
  name         = "woong.shop"
  private_zone = false
}

resource "aws_acm_certificate" "api" {
  domain_name       = "api.woong.shop"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Project = var.project_name
  }
}

resource "aws_route53_record" "api_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.api.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = data.aws_route53_zone.main.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "api" {
  certificate_arn         = aws_acm_certificate.api.arn
  validation_record_fqdns = [for r in aws_route53_record.api_cert_validation : r.fqdn]
}

resource "aws_security_group" "alb" {
  name   = "${var.project_name}-alb-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project = var.project_name
  }
}

# ALB가 EKS 노드의 NodePort(30080, k8s/api.yaml의 shopmall-api Service)로 트래픽을 전달하도록 허용
resource "aws_security_group_rule" "node_nodeport_from_alb" {
  type                     = "ingress"
  from_port                = 30080
  to_port                  = 30080
  protocol                 = "tcp"
  security_group_id        = module.eks.node_security_group_id
  source_security_group_id = aws_security_group.alb.id
}

resource "aws_lb" "api" {
  name               = "${var.project_name}-api-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnets

  tags = {
    Project = var.project_name
  }
}

resource "aws_lb_target_group" "api" {
  name        = "${var.project_name}-api-tg"
  port        = 30080
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "instance"

  health_check {
    path                = "/health"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 5
  }

  tags = {
    Project = var.project_name
  }
}

# EKS 노드 오토스케일링 그룹을 타겟 그룹에 연결 — 노드가 늘거나 줄어도 자동으로 등록/해제됨
resource "aws_autoscaling_attachment" "api" {
  autoscaling_group_name = module.eks.eks_managed_node_groups_autoscaling_group_names[0]
  lb_target_group_arn    = aws_lb_target_group.api.arn
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.api.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.api.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.api.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_route53_record" "api" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "api.woong.shop"
  type    = "A"

  alias {
    name                   = aws_lb.api.dns_name
    zone_id                = aws_lb.api.zone_id
    evaluate_target_health = true
  }
}
