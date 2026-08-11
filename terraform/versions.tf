terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.15"
    }
  }

  # state 파일을 로컬이 아니라 S3에 저장 (이 노트북이 없어져도 인프라 추적 가능하게).
  # use_lockfile: 동시에 두 명(또는 두 프로세스)이 apply 못 하게 막는 락을 S3 자체 기능으로
  # 처리 (Terraform 1.10+). 예전엔 DynamoDB 테이블이 따로 필요했지만 이제는 불필요.
  backend "s3" {
    bucket       = "shopmall-terraform-state-092042969614"
    key          = "shopmall/terraform.tfstate"
    region       = "ap-northeast-2"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = var.region
}

# CloudFront에 붙일 ACM 인증서는 리전이 반드시 us-east-1이어야 함 (AWS 고정 제약)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

# helm_release가 EKS 클러스터에 직접 붙어서 차트를 설치할 수 있게 인증 방법을 알려줌.
# kubeconfig 파일 대신 매번 aws CLI로 임시 토큰을 받아오는 방식(exec) — 로컬 kubeconfig
# 상태에 의존하지 않아서 CI에서 그대로 재사용 가능.
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.region]
    }
  }
}
