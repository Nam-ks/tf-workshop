terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}


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

#----------------------------------------------------------------------------#
# Kubernetes 추가 Provider
# EKS Cluster 구성 후 초기 구성 작업을 수행하기 위한 Terraform Kubernetes Provider 설정 
# 생성 된 EKS Cluster의 EndPoint 주소 및 인증정보등을 DataSource로 정의 후 Provider 설정 정보로 입력
#----------------------------------------------------------------------------#


# AWS EKS Cluster Data Source
data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

# AWS EKS Cluster Auth Data Source
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

#----------------------------------------------------------------------------#
# 붙일 vpc, name, version, subnet, oidc, worker node정의하여 생성
# 워커 노드 그룹의 최소 최대 요구 개수를 입력받아 변경 가능하고 기본값이 각 242로 지정
# instance_type 기본값은 t3.small 이며 변경가능
#----------------------------------------------------------------------------#
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.12.0"

  # EKS Cluster Setting
  cluster_name                    = "nam-terra-eks"
  cluster_version                 = "~> 20.0"
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  vpc_id                          = module.vpc.vpc_id
  subnet_ids                      = module.vpc.private_subnets.subnet_ids
  
  # OIDC(OpenID Connect) 구성 
  enable_irsa = true
  # EKS Worker Node 정의 ( ManagedNode방식 / Launch Template 자동 구성 )
  eks_managed_node_groups = {
    initial = {
      instance_types         = ["${local.worker_node_instance_type }"]
      create_security_group  = false
      create_launch_template = false 
      launch_template_name   = ""    

      min_size     = "2"
      max_size     = "3"
      desired_size = "2"
    }
  }

  # K8s role 과 연동
  iam_role_arn = "arn:aws:iam::552166050235:role/eksClusterRole"
  
  tags = {
    Name = "${local.tag}_eks_cluster"
  }
}



