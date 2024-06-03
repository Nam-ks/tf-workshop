terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = local.region
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
# 붙일 vpc, name, version, subnet, oidc, worker node정의하여 생성
# 워커 노드 그룹의 최소 최대 요구 개수를 입력받아 변경 가능하고 기본값이 각 232로 지정
# role은 미리 정의하여 배포되어 있다고 가정
#----------------------------------------------------------------------------#
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.12.0"

  # EKS Cluster Setting
  cluster_name                    = "nam-terra-eks"
  cluster_version                 = "1.29"
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  vpc_id                          = module.vpc.vpc_id
  subnet_ids                      = module.vpc.private_subnets
  
  # OIDC(OpenID Connect) 구성 
  enable_irsa = true
  #EKS Worker Node 정의 ( ManagedNode방식 / Launch Template 자동 구성 )
  eks_managed_node_groups = {
    # 그룹 이름(?) 
    initial = {
    #  instance_types         = ["${local.worker_node_instance_type }"]
    ami_type                   = "AL2_x86_64"
    instance_types             = ["t3.medium"] 
      create_security_group  = false
      use_name_prefix            = false
    #  create_launch_template = false
      launch_template_name   = "nam_temp_null_terra"

      min_size     = "2"
      max_size     = "3"
      desired_size = "2"
    }
  }
  #role 생성 false
  create_iam_role = false
  # 기존에 있던 role matching 
  iam_role_arn = "arn:aws:iam::552166050235:role/eksClusterRole"
  kms_key_aliases = "eks1/nam-terra-eks"
  tags = {
    Name = "${local.tag}_eks_cluster"
  }
}


#----------------------------------------------------------------------------#
# bastionhost 보안 그룹 정의 ( 어디든 접근 가능 ) , eip 할당
# key pair 로 ec2 생성 및 설정 후 data 참조로 아웃풋 지정
#----------------------------------------------------------------------------#

# Security-Group (BastionHost)
module "BastionHost_SG" {
  source          = "terraform-aws-modules/security-group/aws"
  version         = "5.1.0"
  name            = "${local.tag}-BastionHost-Security"
  description     = "BastionHost_SG"
  vpc_id          = module.vpc.vpc_id
  use_name_prefix = "false"

  ingress_with_cidr_blocks = [
    {
      from_port   = local.ssh_port
      to_port     = local.ssh_port
      protocol    = local.tcp_protocol
      description = "SSH"
      cidr_blocks = local.all_network
    },
    {
      from_port   = local.any_protocol
      to_port     = local.any_protocol
      protocol    = local.icmp_protocol
      description = "ICMP"
      cidr_blocks = local.cidr
    },

  ]
  tags = {
    Name = "${local.tag}_bastionhost_sg"
  }
}

# BastionHost EIP
resource "aws_eip" "BastionHost_eip" {
  instance = aws_instance.BastionHost.id
  tags = {
    Name = "${local.tag}_bastionhost_EIP"
  }
}

# BastionHost Key-Pair DataSource
data "aws_key_pair" "EC2-Key" {
  key_name = "vault_lab_nam_key"
}

# BastionHost Instance
# EKS Cluster SG : data.aws_eks_cluster.cluster.vpc_config[0].cluster_security_group_id 
resource "aws_instance" "BastionHost" {
  ami                         = "ami-0b9a26d37416470d2"
  instance_type               = local.bastion_instance_type
  key_name                    = data.aws_key_pair.EC2-Key.key_name
  subnet_id                   = local.public_subnets[0].id
  associate_public_ip_address = true
  vpc_security_group_ids      = [module.BastionHost_SG.security_group_id, module.eks.cluster_security_group_id]

  tags = {
    Name = "${local.tag}_bastion_host"
  }
}

