terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
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
