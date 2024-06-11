terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = local.region
}

#----------------------------------------------------------------------------------#
# vpc를 구성하는 모듈
#----------------------------------------------------------------------------------#
# VPC
module "vpc" {
  source                 = "terraform-aws-modules/vpc/aws"
  version                = "5.8.1"
  name                   = "${local.tag}-vpc"
  azs                    = local.azs
  cidr                   = local.cidr
  public_subnets         = local.public_subnets
  private_subnets        = local.private_subnets
  enable_nat_gateway     = true
  single_nat_gateway     = true
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
    "Name"             = "${local.tag}_public_subnets"
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
# eks 보안그룹 ( all / all )
#----------------------------------------------------------------------------#
# Security-Group (eks)
module "eks_SG" {
  source          = "terraform-aws-modules/security-group/aws"
  version         = "5.1.0"
  name            = "${local.tag}-cluster-security-group"
  description     = "eks_SG"
  vpc_id          = module.vpc.vpc_id
  use_name_prefix = "false"

  ingress_with_cidr_blocks = [
    {
      from_port   = local.any_protocol
      to_port     = local.any_protocol
      protocol    = local.any_protocol
      description = "all"
      cidr_blocks = local.all_network
    },
  ]
  egress_with_cidr_blocks = [
    {
      from_port   = local.any_protocol
      to_port     = local.any_protocol
      protocol    = local.any_protocol
      description = "all"
      cidr_blocks = local.all_network
    },
  ]
  tags = {
    Name = "${local.tag}_eks_sg"
  }
}


#--------------------------------------------------------------------------------------------------#
# block
#--------------------------------------------------------------------------------------------------#
# EKS Cluster 구성 후 초기 구성 작업을 수행하기 위한 Terraform Kubernetes Provider 설정 
# 생성 된 EKS Cluster의 EndPoint 주소 및 인증정보등을 DataSource로 정의 후 Provider 설정 정보로 입력
# 붙일 vpc, name, version, subnet, oidc, worker node정의하여 생성
# eks 관련 role은 미리 정의하여 배포되어 있다고 가정 ( 없는 role 은 eks 모듈에서 생성)
#----------------------------------------------------------------------------#

# AWS EKS Cluster Data Source
data "aws_eks_cluster" "cluster" {
  name = "${local.tag}-eks"
}

# AWS EKS Cluster Auth Data Source
data "aws_eks_cluster_auth" "cluster" {
  name = "${local.tag}-eks"
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}
# cluster admin 데이터 참조로 id 값 참조

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.21.0"

  # EKS Cluster Setting
  cluster_name                    = "${local.tag}-eks"
  cluster_version                 = "1.29"
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  vpc_id                          = module.vpc.vpc_id
  subnet_ids                      = module.vpc.private_subnets
  create_cluster_security_group = false
  cluster_security_group_id = module.eks_SG.security_group_id
  # cluster_security_group_name = "${local.tag}-eks-cluster-sg"
  create_kms_key = false
  cluster_encryption_config = {
    # 여기에 실제 KMS 키 ARN을 입력 기존에 생성된 키 사용
   provider_key_arn = "arn:aws:kms:ap-northeast-1:${local.account_id}:key/f4e06898-d19e-48b9-ab74-09f92e7e7f6d" 
   resources = ["secrets"]
  }

  # OIDC(OpenID Connect) 구성 
  enable_irsa = true
  #EKS Worker Node 정의 ( ManagedNode방식 / Launch Template 자동 구성 )
  eks_managed_node_groups = {
    # 그룹 이름(?) 
    initial = {
      #  instance_types         = ["${local.worker_node_instance_type }"]
      ami_type              = "AL2_x86_64"
      instance_types        = ["t3.medium"]
      create_security_group = false
      #create_launch_template = false # Required Option 
      launch_template_name = "nam_temp_null_terra"

      min_size     = "1"
      max_size     = "3"
      desired_size = "2"
    }
  }

  #role 생성 false
  create_iam_role = false
  # 기존에 있던 role matching 
  iam_role_arn              = "arn:aws:iam::${local.account_id}:role/eksClusterRole"
  #19모듈 이전에 있던 auth config map
  manage_aws_auth_configmap = true
  aws_auth_users = [
    {
      userarn  = "arn:aws:iam::${local.account_id}:user/kw.nam"
      username = "kw.nam"
      groups   = ["system:masters"]
    },
  ]

  tags = {
    Name = "${local.tag}_eks_cluster_teg"
  }
}

output "cluster" {
  value       = module.eks.cluster_id
  description = "eks_cluster_id for another works"
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
    egress_with_cidr_blocks = [
    {
      from_port   = local.any_protocol
      to_port     = local.any_protocol
      protocol    = local.any_protocol
      description = "all"
      cidr_blocks = local.all_network
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
  subnet_id                   = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  vpc_security_group_ids      = [module.BastionHost_SG.security_group_id, module.eks_SG.security_group_id]

  tags = {
    Name = "${local.tag}_bastion_host"
  }

depends_on = [ module.BastionHost_SG ]
}

