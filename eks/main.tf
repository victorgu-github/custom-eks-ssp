/*
 * Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 * SPDX-License-Identifier: MIT-0
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this
 * software and associated documentation files (the "Software"), to deal in the Software
 * without restriction, including without limitation the rights to use, copy, modify,
 * merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
 * INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
 * PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

terraform {
  required_version = ">= 1.0.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.66.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.6.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.4.1"
    }

  }

  backend "s3" {}

}
provider "aws" {
  region = var.region
  alias  = "default"
}

provider "kubernetes" {
  experiments {
    manifest_resource = true
  }
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    token                  = data.aws_eks_cluster_auth.cluster.token
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  }
}



locals {
  tenant      = var.tenant
  environment = var.environment
  zone        = var.zone

  kubernetes_version = var.cluster_version
  terraform_version  = "Terraform v1.0.1"

  vpc_id             = data.terraform_remote_state.vpc_s3_backend.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.vpc_s3_backend.outputs.private_subnets
  public_subnet_ids  = data.terraform_remote_state.vpc_s3_backend.outputs.public_subnets

  cluster_name = join("-", [local.tenant, local.environment, local.zone, "eks"])
  
  amazonlinux2eks = "amazon-eks-node-${var.cluster_version}-*"
  bottlerocket    = "bottlerocket-aws-k8s-${var.cluster_version}-x86_64-*"
}

data "aws_ami" "eks" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["amazon-eks-node-${local.kubernetes_version}-*"]
  }
}

data "aws_ami" "amazonlinux2eks" {
  most_recent = true
  filter {
    name   = "name"
    values = [local.amazonlinux2eks]
  }
  owners = ["amazon"]
}

data "aws_ami" "bottlerocket" {
  most_recent = true
  filter {
    name   = "name"
    values = [local.bottlerocket]
  }
  owners = ["amazon"]
}

module "eks-blueprints" {
  source = "../../terraform-aws-eks-blueprints"
  # directly refer to github source = "github.com/aws-ia/terraform-aws-eks-blueprints"
  tenant            = local.tenant
  environment       = local.environment
  zone              = local.zone
  terraform_version = local.terraform_version

  # EKS Cluster VPC and Subnets
  vpc_id             = local.vpc_id
  private_subnet_ids = local.private_subnet_ids

  # Cluster Security Group
  cluster_additional_security_group_ids   = var.cluster_additional_security_group_ids
  cluster_security_group_additional_rules = var.cluster_security_group_additional_rules

  # Allow Ingress rule for Worker node groups from Cluster Sec group for Karpenter
  node_security_group_additional_rules = {
    ingress_nodes_karpenter_port = {
      description                   = "Cluster API to Nodegroup for Karpenter"
      protocol                      = "tcp"
      from_port                     = 8443
      to_port                       = 8443
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }

  # EKS CONTROL PLANE VARIABLES
  cluster_version = local.kubernetes_version

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # List of map_roles
  map_roles          = [
    {
      rolearn  = "arn:aws:iam::349361870252:role/Admin"     # The ARN of the IAM role
      username = "cluster-admin"                                      # The user name within Kubernetes to map to the IAM role
      groups   = ["system:masters"]                                   # A list of groups within Kubernetes to which the role is mapped; Checkout K8s Role and Rolebindings
    }
  ]

  # List of map_users
  # map_users = [
  #   {
  #     userarn  = "arn:aws:iam::<aws-account-id>:user/<username>"      # The ARN of the IAM user to add.
  #     username = "opsuser"                                            # The user name within Kubernetes to map to the IAM role
  #     groups   = ["system:masters"]                                   # A list of groups within Kubernetes to which the role is mapped; Checkout K8s Role and Rolebindings
  #   }
  # ]

  # map_accounts = ["123456789", "9876543321"]                          # List of AWS account ids



  # EKS MANAGED NODE GROUPS
  managed_node_groups = {
    mg_4 = {
      node_group_name = "managed-ondemand"
      instance_types  = ["m5.large"]
      subnet_ids      = local.private_subnet_ids
      desired_size    = 3      
    }
  }
  
  # self_managed_node_groups = {
  #   self_mg_4 = {
  #     node_group_name    = "self-managed-ondemand"
  #     instance_type      = "m5.large"
  #     launch_template_os = "amazonlinux2eks"   # amazonlinux2eks  or bottlerocket or windows
  #     custom_ami_id      = data.aws_ami.eks.id # Bring your own custom AMI generated by Packer/ImageBuilder/Puppet etc.
  #     subnet_ids         = local.private_subnet_ids
  #     max_size   = "1"
  #     min_size   = "1"
  #   }
  # }
  
  fargate_profiles = {
    default = {
      fargate_profile_name = "default"
      fargate_profile_namespaces = [
        {
          namespace = "default"
          k8s_labels = {
            Environment = "preprod"
            Zone        = "dev"
            env         = "fargate"
          }
      }]
      subnet_ids =  local.private_subnet_ids
      additional_tags = {
        ExtraTag = "Fargate"
      }
    },
  }


    # AWS Managed Services
  enable_amazon_prometheus = true
}


# Creates Launch templates for Karpenter. 
# it is highly related with node group. that is why put it here
# Launch template outputs will be used in Karpenter Provisioners yaml files. Checkout this examples/karpenter/provisioners/default_provisioner_with_launch_templates.yaml
module "karpenter_launch_templates" {
  source         = "../../terraform-aws-eks-blueprints/modules/launch-templates"
  eks_cluster_id = module.eks-blueprints.eks_cluster_id
  tags           = { Name = "karpenter" }

  launch_template_config = {
    linux = {
      ami                    = data.aws_ami.amazonlinux2eks.id
      launch_template_prefix = "karpenter"
      iam_instance_profile   = module.eks-blueprints.managed_node_group_iam_instance_profile_id[0]
      vpc_security_group_ids = [module.eks-blueprints.worker_node_security_group_id]
      block_device_mappings = [
        {
          device_name = "/dev/xvda"
          volume_type = "gp3"
          volume_size = "200"
        }
      ]
    },
    bottlerocket = {
      ami                    = data.aws_ami.bottlerocket.id
      launch_template_os     = "bottlerocket"
      launch_template_prefix = "bottle"
      iam_instance_profile   = module.eks-blueprints.managed_node_group_iam_instance_profile_id[0]
      vpc_security_group_ids = [module.eks-blueprints.worker_node_security_group_id]
      block_device_mappings = [
        {
          device_name = "/dev/xvda"
          volume_type = "gp3"
          volume_size = "200"
        }
      ]
    },
  }
}