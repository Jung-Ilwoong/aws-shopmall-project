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

output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}
