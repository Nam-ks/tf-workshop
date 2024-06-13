locals {
  region                    = "ap-northeast-1"
  oidc_provider_arn = var.oidc_provider_arn
  tag               = "nam-terra"
}

variable "account_id" {
  description = "account_id"
  type        = string
  default     = ""
}

variable "eks_oidc" {
  description = "eks oidc"
  type        = string
  default     = ""
}

variable "oidc_provider_arn" {
  description = "cluster oidc arn"
  type        = string
  default     = "arn:aws:iam::"
}


variable "cluster_name" {
  description = "cluster_nam"
  type        = string
  default     = "nam-terra-eks"
}
