# ---------- Secrets Manager 연동 ----------
# 이전엔 DB 비밀번호/JWT시크릿/Anthropic 키가 k8s/api-secret.yaml에 평문으로 적혀서 로컬
# 디스크에 존재했고, 그걸 손으로 kubectl apply 해야 했음. 이제 값은 Secrets Manager에만
# 존재하고, 파드가 뜰 때 IAM 권한(IRSA)으로 직접 가져가도록 바꿈 — 로컬에 평문 파일이
# 남을 일이 없고, 접근 권한/조회 이력(CloudTrail)도 IAM으로 통제됨.

resource "aws_secretsmanager_secret" "app" {
  name                    = "${var.project_name}/app-secrets"
  recovery_window_in_days = 0 # 데모/캡스톤 특성상 destroy 후 바로 재생성 가능해야 해서 즉시 삭제

  tags = {
    Project = var.project_name
  }
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id
  secret_string = jsonencode({
    DB_HOST           = aws_db_instance.main.address
    DB_PORT           = "3306"
    DB_USER           = var.db_username
    DB_PASSWORD       = var.db_password
    DB_NAME           = var.db_name
    JWT_SECRET        = var.jwt_secret
    ANTHROPIC_API_KEY = var.anthropic_api_key
  })
}

# ---------- IRSA: 이 파드(shopmall-api ServiceAccount)만 위 시크릿을 읽을 수 있게 허용 ----------
resource "aws_iam_role" "app_secrets" {
  name = "${var.project_name}-app-secrets-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = module.eks.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:default:shopmall-api"
          "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = {
    Project = var.project_name
  }
}

resource "aws_iam_role_policy" "app_secrets" {
  name = "${var.project_name}-app-secrets-policy"
  role = aws_iam_role.app_secrets.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      Resource = aws_secretsmanager_secret.app.arn
    }]
  })
}

# 백엔드 파드가 이 ServiceAccount를 쓰면(k8s/api.yaml의 serviceAccountName) 위 IAM 역할을
# 자동으로 가정하게 됨. YAML에 역할 ARN을 직접 적을 필요가 없어서, apply할 때마다 값이
# 바뀌어 수동으로 고쳐줘야 했던 UPLOADS_CLOUDFRONT_DOMAIN 같은 문제가 애초에 안 생김.
resource "kubernetes_service_account_v1" "app" {
  metadata {
    name      = "shopmall-api"
    namespace = "default"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.app_secrets.arn
    }
  }

  depends_on = [module.eks]
}

# ---------- Secrets Store CSI Driver: 파드가 시작할 때 Secrets Manager 값을 가져와서
# 네이티브 k8s Secret으로 동기화해주는 역할 ----------
resource "helm_release" "secrets_store_csi_driver" {
  name       = "csi-secrets-store"
  repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart      = "secrets-store-csi-driver"
  version    = "1.6.0"
  namespace  = "kube-system"

  set {
    name  = "syncSecret.enabled"
    value = "true" # SecretProviderClass의 secretObjects로 네이티브 Secret 동기화 활성화
  }

  # IRSA로 AWS 인증하려면 파드에 sts.amazonaws.com 대상 토큰이 필요한데, 차트 기본값엔
  # 이게 빠져있어서 CSIDriver의 tokenRequests가 비어있었음 (실제 apply 후 "CSI token error:
  # serviceAccount.tokens not provided" 에러로 확인) — 명시적으로 켜줘야 함
  set {
    name  = "tokenRequests[0].audience"
    value = "sts.amazonaws.com"
  }

  depends_on = [module.eks]
}

resource "helm_release" "secrets_store_csi_driver_provider_aws" {
  name       = "secrets-provider-aws"
  repository = "https://aws.github.io/secrets-store-csi-driver-provider-aws"
  chart      = "secrets-store-csi-driver-provider-aws"
  version    = "3.1.2"
  namespace  = "kube-system"

  # 이 차트는 secrets-store-csi-driver를 서브차트로 내장하고 있어서, 기본값 그대로 두면
  # 위에서 이미 따로 설치한 driver와 똑같은 이름의 ServiceAccount를 또 만들려다 충돌함
  # (실제로 apply해보고 겪은 에러) — 내장된 서브차트 설치를 꺼서 driver는 하나만 존재하게 함
  set {
    name  = "secrets-store-csi-driver.install"
    value = "false"
  }

  depends_on = [helm_release.secrets_store_csi_driver]
}
