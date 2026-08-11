# Shopmall

AWS EKS 위에서 돌아가는 쇼핑몰 서비스. 부트캠프 캡스톤 프로젝트로, 기획부터 인프라·백엔드·프론트엔드·CI/CD·모니터링·보안·비용분석까지 1인이 전 과정을 진행했다.

> **실행 중일 때 접속 주소**
> 프론트: https://mall.woong.shop · 백엔드: https://api.woong.shop
>
> 비용 관리를 위해 필요할 때만 `terraform apply`하고 확인 후 바로 `terraform destroy`하는 방식으로 운영한다. 위 주소가 응답하지 않으면 지금은 인프라가 내려가 있는 상태라는 뜻이다 (자세한 내용은 [`docs/cost-analysis.md`](docs/cost-analysis.md) 참고).

## 주요 기능

- 회원가입 / 로그인 (JWT)
- 상품 목록·검색·카테고리 필터, 상품 상세
- 장바구니 담기·수량변경·삭제, 주문(체크아웃)·주문내역
- 관리자: 상품 등록/수정/삭제, **이미지 업로드**(S3 presigned URL), **AI 상품설명 자동생성**
- **AI 챗봇** — 현재 판매 중인 상품 목록을 참고해서 답변 (RAG 방식)
- HPA 기반 오토스케일링 (부하 테스트로 2→8 파드 스케일 아웃 실증)

## 아키텍처

```
사용자
  ├─ https://mall.woong.shop  (CloudFront → S3, React 정적 호스팅)
  └─ https://api.woong.shop   (Route53 → ALB(WAF) → EKS NodePort → FastAPI 파드)
                                                          │
                                        ┌─────────────────┼─────────────────┐
                                        RDS(MySQL)   Secrets Manager   Claude API
```

- **프론트엔드**: React(Vite) 정적 빌드를 S3에 올리고 CloudFront로 서빙. React Router의 클라이언트 사이드 라우팅을 위해 403/404를 `index.html`로 폴백.
- **백엔드**: FastAPI가 EKS 파드 2~8개(HPA)로 떠 있고, ALB가 앞단에서 HTTPS 종단 + WAF를 통과시킴. `kubectl`이 만든 LoadBalancer Service 대신 **Terraform이 직접 관리하는 ALB**를 NodePort로 연결해서, `destroy` 시 Terraform이 모르는 리소스가 안 남게 설계함.
- **시크릿**: DB 비밀번호·JWT시크릿·Anthropic API 키는 로컬 파일이 아니라 **Secrets Manager**에만 존재하고, 파드가 IRSA(IAM Roles for Service Accounts)로 직접 가져옴.
- **모니터링**: kube-prometheus-stack(Prometheus+Grafana)을 Terraform의 `helm_release`로 클러스터에 직접 설치. `/metrics` 엔드포인트를 ServiceMonitor가 스크래핑.

## 기술 스택

| 영역 | 사용 기술 |
|---|---|
| 프론트엔드 | React (Vite, JS), Tailwind CSS v4, DaisyUI, react-router-dom |
| 백엔드 | FastAPI, SQLAlchemy, PyMySQL, python-jose(JWT), boto3 |
| DB | MySQL (RDS, Single-AZ) |
| 인프라 (IaC) | Terraform (S3 backend + 자체 락), AWS EKS/VPC/RDS/ALB/CloudFront/Route53/WAF/Secrets Manager/Budgets |
| 오케스트레이션 | Kubernetes (EKS), HPA, kube-prometheus-stack, Secrets Store CSI Driver |
| CI/CD | GitHub Actions (OIDC로 AWS 인증, 정적 access key 미사용) |
| AI | Anthropic Claude API (챗봇, 상품설명 생성) |
| 테스트 | pytest (핵심 흐름 20개), CI에 배포 전 테스트 게이트 |

## 프로젝트 구조

```
app/            FastAPI 백엔드
  app/routers/    auth, products, cart, orders, chat
  tests/          pytest (회원가입/로그인/상품/장바구니/주문)
frontend/       React 프론트엔드 (Vite)
terraform/      AWS 인프라 전체 (VPC/EKS/RDS/ALB/CloudFront/WAF/Secrets Manager/모니터링/CI용 IAM 등)
k8s/            Deployment/Service/HPA/SecretProviderClass 매니페스트
.github/workflows/  deploy.yml(백엔드), deploy-frontend.yml(프론트)
monitoring/     ServiceMonitor, Grafana 대시보드 JSON
docs/           비용분석 등 문서
```

## API 개요

| 그룹 | 엔드포인트 |
|---|---|
| `/auth` | `POST /register`, `POST /login`, `GET /me` |
| `/products` | `GET`, `GET /{id}`, `GET /meta/categories`, `POST`\*, `PUT /{id}`\*, `DELETE /{id}`\*, `POST /generate-description`\*, `POST /upload-url`\* |
| `/cart` | `GET`, `POST`, `PUT /{id}`, `DELETE /{id}` |
| `/orders` | `POST`(체크아웃), `GET`, `GET /{id}` |
| `/chat` | `POST` |

\* 관리자 전용

## 로컬 개발 환경 실행

```bash
# 백엔드
cd app
docker compose up -d --build   # FastAPI + MySQL

# 프론트엔드
cd frontend
cp .env.example .env           # VITE_API_URL=http://localhost:8000
npm install
npm run dev
```

## 실제 AWS 배포

```bash
cd terraform
terraform init
terraform apply
```

apply 후 수동으로 해줘야 하는 것:

1. `kubectl apply -f k8s/secretproviderclass.yaml -f k8s/api.yaml` (최초 1회, 이후엔 CI가 처리)
2. GitHub repo **Settings → Secrets and variables → Actions → Variables**에 등록:
   - `AWS_ROLE_ARN`, `FRONTEND_S3_BUCKET`, `VITE_API_URL` — apply마다 값이 그대로 유지됨
   - `FRONTEND_CLOUDFRONT_DISTRIBUTION_ID` — **apply할 때마다 새로 발급되는 값이라 매번 갱신 필요**

이후 `main` 브랜치에 `app/**` 또는 `frontend/**` 변경사항을 push하면 CI/CD가 테스트→빌드→배포까지 자동으로 처리한다.

## CI/CD

- **`deploy.yml`**: `app/**`, `k8s/**` 변경 시 트리거 → pytest 실행(MySQL 서비스 컨테이너) → 통과해야만 → Docker 이미지 빌드/ECR push → EKS 배포
- **`deploy-frontend.yml`**: `frontend/**` 변경 시 트리거 → `npm run build` → S3 sync → CloudFront invalidation
- 두 워크플로우 모두 **GitHub OIDC**로 AWS에 임시 인증하며, 정적 access key를 저장하지 않는다.

## 보안

- WAF (ALB 앞단): AWS 관리형 룰셋(Common/KnownBadInputs/SQLi) + IP당 요청 제한
- Secrets Manager + IRSA: DB/JWT/AI API 키를 파드가 직접 가져오며 로컬에 평문 저장 안 함
- OIDC 기반 CI/CD 인증 (정적 IAM 액세스 키 미사용)
- Bastion은 SSH 대신 SSM Session Manager로만 접근

## 비용

24시간 상시 운영 가정 시 약 $253/월(AWS 공식 요금표 실측), 이 프로젝트는 apply→destroy 사이클로 운영해 실제 지출은 사이클당 $1~2 수준. 서비스별 상세 내역과 산출 근거는 [`docs/cost-analysis.md`](docs/cost-analysis.md) 참고.

## 배운 것 / 트러블슈팅

실제 운영하면서 만나고 고친 문제들 (전부 커밋 로그에 기록됨):

- `kubectl`로 만든 LoadBalancer Service는 Terraform이 모르는 AWS 리소스가 되어 `destroy`를 막음 → NodePort + Terraform 관리 ALB로 설계 변경
- GitHub OIDC의 `sub` claim이 계정/리포 이름에 숫자 ID를 붙이는 형식으로 바뀌어 트러스트 정책이 어긋남 → CloudTrail의 `AssumeRoleWithWebIdentity` 실패 이벤트로 실제 값을 확인해서 수정
- `kubectl set image`만으로는 새로 추가한 환경변수 등 spec 변경이 반영되지 않음 → `kubectl apply` 병행하도록 파이프라인 수정
- CloudFront 도메인은 apply할 때마다 새로 발급되는데 이걸 k8s manifest에 하드코딩해서 이미지가 안 뜨는 버그 발생 → 배포 시점에 AWS에서 동적으로 조회하도록 변경
- Secrets Store CSI Driver의 AWS provider 차트가 driver를 서브차트로 중복 설치하려 함, IRSA 토큰 요청 설정 누락 → 둘 다 실제 에러 메시지 기반으로 원인 파악 후 수정
