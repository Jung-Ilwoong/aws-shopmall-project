output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "rds_endpoint" {
  value = aws_db_instance.main.endpoint
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "cloudfront_domain" {
  value = aws_cloudfront_distribution.uploads.domain_name
}

output "frontend_cloudfront_domain" {
  value       = aws_cloudfront_distribution.frontend.domain_name
  description = "React 프론트엔드가 서빙되는 CloudFront 도메인"
}

output "frontend_bucket_name" {
  value       = aws_s3_bucket.frontend.bucket
  description = "CI/CD에서 aws s3 sync 대상이 될 버킷 이름"
}

output "frontend_cloudfront_distribution_id" {
  value       = aws_cloudfront_distribution.frontend.id
  description = "CI/CD에서 cloudfront create-invalidation에 쓸 distribution ID"
}

output "api_url" {
  value       = "https://api.woong.shop"
  description = "프론트엔드 VITE_API_URL / CI/CD 변수로 쓸 백엔드 HTTPS 주소"
}

output "frontend_url" {
  value       = "https://mall.woong.shop"
  description = "실제 쇼핑몰 화면 주소 (CloudFront에 커스텀 도메인 연결됨)"
}

output "bastion_instance_id" {
  value       = aws_instance.bastion.id
  description = "aws ssm start-session --target <이 값> 으로 접속"
}

output "grafana_access" {
  value       = "kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80  (admin / var.grafana_admin_password)"
  description = "Grafana 접속 방법 — 별도 도메인 없이 port-forward로 접근"
}
