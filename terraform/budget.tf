# ---------- 비용 알림 (완전 무료) ----------
# 이 프로젝트는 필요할 때만 apply하고 바로 destroy하는 패턴이라 정상적인 한 달 지출은
# $20을 넘을 일이 거의 없음 (docs/cost-analysis.md 참고). 임계값을 넘었다는 건 뭔가를
# 끄는 걸 깜빡하고 계속 켜뒀다는 신호이므로, 조기에 이메일로 알아차리기 위한 안전망.
resource "aws_budgets_budget" "monthly_cost" {
  name         = "${var.project_name}-monthly-budget"
  budget_type  = "COST"
  limit_amount = "20"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # 이미 20달러의 80%(=16달러)를 실제로 썼을 때
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_alert_email]
  }

  # 이번 달 계속 이 추세로 가면 예산을 넘길 것으로 "예측"될 때 (더 이른 경고)
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.budget_alert_email]
  }
}
