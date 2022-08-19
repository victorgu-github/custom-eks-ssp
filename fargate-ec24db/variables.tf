variable "opensearch_dashboard_user" {
  description = "OpenSearch dashboard user"
  type        = string
  default     = "victor"
}

variable "opensearch_dashboard_pw" {
  description = "OpenSearch dashboard user password"
  type        = string
  default     = "Victor123!"
  # sensitive   = true
}


variable "name" {
  type        = string
  description = "cluster name"
}

variable "region" {
  type        = string
  description = "AWS region"
}

variable "vpc_cidr" {
  description = "The CIDR block of the default VPC that hosts the EKS cluster."
  type        = string
}
