# ---------- WAF (ALB 앞단 — 실제 로그인/DB조회가 일어나는 백엔드 API를 보호) ----------
# CloudFront(프론트)가 아니라 ALB(백엔드)에 붙인 이유: 정적 파일만 서빙하는 프론트보다,
# 로그인/검색/장바구니처럼 사용자 입력을 받아 DB까지 가는 백엔드 API 쪽이 실제 공격 표면임.
# ALB에 붙는 WAF는 스코프가 REGIONAL이라 us-east-1 provider가 필요 없음 (CloudFront용
# 리소스와 달리 이 스택 기본 리전 그대로 사용).
resource "aws_wafv2_web_acl" "api" {
  name        = "${var.project_name}-api-waf"
  description = "WAF protecting the backend API ALB"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # 일반적인 웹 공격 패턴(XSS, LFI 등) 차단
  rule {
    name     = "AWS-CommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # 알려진 악성 요청 패턴 차단
  rule {
    name     = "AWS-KnownBadInputs"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "KnownBadInputs"
      sampled_requests_enabled   = true
    }
  }

  # SQL 인젝션 차단 — 상품 검색(/products?search=)이 사용자 입력을 SQL 쿼리에 사용하므로
  # SQLAlchemy의 파라미터 바인딩과는 별개로 방어 계층을 하나 더 둠
  rule {
    name     = "AWS-SQLiRuleSet"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "SQLiRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # IP당 5분에 2000건 넘게 요청하면 차단 — 로그인 무차별 대입 등 남용 방지
  rule {
    name     = "RateLimit"
    priority = 4

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-api-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Project = var.project_name
  }
}

resource "aws_wafv2_web_acl_association" "api" {
  resource_arn = aws_lb.api.arn
  web_acl_arn  = aws_wafv2_web_acl.api.arn
}
