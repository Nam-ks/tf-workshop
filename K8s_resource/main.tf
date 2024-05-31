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