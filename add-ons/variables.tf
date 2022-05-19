variable "region" {
  type        = string
  description = "AWS region"
}
variable "eks_cluster_id" {
  description = "EKS Cluster ID/name"
  type        = string
}
variable "amp_endpoint" {
  description = "amp_endpoint"
  type        = string
}
