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

  tags = {
    Blueprint  = var.cluster_name
    GithubRepo = "github.com/aws-ia/terraform-aws-eks-blueprints"
  }
  
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
  
  kubeconfig = yamlencode({
    apiVersion      = "v1"
    kind            = "Config"
    current-context = "terraform"
    clusters = [{
      name = module.eks-blueprints.eks_cluster_id
      cluster = {
        certificate-authority-data = module.eks-blueprints.eks_cluster_certificate_authority_data
        server                     = module.eks-blueprints.eks_cluster_endpoint
      }
    }]
    contexts = [{
      name = "terraform"
      context = {
        cluster = module.eks-blueprints.eks_cluster_id
        user    = "terraform"
      }
    }]
    users = [{
      name = "terraform"
      user = {
        token = data.aws_eks_cluster_auth.this.token
      }
    }]
  })
  
      #---------------------------------------------------------------
  # ARGOCD ADD-ON APPLICATION
  #---------------------------------------------------------------
  addon_application = {
    path               = "chart"
    repo_url           = "https://github.com/season1946/eks-addson-fargate.git"
    add_on_application = true
  }

  #---------------------------------------------------------------
  # ARGOCD WORKLOAD APPLICATION
  #---------------------------------------------------------------
  workload_application = {
    path               = "envs/dev"
    repo_url           = "https://github.com/aws-samples/eks-blueprints-workloads.git"
    add_on_application = false
  }
  
  
}



module "eks-blueprints" {
  source = "../../terraform-aws-eks-blueprints"
  # directly refer to github source = "github.com/aws-ia/terraform-aws-eks-blueprints"
  cluster_name = var.cluster_name
  
  //old version
  # tenant            = local.tenant
  # environment       = local.environment
  # zone              = local.zone
  # terraform_version = local.terraform_version

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
  # managed_node_groups = {
  #   mg_4 = {
  #     node_group_name = "managed-ondemand"
  #     instance_types  = ["m5.large"]
  #     subnet_ids      = local.private_subnet_ids
  #     desired_size    = 3      
  #   }
  # }
  
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
      },
           {
          namespace = "argocd"
      },
           {
          namespace = "prometheus"
      }]
      subnet_ids =  local.private_subnet_ids
    },
        # Providing compute for kube-system namespace where core addons reside
    kube_system = {
      fargate_profile_name = "kube-system"
      fargate_profile_namespaces = [
        {
          namespace = "kube-system"
      }]

      subnet_ids = local.private_subnet_ids
    }
  }


    # AWS Managed Services
  # enable_amazon_prometheus = true
}


module "eks_blueprints_kubernetes_addons" {
  source = "../../terraform-aws-eks-blueprints/modules/kubernetes-addons"

  eks_cluster_id       = module.eks-blueprints.eks_cluster_id
  eks_cluster_endpoint = module.eks-blueprints.eks_cluster_endpoint
  eks_oidc_provider    = module.eks-blueprints.oidc_provider
  eks_cluster_version  = module.eks-blueprints.eks_cluster_version

  enable_amazon_eks_vpc_cni = true
  amazon_eks_vpc_cni_config = {
    addon_version     = data.aws_eks_addon_version.latest["vpc-cni"].version
    resolve_conflicts = "OVERWRITE"
  }

  enable_amazon_eks_kube_proxy = true
  amazon_eks_kube_proxy_config = {
    addon_version     = data.aws_eks_addon_version.latest["kube-proxy"].version
    resolve_conflicts = "OVERWRITE"
  }

  enable_self_managed_coredns = true
  self_managed_coredns_helm_config = {
    # Sets the correct annotations to ensure the Fargate provisioner is used and not the EC2 provisioner
    compute_type       = "fargate"
    kubernetes_version = module.eks-blueprints.eks_cluster_version
  }


    enable_metrics_server     = true
    enable_argocd         = true
    argocd_manage_add_ons = true # Indicates that ArgoCD is responsible for managing/deploying Add-ons.
    argocd_applications = {
      addons    = local.addon_application
      #workloads = local.workload_application
    }
    
    // enable_aws_efs_csi_driver           = true # no need for fargate 
    //enable_amazon_eks_aws_ebs_csi_driver = true
    
    enable_aws_load_balancer_controller = true
    
    # Prometheus and Amazon Managed Prometheus integration
    enable_prometheus                    = true
    enable_amazon_prometheus             = true # need repeat here for creating irsa and pass it to prometheus
    amazon_prometheus_workspace_endpoint = "https://aps-workspaces.us-west-2.amazonaws.com/workspaces/ws-eafc8ccd-b74c-4e94-8e34-8624299b3608/"


  tags = local.tags

  depends_on = [
    # CoreDNS provided by EKS needs to be updated before applying self-managed CoreDNS Helm addon
    null_resource.modify_kube_dns
  ]
}


# Separate resource so that this is only ever executed once
resource "null_resource" "remove_default_coredns_deployment" {
  triggers = {}

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      KUBECONFIG = base64encode(local.kubeconfig)
    }

    # We are removing the deployment provided by the EKS service and replacing it through the self-managed CoreDNS Helm addon
    # However, we are maintaing the existing kube-dns service and annotating it for Helm to assume control
    command = <<-EOT
      kubectl --namespace kube-system delete deployment coredns --kubeconfig <(echo $KUBECONFIG | base64 --decode)
    EOT
  }
}

resource "null_resource" "modify_kube_dns" {
  triggers = {}

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      KUBECONFIG = base64encode(local.kubeconfig)
    }

    # We are maintaing the existing kube-dns service and annotating it for Helm to assume control
    command = <<-EOT
      echo "Setting implicit dependency on ${module.eks-blueprints.fargate_profiles["kube_system"].eks_fargate_profile_arn}"
      kubectl --namespace kube-system annotate --overwrite service kube-dns meta.helm.sh/release-name=coredns --kubeconfig <(echo $KUBECONFIG | base64 --decode)
      kubectl --namespace kube-system annotate --overwrite service kube-dns meta.helm.sh/release-namespace=kube-system --kubeconfig <(echo $KUBECONFIG | base64 --decode)
      kubectl --namespace kube-system label --overwrite service kube-dns app.kubernetes.io/managed-by=Helm --kubeconfig <(echo $KUBECONFIG | base64 --decode)
    EOT
  }

  depends_on = [
    null_resource.remove_default_coredns_deployment
  ]
}


// private openseach 
# resource "aws_elasticsearch_domain" "opensearch" {
#   domain_name           = "opensearch"
#   elasticsearch_version = "OpenSearch_1.1"

#   cluster_config {
#     instance_type          = "m6g.large.elasticsearch"
#     instance_count         = 3
#     zone_awareness_enabled = true

#     zone_awareness_config {
#       availability_zone_count = 3
#     }
#   }

#   node_to_node_encryption {
#     enabled = true
#   }

#   domain_endpoint_options {
#     enforce_https       = true
#     tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
#   }

#   encrypt_at_rest {
#     enabled = true
#   }

#   ebs_options {
#     ebs_enabled = true
#     volume_size = 10
#   }

#   advanced_security_options {
#     enabled                        = true
#     internal_user_database_enabled = true

#     master_user_options {
#       master_user_name     = var.opensearch_dashboard_user
#       master_user_password = var.opensearch_dashboard_pw
#     }
#   }

#   vpc_options {
#     subnet_ids         = local.public_subnet_ids
#     security_group_ids = [aws_security_group.opensearch_access.id]
#   }

#   depends_on = [
#     aws_iam_service_linked_role.opensearch
#   ]

#   //tags = local.tags
# }

# resource "aws_security_group" "opensearch_access" {
#   vpc_id      = local.vpc_id
#   description = "OpenSearch access"

#   ingress {
#     description = "host access to OpenSearch"
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     self        = true
#   }

#   ingress {
#     description = "allow instances in the VPC (like EKS) to communicate with OpenSearch"
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"

#     cidr_blocks =[var.opensearch_cidr] 
#   }

#   egress {
#     description = "Allow all outbound access"
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]  #tfsec:ignore:aws-vpc-no-public-egress-sgr
#   }

# // tags = local.tags
# }

# resource "aws_iam_service_linked_role" "opensearch" {
#   count            = var.create_iam_service_linked_role == true ? 1 : 0
#   aws_service_name = "es.amazonaws.com"
# }