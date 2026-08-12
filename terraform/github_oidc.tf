# ---------- GitHub Actions가 access key 없이 AWS를 임시로 사용할 수 있게 하는 OIDC 연동 ----------

resource "aws_iam_openid_connect_provider" "github_actions" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  # GitHub Actions OIDC의 루트 CA(DigiCert) thumbprint. AWS가 자체적으로 검증하므로 실질적 의미는 없지만
  # 리소스 스펙상 필수값이라 공식 문서 기재값을 사용한다.
  thumbprint_list = ["1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
}

resource "aws_iam_role" "github_actions" {
  name = "${var.project_name}-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github_actions.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        # main 브랜치로의 push에서 실행되는 워크플로우만 이 Role을 assume 할 수 있음.
        # GitHub가 sub claim에 계정/리포 이름 뒤 숫자 ID를 붙이는 형식을 쓰길래
        # (CloudTrail의 AccessDenied 이벤트로 실제 값을 확인함), 처음엔 그 숫자 부분을
        # 와일드카드(StringLike)로 흡수했었음 — 근데 와일드카드라 "Jung-Ilwoong"으로
        # 시작하는 다른 계정 + "aws-shopmall-project"로 시작하는 다른 리포도 이론상
        # 이 조건을 통과할 수 있는 틈이 있어서, 확인해둔 정확한 숫자 ID로 완전 고정
        # (계정/리포를 지우고 새로 만들지 않는 한 이 ID는 안 바뀜)
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:Jung-Ilwoong@100551482/aws-shopmall-project@1322439962:ref:refs/heads/main"
        }
      }
    }]
  })

  tags = {
    Project = var.project_name
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name = "${var.project_name}-github-actions-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
        ]
        Resource = aws_ecr_repository.app.arn
      },
      {
        Sid      = "EKSDescribe"
        Effect   = "Allow"
        Action   = "eks:DescribeCluster"
        Resource = module.eks.cluster_arn
      },
      {
        Sid    = "FrontendDeploy"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
        ]
        Resource = [
          aws_s3_bucket.frontend.arn,
          "${aws_s3_bucket.frontend.arn}/*",
        ]
      },
      {
        Sid      = "CloudFrontInvalidate"
        Effect   = "Allow"
        Action   = "cloudfront:CreateInvalidation"
        Resource = aws_cloudfront_distribution.frontend.arn
      },
      {
        # ListDistributions는 CloudFront API 특성상 리소스 단위 제한이 안 되고 계정 전체 대상임
        # (배포 시점에 uploads 버킷용 CloudFront 도메인을 동적으로 찾기 위해 필요)
        Sid      = "CloudFrontListForUploadsDomainLookup"
        Effect   = "Allow"
        Action   = "cloudfront:ListDistributions"
        Resource = "*"
      },
    ]
  })
}

# eks:DescribeCluster만으론 kubectl 명령이 실제로 안 먹는다 (IAM != k8s RBAC).
# 이 Role한테 클러스터 안에서 배포를 수정할 수 있는 RBAC 권한을 별도로 부여해야 함.
resource "aws_eks_access_entry" "github_actions" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.github_actions.arn
}

resource "aws_eks_access_policy_association" "github_actions" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.github_actions.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope {
    type = "cluster"
  }
}

output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions.arn
  description = "deploy.yml의 role-to-assume 값으로 사용 (apply 후 GitHub repo variable AWS_ROLE_ARN에 등록)"
}
