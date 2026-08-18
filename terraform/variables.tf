variable "region" {
  type    = string
  default = "ap-northeast-2"
}

variable "project_name" {
  type    = string
  default = "shopmall"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "azs" {
  type    = list(string)
  default = ["ap-northeast-2a", "ap-northeast-2c"]
}

variable "public_subnets" {
  type    = list(string)
  default = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnets" {
  type    = list(string)
  default = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "node_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 6
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_name" {
  type    = string
  default = "shopmall"
}

variable "db_username" {
  type    = string
  default = "admin"
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "grafana_admin_password" {
  type      = string
  sensitive = true
}

variable "budget_alert_email" {
  type = string
}

variable "jwt_secret" {
  type      = string
  sensitive = true
}

variable "gmail_smtp_username" {
  type      = string
  sensitive = true
}

variable "gmail_smtp_app_password" {
  type      = string
  sensitive = true
}

variable "alert_email" {
  type    = string
  default = "jiw3052@gmail.com"
}

variable "anthropic_api_key" {
  type      = string
  sensitive = true
}
