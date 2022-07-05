# variable "amp_endpoint" {
#   description = "amp_endpoint"
#   type        = string
#   default     = "https://aps-workspaces.us-east-1.amazonaws.com/workspaces/ws-b1fe62a1-f64b-42b2-aa11-8248d9293d3d/"
# }

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

# variable "name" {
#   type        = string
#   description = "cluster name"
#   default     = "aws006-preprod-test-eks"
# }

# variable "region" {
#   type        = string
#   description = "AWS region"
#   default     = "us-east-1"
# }

# variable "vpc_cidr" {
#   description = "The CIDR block of the default VPC that hosts the EKS cluster."
#   type        = string
#   default     = "10.0.0.0/16"
# }
