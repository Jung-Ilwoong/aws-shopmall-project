terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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
