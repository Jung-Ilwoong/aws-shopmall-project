# ---------- 모니터링 (kube-prometheus-stack: Prometheus + Grafana + Alertmanager) ----------
# 예전엔 k8s-vm(minikube)에서만 설치/테스트했고 실제 EKS 클러스터엔 연결한 적이 없었음.
# kubectl로 수동 설치하지 않고 Terraform의 helm_release로 관리해서, apply/destroy 사이클에
# 다른 리소스와 똑같이 묶이게 함 (수동으로 설치했다가 destroy 때 빠뜨리는 실수 방지).
#
# 영속 스토리지(PVC/EBS)는 의도적으로 설정하지 않음 — 이 프로젝트는 세션마다 클러스터 자체를
# destroy하기 때문에, 굳이 EBS 볼륨을 만들어 추가 비용을 낼 이유가 없음 (destroy되면 어차피
# 메트릭 히스토리도 함께 사라지는 게 자연스러움).
resource "helm_release" "kube_prometheus_stack" {
  # release 이름을 "monitoring"으로 고정 — monitoring/servicemonitor.yaml에 이미
  # `release: monitoring` 라벨이 박혀 있어서(minikube에서 검증된 그대로 재사용), 여기서
  # 이름을 다르게 지으면 Prometheus의 기본 ServiceMonitor 셀렉터와 라벨이 어긋날 수 있음.
  name             = "monitoring"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "88.2.0"
  namespace        = "monitoring"
  create_namespace = true

  values = [yamlencode({
    grafana = {
      adminPassword = var.grafana_admin_password
    }

    # 차트 기본 Alertmanager 설정은 receiver가 "null"이라, 규칙이 터져도 아무한테도 안 감.
    # Gmail을 SMTP 릴레이로 써서 실제로 이메일이 나가게 함 (SES는 아직 도메인 인증 등
    # 준비가 안 돼있어서, 개인 프로젝트 규모엔 Gmail 앱 비밀번호가 제일 빠름).
    alertmanager = {
      config = {
        global = {
          resolve_timeout    = "5m"
          smtp_smarthost     = "smtp.gmail.com:587"
          smtp_from          = var.gmail_smtp_username
          smtp_auth_username = var.gmail_smtp_username
          smtp_auth_password = replace(var.gmail_smtp_app_password, " ", "")
          smtp_require_tls   = true
        }
        route = {
          receiver        = "email"
          group_by        = ["namespace"]
          group_wait      = "30s"
          group_interval  = "5m"
          repeat_interval = "12h"
          routes = [
            { matchers = ["alertname = \"Watchdog\""], receiver = "null" }
          ]
        }
        receivers = [
          { name = "null" },
          {
            name = "email"
            email_configs = [
              { to = var.alert_email }
            ]
          }
        ]
      }
    }

    # shopmall-api 전용 알림 규칙 (차트 기본 규칙은 클러스터 인프라 레벨만 다뤄서, 앱
    # 레벨은 직접 정의해야 함)
    additionalPrometheusRulesMap = {
      shopmall-rules = {
        groups = [
          {
            name = "shopmall-api"
            rules = [
              {
                alert = "ShopmallApiDown"
                expr  = "kube_deployment_status_replicas_available{deployment=\"shopmall-api\"} == 0"
                for   = "2m"
                labels = { severity = "critical" }
                annotations = {
                  summary     = "shopmall-api 파드가 전부 죽었습니다"
                  description = "2분 넘게 사용 가능한 shopmall-api 파드가 0개입니다."
                }
              },
              {
                alert = "ShopmallApiHighErrorRate"
                expr = join("", [
                  "sum(rate(http_requests_total{status=\"5xx\"}[5m])) ",
                  "/ sum(rate(http_requests_total[5m])) > 0.05 ",
                  "and sum(rate(http_requests_total[5m])) > 0"
                ])
                for    = "5m"
                labels = { severity = "warning" }
                annotations = {
                  summary     = "shopmall-api 5xx 에러율이 5%를 넘었습니다"
                  description = "최근 5분간 요청 중 5% 이상이 5xx 에러입니다."
                }
              },
              {
                alert = "ShopmallApiHpaMaxedOut"
                expr = join("", [
                  "kube_horizontalpodautoscaler_status_current_replicas{horizontalpodautoscaler=\"shopmall-api-hpa\"} ",
                  "== kube_horizontalpodautoscaler_spec_max_replicas{horizontalpodautoscaler=\"shopmall-api-hpa\"}"
                ])
                for    = "10m"
                labels = { severity = "warning" }
                annotations = {
                  summary     = "shopmall-api HPA가 10분 넘게 최대치입니다"
                  description = "파드가 최대(8개)로 계속 유지되고 있어 트래픽이 지속적으로 높습니다. 스케일 정책 재검토가 필요할 수 있습니다."
                }
              }
            ]
          }
        ]
      }
    }
  })]

  depends_on = [module.eks]
}

# ---------- metrics-server ----------
# Prometheus와는 별개로, HPA(HorizontalPodAutoscaler)가 CPU/메모리 사용률을 읽으려면
# metrics.k8s.io API를 제공하는 metrics-server가 반드시 필요함. EKS는 이걸 기본 제공하지
# 않음 (직접 확인: 이거 없이는 `kubectl top`도, HPA의 CPU 타겟도 계속 <unknown>으로 뜸).
resource "helm_release" "metrics_server" {
  name             = "metrics-server"
  repository       = "https://kubernetes-sigs.github.io/metrics-server/"
  chart            = "metrics-server"
  version          = "3.13.1"
  namespace        = "kube-system"
  create_namespace = false

  depends_on = [module.eks]
}
