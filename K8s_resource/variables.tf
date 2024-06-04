locals {
  cluster_id        = module.eks.cluster_id
  oidc_provider_arn = module.eks.oidc
  tag               = "nam-terra"
}
