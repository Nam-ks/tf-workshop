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


#----------------------------------------------------------------------------#
# Kubernetes 추가 Provider
# EKS Cluster 구성 후 초기 구성 작업을 수행하기 위한 Terraform Kubernetes Provider 설정 
# 생성 된 EKS Cluster의 EndPoint 주소 및 인증정보등을 DataSource로 정의 후 Provider 설정 정보로 입력
#----------------------------------------------------------------------------#

# AWS EKS Cluster Data Source
data "aws_eks_cluster" "cluster" {
  name = "nam-terra-eks"
}

# AWS EKS Cluster Auth Data Source
data "aws_eks_cluster_auth" "cluster" {
  name = "nam-terra-eks"
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

#-----------------------------------------------------------------
#alb irsa 롤을 설정하고 sa를 만들어서 binding 까지 해준 후 helm 으로 alb controller 배포
#-----------------------------------------------------------------
module "load_balancer_controller_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name                              = "${local.tag}-lb-controller-irsa-role"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = local.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

}

module "load_balancer_controller_targetgroup_binding_only_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name                                                       = "${local.tag}-lb-controller-tg-binding-only-irsa-role"
  attach_load_balancer_controller_targetgroup_binding_only_policy = true

  oidc_providers = {
    main = {
      provider_arn               = local.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = {
    Name = "${local.tag}_terra_albcontroller_irsa"
  }
}

resource "kubernetes_service_account" "aws-load-balancer-controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.load_balancer_controller_irsa_role.iam_role_arn
    }

    labels = {
      "app.kubernetes.io/component" = "controller"
      "app.kubernetes.io/name"      = "aws-load-balancer-controller"
    }

  }

  depends_on = [module.load_balancer_controller_irsa_role]
}


resource "helm_release" "aws-load-balancer-controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"

  set {
    name  = "clusterName"
    value = var.cluster_name
  }
  set {
    name  = "serviceAccount.create"
    value = false
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  depends_on = [kubernetes_service_account.aws-load-balancer-controller]
}

#-----------------------------------------------------------------
# external_dns 롤을 설정하고 sa를 만들어서 binding 까지 해준 후 controller 생성
# route 53 이 없으므로 다음에 시도
#-----------------------------------------------------------------

# data "aws_route53_zone" "route_53" {
#   zone_id = ""
# }

# #ex dns irsa
# resource "kubernetes_service_account" "external-dns" {
#   metadata {
#     name      = "external-dns"
#     namespace = "kube-system"
#     annotations = {
#       "eks.amazonaws.com/role-arn" = module.external_dns_irsa_role.iam_role_arn
#     }
#   }

#   depends_on = [module.external_dns_irsa_role]
# }

# module "external_dns_irsa_role" {
#   source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

#   role_name                     = "${local.name}-externaldns-irsa-role"
#   attach_external_dns_policy    = true
#   external_dns_hosted_zone_arns = [data.aws_route53_zone.route_53.arn]

#   oidc_providers = {
#     main = {
#       provider_arn               = var.oidc_provider_arn
#       namespace_service_accounts = ["kube-system:external-dns"]
#     }
#   }

#   tags = {
#     Name = "${var.tag}_terra_dns_irsa"
#   }

#   depends_on = [kubernetes_service_account.aws-load-balancer-controller]
# }

# resource "helm_release" "external_dns" {
#   name       = "external-dns"
#   namespace  = "kube-system"
#   repository = "https://charts.bitnami.com/bitnami"
#   chart      = "external-dns"
#   wait       = false
#   set {
#     name  = "provider"
#     value = "aws"
#   }
#   set {
#     name  = "serviceAccount.create"
#     value = false
#   }
#   set {
#     name  = "serviceAccount.name"
#     value = "external-dns"
#   }
#   set {
#     name  = "policy"
#     value = "sync"
#   }
#   depends_on = [kubernetes_service_account.external-dns, helm_release.aws-load-balancer-controller]
# }

