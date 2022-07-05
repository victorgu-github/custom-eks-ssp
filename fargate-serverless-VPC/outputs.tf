output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = module.eks_blueprints.configure_kubectl
}

output "amp_endpoint" {
  description = "Amazon managed prometheus workspace endpoint"
  value       = module.managed_prometheus.workspace_prometheus_endpoint
}

output "eks_oidc_provider_arn" {
  description = "eks_oidc_provider_arn"
  value       = module.eks_blueprints.eks_oidc_provider_arn
}

output "amp_ingest_role_arn" {
  description = "amp_ingest_role_arn"
  value       = aws_iam_role.amp_ingest_role.arn
}
