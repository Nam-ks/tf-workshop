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


