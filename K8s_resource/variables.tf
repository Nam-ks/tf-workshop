locals {
  region                    = "ap-northeast-1"
  oidc_provider_arn = var.eks_oidc
  tag               = "nam-terra"
  account_id                = var.account_id
}

variable "account_id" {
  description = "account_id"
  type        = string
  default     = "552166050235"
}

variable "eks_oidc" {
  description = "eks oidc"
  type        = string
  default     = "E6569989B19EE804C1D6C4CE94EE14EC"
}