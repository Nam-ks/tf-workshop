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
# 붙일 vpc, name, version, subnet, oidc, worker node정의하여 생성
# 워커 노드 그룹의 최소 최대 요구 개수를 입력받아 변경 가능하고 기본값이 각 232로 지정
# role은 미리 정의하여 배포되어 있다고 가정
#----------------------------------------------------------------------------#
# AWS EKS Cluster Data Source

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
# Kubernetes 추가 Provider
# EKS Cluster 구성 후 초기 구성 작업을 수행하기 위한 Terraform Kubernetes Provider 설정 
# 생성 된 EKS Cluster의 EndPoint 주소 및 인증정보등을 DataSource로 정의 후 Provider 설정 정보로 입력
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
   provider_key_arn = "arn:aws:kms:ap-northeast-1:${local.account_id}:key/f4e06898-d19e-48b9-ab74-09f92e7e7f6d" # 여기에 실제 KMS 키 ARN을 입력
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

resource "aws_iam_role" "alb_role" {
  name        = "AmazonEKSLoadBalancerControllerRoleTest2"
  path        = "/"
  description = "eks alb controller role"
  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Principal" : {
            "Federated" : "arn:aws:iam::451460726243:oidc-provider/oidc.eks.ap-northeast-2.amazonaws.com/id/${module.eks.oidc}"
          },
          "Action" : "sts:AssumeRoleWithWebIdentity",
          "Condition" : {
            "StringEquals" : {
              "oidc.eks.ap-northeast-2.amazonaws.com/id/${module.eks.oidc}:sub" : "system:serviceaccount:kube-system:aws-load-balancer-controller",
              "oidc.eks.ap-northeast-2.amazonaws.com/id/${module.eks.oidc}:aud" : "sts.amazonaws.com"
            }
          }
        }
      ]
    }
  )
}



resource "aws_iam_policy" "alb_policy" {
  name        = "AWSLoadBalancerControllerIAMPolicyTest2"
  path        = "/"
  description = "policy with terraform"
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "iam:CreateServiceLinkedRole"
          ],
          "Resource" : "*",
          "Condition" : {
            "StringEquals" : {
              "iam:AWSServiceName" : "elasticloadbalancing.amazonaws.com"
            }
          }
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "ec2:DescribeAccountAttributes",
            "ec2:DescribeAddresses",
            "ec2:DescribeAvailabilityZones",
            "ec2:DescribeInternetGateways",
            "ec2:DescribeVpcs",
            "ec2:DescribeVpcPeeringConnections",
            "ec2:DescribeSubnets",
            "ec2:DescribeSecurityGroups",
            "ec2:DescribeInstances",
            "ec2:DescribeNetworkInterfaces",
            "ec2:DescribeTags",
            "ec2:GetCoipPoolUsage",
            "ec2:DescribeCoipPools",
            "elasticloadbalancing:DescribeLoadBalancers",
            "elasticloadbalancing:DescribeLoadBalancerAttributes",
            "elasticloadbalancing:DescribeListeners",
            "elasticloadbalancing:DescribeListenerCertificates",
            "elasticloadbalancing:DescribeSSLPolicies",
            "elasticloadbalancing:DescribeRules",
            "elasticloadbalancing:DescribeTargetGroups",
            "elasticloadbalancing:DescribeTargetGroupAttributes",
            "elasticloadbalancing:DescribeTargetHealth",
            "elasticloadbalancing:DescribeTags"
          ],
          "Resource" : "*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "cognito-idp:DescribeUserPoolClient",
            "acm:ListCertificates",
            "acm:DescribeCertificate",
            "iam:ListServerCertificates",
            "iam:GetServerCertificate",
            "waf-regional:GetWebACL",
            "waf-regional:GetWebACLForResource",
            "waf-regional:AssociateWebACL",
            "waf-regional:DisassociateWebACL",
            "wafv2:GetWebACL",
            "wafv2:GetWebACLForResource",
            "wafv2:AssociateWebACL",
            "wafv2:DisassociateWebACL",
            "shield:GetSubscriptionState",
            "shield:DescribeProtection",
            "shield:CreateProtection",
            "shield:DeleteProtection"
          ],
          "Resource" : "*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "ec2:AuthorizeSecurityGroupIngress",
            "ec2:RevokeSecurityGroupIngress"
          ],
          "Resource" : "*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "ec2:CreateSecurityGroup"
          ],
          "Resource" : "*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "ec2:CreateTags"
          ],
          "Resource" : "arn:aws:ec2:*:*:security-group/*",
          "Condition" : {
            "StringEquals" : {
              "ec2:CreateAction" : "CreateSecurityGroup"
            },
            "Null" : {
              "aws:RequestTag/elbv2.k8s.aws/cluster" : "false"
            }
          }
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "ec2:CreateTags",
            "ec2:DeleteTags"
          ],
          "Resource" : "arn:aws:ec2:*:*:security-group/*",
          "Condition" : {
            "Null" : {
              "aws:RequestTag/elbv2.k8s.aws/cluster" : "true",
              "aws:ResourceTag/elbv2.k8s.aws/cluster" : "false"
            }
          }
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "ec2:AuthorizeSecurityGroupIngress",
            "ec2:RevokeSecurityGroupIngress",
            "ec2:DeleteSecurityGroup"
          ],
          "Resource" : "*",
          "Condition" : {
            "Null" : {
              "aws:ResourceTag/elbv2.k8s.aws/cluster" : "false"
            }
          }
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "elasticloadbalancing:CreateLoadBalancer",
            "elasticloadbalancing:CreateTargetGroup"
          ],
          "Resource" : "*",
          "Condition" : {
            "Null" : {
              "aws:RequestTag/elbv2.k8s.aws/cluster" : "false"
            }
          }
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "elasticloadbalancing:CreateListener",
            "elasticloadbalancing:DeleteListener",
            "elasticloadbalancing:CreateRule",
            "elasticloadbalancing:DeleteRule"
          ],
          "Resource" : "*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "elasticloadbalancing:AddTags",
            "elasticloadbalancing:RemoveTags"
          ],
          "Resource" : [
            "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
            "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
            "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
          ],
          "Condition" : {
            "Null" : {
              "aws:RequestTag/elbv2.k8s.aws/cluster" : "true",
              "aws:ResourceTag/elbv2.k8s.aws/cluster" : "false"
            }
          }
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "elasticloadbalancing:AddTags",
            "elasticloadbalancing:RemoveTags"
          ],
          "Resource" : [
            "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
            "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
            "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
            "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
          ]
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "elasticloadbalancing:ModifyLoadBalancerAttributes",
            "elasticloadbalancing:SetIpAddressType",
            "elasticloadbalancing:SetSecurityGroups",
            "elasticloadbalancing:SetSubnets",
            "elasticloadbalancing:DeleteLoadBalancer",
            "elasticloadbalancing:ModifyTargetGroup",
            "elasticloadbalancing:ModifyTargetGroupAttributes",
            "elasticloadbalancing:DeleteTargetGroup"
          ],
          "Resource" : "*",
          "Condition" : {
            "Null" : {
              "aws:ResourceTag/elbv2.k8s.aws/cluster" : "false"
            }
          }
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "elasticloadbalancing:AddTags"
          ],
          "Resource" : [
            "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
            "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
            "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
          ],
          "Condition" : {
            "StringEquals" : {
              "elasticloadbalancing:CreateAction" : [
                "CreateTargetGroup",
                "CreateLoadBalancer"
              ]
            },
            "Null" : {
              "aws:RequestTag/elbv2.k8s.aws/cluster" : "false"
            }
          }
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "elasticloadbalancing:RegisterTargets",
            "elasticloadbalancing:DeregisterTargets"
          ],
          "Resource" : "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "elasticloadbalancing:SetWebAcl",
            "elasticloadbalancing:ModifyListener",
            "elasticloadbalancing:AddListenerCertificates",
            "elasticloadbalancing:RemoveListenerCertificates",
            "elasticloadbalancing:ModifyRule"
          ],
          "Resource" : "*"
        }
      ]
    }

  )
}


resource "aws_iam_role_policy_attachment" "alb_attach" {
  role       = aws_iam_role.alb_role.name
  policy_arn = aws_iam_policy.alb_policy.arn
}
output "alb_arn" {
  value = aws_iam_role.alb_role.arn
}
