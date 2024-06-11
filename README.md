# 과제

| 작성자 | 남권우 주임 |
| --- | --- |
| 작성일시 | 2024.06.04 |

## **목차**

---

1. 사전 정보
1) 진행 정보
2) 아키텍처 정보
2. 환경 구성
1) VS CODE  설치 및 확장 프로그램 설치
2) aws, git hub, terraform cloud 계정
3) TFC 설정
3. IaC

---

## **1. 사전 정보**

---

### 1) 진행 정보

- **목적** : Terraform cloud를 활용한 인프라 배포 자동화
- **진행 일정** : 6/3(월) ~ 6/10(화)
- **진행 인원 :** 남권우 주임
- **진행 환경** :  AWS / Kubernetes
- 진행 방식 :  TFC ( terraform cloud ) - VCS ( Version Control System / git hub 사용 ) 방식 진행
1) local ( 노트북 ) 에서 코드 작성
2) 작성 코드 git hub repo에 저장
3) terraform 에서 연동된 vcs 코드를 provider 에 배포

### 2) 아키텍처 정보

![Untitled](%E1%84%80%E1%85%AA%E1%84%8C%E1%85%A6%20cc1ffeb326874539a1d0e826956732e2/Untitled.png)

- EKS Cluster 구축 
- VPC 리전 : 도쿄 / az : 1a, 1c 
- subnet public 2 개 / private 2 개 
- Nat gateway 1개 , Internet gateway 1개
- ALB ( eks addons )
- instance bastion 용 
- EKS ( 노드 2개 )
- 각 역할에 맞는 정책 및 역할
- 구축된 EKS 클러스터에 K8s Provider을 사용한 리소스 구축 
- namespace ( cloudnetworks )
- deployment ( replicaset : 2 / image : nginx )
- service, Ingress ( nodeport / ALB )
- loadbalancer controller
- service account

---

## 2. 환경 구성

---

### **1) VS CODE  설치 및 확장 프로그램 설치**

> **확장 프로그램 목록
—————————**
AWS Toolkit
AWS CLI Configure
HashiCorp Terraform (문법 박스 제공)
Terraform Advanced Syntax Highlighting (오타)
Korean Language Pack for Visual Studio code (vs code 한글 패치)
> 

### **2) aws, git hub, terraform cloud 계정**

- aws - IAM 계정 ( admin )
- git hub - public repository 생성
- terraform cloud - HCP plus

### **3) TFC 설정**

- Project 및 workspaces 생성
- 아키텍처 특성을 고려하여 workspace를 2개 구성
- aws infra workspace / kubernetes infra workspace

![Untitled](%E1%84%80%E1%85%AA%E1%84%8C%E1%85%A6%20cc1ffeb326874539a1d0e826956732e2/Untitled%201.png)

- Secure Variable Storage 설정 ( aws credential 환경 변수 설정 )
- Dynamic Provider Prodential ( AWS ) 동적 자격 증명 주입을 통해 관리해서 Credential 값을 주기적으로 변동해줘야합니다.
- `정적으로 구성하면 수동으로 주기적으로 변동해주어야합니다. 본 환경에서는 수동으로 구성하였습니다.`

---

## 3. 코드 구성 ( 상세 내용 git hub 확인 )

---

### 1) tree

```jsx
TFE_K8s
├─EKS_cluster
│  ├─main.tf
│  ├─outputs.tf
│  └─varialbes.tf
│
└─K8s_resource
   ├─main.tf
   └─varialbes.tf
```

### 2) EKS_cluster ( aws_infra )

```jsx
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
    # 그룹 이름 
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
  iam_role_arn              = "arn:aws:iam::${local.account_id}:role/eksClusterRole"
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

```

### 3) K8s_resource ( K8s_infra )

- alb controller 를 사용하여 k8s 가 alb 는 직접 생성
- namespace 생성 후 deployment 로 배포 후 외부에서 접속 가능하게 생성

```jsx
resource "kubernetes_namespace" "cloudnetworks" {
  metadata {
    name = "cloudnetworks"
  }
}
resource "kubernetes_deployment" "namserver" {
  metadata {
    name = "namserver"
    namespace = "cloudnetworks"
    labels = {
      test = "namserver"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        test = "namserver"
      }
    }

    template {
      metadata {
        labels = {
          test = "namserver"
        }
      }

      spec {
        container {
          image = "nginx:1.21.6"
          name  = "example"

          resources {
            limits = {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "50Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }

            initial_delay_seconds = 3
            period_seconds        = 3
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "namserver-service" {
  metadata {
    name = "namserver-service"
    namespace = "cloudnetworks"
  }

  spec {
    selector = {
      test = kubernetes_deployment.namserver.metadata.0.labels.test
    }
    session_affinity = "ClientIP"
    port {
      port        = 8080
      target_port = 80
    }

    type = "NodePort"
  }
}

resource "kubernetes_ingress_v1" "namserver-ingress" {
  metadata {
    name = "namserver-ingress"
    namespace = "cloudnetworks"
    annotations = {
      "kubernetes.io/ingress.class" = "alb"
      "alb.ingress.kubernetes.io/scheme" = "internet-facing"
      "alb.ingress.kubernetes.io/subnets" = "subnet-026853e3452e8d3c7,subnet-0c6b57b7c434d928a"
      "alb.ingress.kubernetes.io/target-type" = "ip"
    }
  }

  spec {
    ingress_class_name = "alb"
    rule {
      http {
        path {
          path = "/*"
          backend {
            service {
              name = "namserver-service"
              port {
                number = 8080
              }
            }
          }
        }
      }
    }
  }
}

```

## 4. 결과 확인

---

### AWS Cli를 통한 k8s 구성 환경 확인

![성공 화면2.png](%E1%84%80%E1%85%AA%E1%84%8C%E1%85%A6%20cc1ffeb326874539a1d0e826956732e2/%25EC%2584%25B1%25EA%25B3%25B5_%25ED%2599%2594%25EB%25A9%25B42.png)

### 외부에서 접속한 화면 ( deploy 에 nginx 이미지 배포 )

![성공 화면.png](%E1%84%80%E1%85%AA%E1%84%8C%E1%85%A6%20cc1ffeb326874539a1d0e826956732e2/%25EC%2584%25B1%25EA%25B3%25B5_%25ED%2599%2594%25EB%25A9%25B4.png)
