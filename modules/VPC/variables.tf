locals {
  region           = "ap-northeast-2"
  azs              = ["ap-northeast-2a", "ap-northeast-2c"]
  cidr             = "10.10.0.0/16"
  public_subnets   = ["10.10.1.0/24", "10.10.2.0/24"]
  private_subnets  = ["10.10.11.0/24", "10.10.12.0/24"]
  tag              = "nam-terra"
}

variable "name" {
  description = "VPC name"
  type        = string
}

variable "cidr" {
  description = "VPC CIDR BLOCK"
  type        = string
}

variable "public_subnets" {
  description = "VPC Public Subnets"
  type        = list(any)
}

variable "private_subnets" {
  description = "VPC Private Subnets"
  type        = list(any)
}