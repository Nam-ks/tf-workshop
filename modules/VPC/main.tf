#----------------------------------------------------------------------------------#
# vpc를 구성하는 모듈이며 name, cidr, 퍼블릭 및 프라이빗 cidr값을 입력해주어야한다.
# 태그에는 필요한 태그값들을 미리 지정 ( 테라폼 관리임을 명시 )
#----------------------------------------------------------------------------------#
# VPC
module "vpc" {
  source                             = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"
  name                               = "nam-terra-vpc"
  azs                                = local.azs
  cidr                               = local.cidr
  public_subnets                     = local.public_subnets
  private_subnets                    = local.private_subnets
  enable_nat_gateway = true
  single_nat_gateway = true
  one_nat_gateway_per_az = false
  private_route_table_tags = {
    "TerraformManaged" = "True"
    "Name"             = "${local.tag}_private_route_table"
  }
  private_subnet_tags = {
    "TerraformManaged" = "True"
    "Name"             = "${local.tag}_private_subnets"
  }
  public_route_table_tags = {
    "TerraformManaged" = "True"
    "Name"             = "${local.tag}_public_route_table"
  }
  public_subnet_tags = {
    "TerraformManaged" = "True"
    "Name"                   = "${local.tag}_public_subnets"
  }
  igw_tags = {
    "TerraformManaged" = "True"
    "Name"             = "${local.tag}_IGW"
  }
  enable_dns_hostnames = "true"
  enable_dns_support   = "true"
  tags = {
    "TerraformManaged" = "True"
    "Name"             = "${local.tag}_VPC"
  }
}


