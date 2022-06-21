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
variable "opensearch_endpoint" {
  description = "opensearch_endpoint"
  type        = string
}
variable "opensearch_arn" {
  description = "opensearch_arn"
  type        = string
}

