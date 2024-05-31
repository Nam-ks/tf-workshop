locals {
  region           = "ap-northeast-2"
  azs              = ["ap-northeast-2a", "ap-northeast-2c"]
  tag              = "nam-terra"
  worker_node_instance_type = "t3.small"
  cluster_admin = "552166050235"
}

variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
  default     = "my-cluster"
}

variable "cluster_version" {
  description = "The Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.23"
}
variable "cluster_admin" {
  description = "The AWS Account ID for the cluster admin"
  type        = string
}
