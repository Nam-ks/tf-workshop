locals {
  region                    = "ap-northeast-1"
  oidc_provider_arn = var.oidc_provider_arn
  tag               = "nam-terra"
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

variable "oidc_provider_arn" {
  description = "cluster oidc arn"
  type        = string
  default     = "https://E6569989B19EE804C1D6C4CE94EE14EC.gr7.ap-northeast-1.eks.amazonaws.com"
}