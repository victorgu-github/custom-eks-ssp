provider "aws" {
  region = local.region
}

provider "kubernetes" {
  host                   = module.eks_blueprints.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks_blueprints.eks_cluster_id]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks_blueprints.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", module.eks_blueprints.eks_cluster_id]
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}

locals {
  name   = var.name
  region = var.region

  vpc_cidr = var.vpc_cidr
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Blueprint  = local.name
    GithubRepo = "terraform-aws-eks-blueprints"
  }
  
    #---------------------------------------------------------------
  # ARGOCD ADD-ON APPLICATION
  #---------------------------------------------------------------
  addon_application = {
    path               = "chart"
    repo_url           = "https://git-codecommit.us-west-2.amazonaws.com/v1/repos/eks-addons-config"
    add_on_application = true
    #ssh_key_secret_name = var.gitkey  # Needed for private repos
    insecure            = false # Set to true to disable the server's certificate verification
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

#---------------------------------------------------------------
# EKS Blueprints
#---------------------------------------------------------------
module "eks_blueprints" {
  source = "../../terraform-aws-eks-blueprints"

  cluster_name    = local.name
  cluster_version = "1.21"

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets

  # https://github.com/aws-ia/terraform-aws-eks-blueprints/issues/485
  # https://github.com/aws-ia/terraform-aws-eks-blueprints/issues/494
  cluster_kms_key_additional_admin_arns = [data.aws_caller_identity.current.arn]

  fargate_profiles = {
    # Providing compute for default namespace
    default = {
      fargate_profile_name = "default"
      additional_iam_policies = ["arn:aws:iam::349361870252:policy/eks-fargate-logging-policy"]
      fargate_profile_namespaces = [
        {
          namespace = "default"
      },     {
          namespace = "argocd"
      },
      {
          namespace = "prometheus"
      }]

      subnet_ids = module.vpc.private_subnets
    }

  }
  
    # List of map_roles
  map_roles          = [
    {
      rolearn  = "arn:aws:iam::349361870252:role/Admin"     # The ARN of the IAM role
      username = "cluster-admin"                                      # The user name within Kubernetes to map to the IAM role
      groups   = ["system:masters"]                                   # A list of groups within Kubernetes to which the role is mapped; Checkout K8s Role and Rolebindings
    }
  ]
  
    # EKS MANAGED NODE GROUPS
  managed_node_groups = {
    mg_4 = {
      node_group_name = "managed-ondemand"
      instance_types  = ["m5.large"]
      subnet_ids      =  module.vpc.private_subnets
      desired_size    = 5     
      max_size               = 5
      min_size               = 3
    }
  }
  
  
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true
  tags = local.tags
}

module "eks_blueprints_kubernetes_addons" {
  source = "../../terraform-aws-eks-blueprints/modules/kubernetes-addons"

  eks_cluster_id       = module.eks_blueprints.eks_cluster_id
  eks_cluster_endpoint = module.eks_blueprints.eks_cluster_endpoint
  eks_oidc_provider    = module.eks_blueprints.oidc_provider
  eks_cluster_version  = module.eks_blueprints.eks_cluster_version

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

  # enable_self_managed_coredns = true
  # self_managed_coredns_helm_config = {
  #   # Sets the correct annotations to ensure the Fargate provisioner is used and not the EC2 provisioner
  #   compute_type       = "fargate"
  #   kubernetes_version = module.eks_blueprints.eks_cluster_version
  # }
  enable_amazon_eks_coredns = true
  amazon_eks_coredns_config = {
    addon_version     = data.aws_eks_addon_version.latest["coredns"].version
    resolve_conflicts = "OVERWRITE"
  }

  enable_metrics_server     = true
  enable_aws_efs_csi_driver = true
  enable_amazon_eks_aws_ebs_csi_driver  = true
  # enable_argocd         = true
  # argocd_manage_add_ons = true # Indicates that ArgoCD is responsible for managing/deploying Add-ons.
  # argocd_applications = {
  #   addons    = local.addon_application
  #   #workloads = local.workload_application
  # }
  
  # enable_aws_load_balancer_controller = true

  # Prometheus and Amazon Managed Prometheus integration
  #enable_prometheus                    = true
  #enable_amazon_prometheus             = true
  #amazon_prometheus_workspace_endpoint = module.managed_prometheus.workspace_prometheus_endpoint
  

  tags = local.tags

  depends_on = [
    module.eks_blueprints
  ]

}

data "aws_eks_addon_version" "latest" {
  for_each = toset(["kube-proxy", "vpc-cni","coredns"])

  addon_name         = each.value
  kubernetes_version = module.eks_blueprints.eks_cluster_version
  most_recent        = true
}

#---------------------------------------------------------------
# Modifying CoreDNS for Fargate
#---------------------------------------------------------------
data "aws_eks_cluster_auth" "this" {
  name = module.eks_blueprints.eks_cluster_id
}

locals {
  kubeconfig = yamlencode({
    apiVersion      = "v1"
    kind            = "Config"
    current-context = "terraform"
    clusters = [{
      name = module.eks_blueprints.eks_cluster_id
      cluster = {
        certificate-authority-data = module.eks_blueprints.eks_cluster_certificate_authority_data
        server                     = module.eks_blueprints.eks_cluster_endpoint
      }
    }]
    contexts = [{
      name = "terraform"
      context = {
        cluster = module.eks_blueprints.eks_cluster_id
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
}

# don't install here since cannot see logs
# resource "null_resource" "install_kubeflow" {
#   triggers = {}

#   provisioner "local-exec" {
#     interpreter = ["/bin/bash", "-c"]
#     environment = {
#       KUBECONFIG = base64encode(local.kubeconfig)
#     }

#     # We are maintaing the existing kube-dns service and annotating it for Helm to assume control
#     command = <<-EOT
#       echo "Intalling kuebflow on EKS with Vanilla setting by Kustomize"
#       while ! kustomize build deployments/vanilla | kubectl apply -f -; do echo "Retrying to apply resources"; sleep 30; done
#     EOT
#   }

#   depends_on = [
#       module.eks_blueprints
#   ]
# }

#---------------------------------------------------------------
# Supporting Resources
#---------------------------------------------------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 10)]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  create_igw           = true

  # Manage so we can name
  manage_default_network_acl    = true
  default_network_acl_tags      = { Name = "${local.name}-default" }
  manage_default_route_table    = true
  default_route_table_tags      = { Name = "${local.name}-default" }
  manage_default_security_group = true
  default_security_group_tags   = { Name = "${local.name}-default" }

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.name}" = "shared"
    "kubernetes.io/role/elb"              = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.name}" = "shared"
    "kubernetes.io/role/internal-elb"     = 1
  }

  tags = local.tags
}
