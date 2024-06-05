locals {
  region                    = var.region
  azs                       = ["ap-northeast-1a", "ap-northeast-1c"]
  cidr                      = var.cidr
  public_subnets            = var.public_subnets
  private_subnets           = var.private_subnets
  tag                       = var.tag
  worker_node_instance_type = var.worker_node_instance_type
  bastion_instance_type     = var.bastion_instance_type
  account_id                = var.account_id
  any_protocol              = "-1"
  tcp_protocol              = "tcp"
  ssh_port                  = "22"
  icmp_protocol             = "icmp"
  all_network               = "0.0.0.0/0"
}


variable "region" {
  description = "region"
  type        = string
  default = "ap-northeast-1"
}

variable "azs" {
  description = "azs"
  type        = list(any)
  default = ["ap-northeast-1a", "ap-northeast-1c"]
}

variable "cidr" {
  description = "VPC CIDR BLOCK"
  type        = string
  default = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "VPC Public Subnets"
  type        = list(any)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  description = "VPC Private subnets"
  type        = list(any)
  default = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "tag" {
  description = "tag_for_resource"
  type        = string
  default     = "nam-terra"
}

variable "worker_node_instance_type" {
  description = "worker node instance_types"
  type        = string
  default     = "t3.small"
}

variable "bastion_instance_type" {
  description = "bastion host instance_types"
  type        = string
  default     = "t3.small"
}

variable "account_id" {
  description = "account_id"
  type        = string
  default     = "552166050235"
}
