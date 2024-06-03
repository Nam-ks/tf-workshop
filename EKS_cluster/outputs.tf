output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "VPC ID Output"
}

output "vpc_cidr_blocks" {
  value       = module.vpc.vpc_cidr_block
  description = "vpc_Cidr_Blocks Output"
}

output "public_subnets" {
  value       = module.vpc.public_subnets
  description = "Public_Subnets Output"
}

output "private_subnets" {
  value       = module.vpc.private_subnets
  description = "Private_Subnets Output"
}

output "cluster_id" {
  value       = module.eks.cluster_id
  description = "eks_cluster_id for another works"
}

output "cluster_endpoint" {
  value       = module.eks.cluster_endpoint
  description = "cluster_endpoint"
}

output "oidc" {
  value       = split("/", module.eks.cluster_oidc_issuer_url)[length(split("/", module.eks.cluster_oidc_issuer_url)) - 1]
  description = "oidc for auth"
}


output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}