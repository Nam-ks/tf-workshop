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
  default     = "arn:aws:iam::552166050235:oidc-provider/oidc.eks.ap-northeast-1.amazonaws.com/id/E6569989B19EE804C1D6C4CE94EE14EC"
}


variable "cluster_name" {
  description = "cluster_nam"
  type        = string
  default     = "nam-terra-eks"
}

output "test_ven" {
  value = "${test}"
}