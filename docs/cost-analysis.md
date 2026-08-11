# AWS 인프라 비용 분석

Shopmall 캡스톤 프로젝트의 실측 요금 기반 비용 분석. 시각화된 버전은 별도 아티팩트로 공유됨.

## 요약

| 구분 | 비용 |
|---|---|
| 24시간 상시 운영 시 (월) | 약 $243 (약 ₩335,000, 환율 1,380원 가정) |
| 이 프로젝트 실제 지출 | 약 $2 내외 (apply→destroy 사이클 2회, 총 5~6시간 가동) |

## 서비스별 월 환산 비용 (24시간 상시 운영 기준)

단가는 `aws pricing get-products` (AWS Price List API)로 `ap-northeast-2` 리전을 2026-08-11 직접 조회한 실제 공개 요금표. 월 환산은 730시간(=365일÷12개월×24시간) 기준.

| 서비스 | 단가 | 월 환산 |
|---|---|---|
| EKS 컨트롤플레인 | $0.100/hr | $73.00 |
| EKS 워커노드 (t3.medium ×2) | $0.052/hr ×2 | $75.92 |
| NAT Gateway | $0.059/hr | $43.07 |
| RDS db.t3.micro (Single-AZ MySQL) | $0.026/hr | $18.98 |
| ALB | $0.0225/hr | $16.43 |
| Bastion (t3.micro) | $0.013/hr | $9.49 |
| RDS 스토리지 (gp2 20GB) | $0.131/GB | $2.62 |
| CloudFront ×2 (데모 트래픽 추정) | 종량 | ≈$1.00 |
| KMS 키 (EKS 시크릿 암호화) | $1.00/월 | $1.00 |
| Route53 호스팅 영역 | $0.50/월 | $0.50 |
| S3 · ECR (저장용량 소량) | 종량 | ≈$0.15 |
| CloudWatch Logs (EKS 컨트롤플레인 audit/api/authenticator) | $0.76/GB 수집 | ≈$1.00 |
| ACM 인증서 ×2 · IAM · OIDC | 무료 | $0.00 |
| **합계** | | **$243.16** |

데이터 전송량, ALB LCU 등 트래픽 종량 항목은 실사용량에 따라 달라져 합계에서 제외.

**CloudWatch Logs는 의도적으로 설정한 적이 없는데도 이미 쓰이고 있었음** — `terraform-aws-modules/eks` 모듈이 `cluster_enabled_log_types`를 `["audit", "api", "authenticator"]`로, 보관기간을 90일로 기본 설정해서 자동으로 컨트롤플레인 로그를 CloudWatch Logs에 보내고 있었다. 애플리케이션 로그·메트릭은 여전히 CloudWatch가 아닌 Prometheus/Grafana를 의도적으로 사용 중이며, 이 발견 이후에도 컨트롤플레인 로그는 그대로 두기로 함 (트래픽이 적어 실비용 영향이 미미함).

## 실제로 비용을 낮춘 방법

- **필요할 때만 apply, 확인 끝나면 destroy** — EKS·NAT·RDS·ALB는 전부 시간당 과금이라, 안 쓸 때 꺼두는 것만으로 비용 대부분이 사라짐. 완전한 apply→destroy 사이클을 2회 거침 (2026-08-05, 2026-08-10).
- **S3 `force_destroy`, ECR `force_delete`** — 비어있지 않은 버킷/레포가 destroy를 막는 걸 방지. 이 설정이 없어서 destroy가 3번 실패했던 경험이 있어 처음부터 적용.
- **NodePort + Terraform 관리 ALB, kubectl LoadBalancer 미사용** — kubectl로 LoadBalancer 타입 Service를 만들면 Terraform이 모르는 AWS 리소스(ELB)가 생겨 destroy가 막힘. 이 구조를 피해서 두 번째 destroy는 재시도 없이 한 번에 완료.
- **Terraform state를 S3(+자체 락)로 이전, DynamoDB는 미사용** — state 저장/락 비용은 안 쓰는 동안 사실상 $0.

## 아직 반영 안 한 항목의 예상 추가 비용

| 항목 | 예상 추가 비용 | 비고 |
|---|---|---|
| WAF | +$5~10/월 | 기본 규칙 세트 기준, 리퀘스트 처리량에 따라 변동 |
| Secrets Manager | +$0.40/시크릿 | 현재 k8s Secret 평문 대신 사용 시. API 호출 비용 별도 소액 |
| AWS Budgets | 무료 | 예산 알림 2개까지 무료 — 비용 대비 가장 먼저 추가할 가치 있음 |

## 방법론 / 한계

- 모든 단가는 추정이 아닌 AWS Price List API 실측값 (2026-08-11 기준)
- 원화 환산은 1,380원/달러 가정치로 실제 환율과 다를 수 있음
- "실제 지출" 값은 두 세션의 apply~destroy 경과시간을 추정해 월 비용에 비례 배분한 근사치. AWS Cost Explorer의 실제 청구 데이터는 반영까지 24~48시간이 걸려 이 문서 작성 시점엔 집계되지 않음 — 확정되는 대로 대조 예정
