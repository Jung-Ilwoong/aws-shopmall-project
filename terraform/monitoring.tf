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
  })]

  depends_on = [module.eks]
}
