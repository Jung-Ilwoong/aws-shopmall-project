data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "uploads" {
  bucket        = "${var.project_name}-uploads-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Project = var.project_name
  }
}

resource "aws_s3_bucket_public_access_block" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 백엔드 파드가 presigned URL을 발급하려면, 그 URL 서명에 쓰이는 자격증명(EKS 노드 IAM 역할,
# 이 프로젝트는 IRSA 대신 노드 역할을 그대로 씀)에 실제 PutObject 권한이 있어야 함
# 브라우저가 presigned URL로 이 버킷에 직접 PUT하려면 CORS 허용이 필요함
# (없으면 브라우저가 응답에 Access-Control-Allow-Origin이 없다고 보고 요청을 막음)
resource "aws_s3_bucket_cors_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  cors_rule {
    allowed_methods = ["PUT"]
    allowed_origins = ["https://mall.woong.shop", "http://localhost:5173"]
    allowed_headers = ["*"]
  }
}

# (예전엔 이미지 업로드용 S3 권한을 EKS 노드 역할에 붙였었는데, secrets.tf에서 파드에
# IRSA(shopmall-app-secrets-role)를 붙인 뒤로는 파드가 노드 역할을 더 이상 안 써서
# 여기 권한은 무의미해짐 — 실제로 이것 때문에 업로드가 막혔던 걸 확인하고 IRSA 역할
# 쪽으로 권한을 옮김 (terraform/secrets.tf의 aws_iam_role_policy.app_secrets 참고))

resource "aws_cloudfront_origin_access_control" "uploads" {
  name                              = "${var.project_name}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "uploads" {
  enabled = true

  origin {
    domain_name              = aws_s3_bucket.uploads.bucket_regional_domain_name
    origin_id                = "s3-uploads"
    origin_access_control_id = aws_cloudfront_origin_access_control.uploads.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-uploads"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Project = var.project_name
  }
}

resource "aws_s3_bucket_policy" "uploads" {
  bucket = aws_s3_bucket.uploads.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowCloudFrontServicePrincipal"
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.uploads.arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.uploads.arn
        }
      }
    }]
  })
}

# ---------- 프론트엔드 정적 호스팅 (React 빌드 결과물) ----------

resource "aws_acm_certificate" "frontend" {
  provider          = aws.us_east_1
  domain_name       = "mall.woong.shop"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Project = var.project_name
  }
}

resource "aws_route53_record" "frontend_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.frontend.domain_validation_options : dvo.domain_name => {
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

resource "aws_acm_certificate_validation" "frontend" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.frontend.arn
  validation_record_fqdns = [for r in aws_route53_record.frontend_cert_validation : r.fqdn]
}

resource "aws_s3_bucket" "frontend" {
  bucket        = "${var.project_name}-frontend-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Project = var.project_name
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${var.project_name}-frontend-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  default_root_object = "index.html"
  aliases             = ["mall.woong.shop"]

  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "s3-frontend"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-frontend"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  # React Router가 처리하는 클라이언트 사이드 경로(/products/3 등)는 S3엔 실제 파일이 없어
  # 403/404가 나므로, index.html로 되돌려보내 React Router가 대신 처리하게 한다
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.frontend.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Project = var.project_name
  }
}

resource "aws_route53_record" "frontend" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "mall.woong.shop"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.frontend.domain_name
    zone_id                = aws_cloudfront_distribution.frontend.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowCloudFrontServicePrincipal"
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.frontend.arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.frontend.arn
        }
      }
    }]
  })
}
