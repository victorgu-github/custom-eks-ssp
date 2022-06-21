terraform {
  required_version = ">= 1.0.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.66.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.7.1"
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

data "aws_eks_addon_version" "latest" {
  for_each = toset(["vpc-cni", "coredns"])

  addon_name         = each.value
  kubernetes_version = local.cluster_version
  most_recent        = true
}

data "aws_eks_addon_version" "default" {
  for_each = toset(["kube-proxy"])

  addon_name         = each.value
  kubernetes_version = local.cluster_version
  most_recent        = false
}

data "aws_iam_policy_document" "fluentbit_opensearch_access" {
  statement {
    sid       = "OpenSearchAccess"
    effect    = "Allow"
    resources = [var.opensearch_arn]
    actions   = ["es:ESHttp*"]
  }
}

data "aws_iam_policy_document" "opensearch_access_policy" {
  statement {
    effect    = "Allow"
    resources = [var.opensearch_arn]
    actions   = ["es:ESHttp*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

locals {

  cluster_version = data.aws_eks_cluster.cluster.version
  #---------------------------------------------------------------
  # ARGOCD ADD-ON APPLICATION
  #---------------------------------------------------------------
  addon_application = {
    path               = "chart"
    repo_url           = "https://github.com/season1946/eks-blueprints-add-ons.git"
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

module "kubernetes-addons" {
  source = "../../terraform-aws-eks-blueprints/modules/kubernetes-addons"

  eks_cluster_id = var.eks_cluster_id
  # eks_worker_security_group_id = module.eks_blueprints.worker_node_security_group_id    # required by agones
  # auto_scaling_group_names     = module.eks_blueprints.self_managed_node_group_autoscaling_groups  # required by aws_node_termination_handler
  #---------------------------------------------------------------
  # ARGO CD ADD-ON
  #---------------------------------------------------------------
  enable_metrics_server     = true
  //enable_cluster_autoscaler = true

  enable_argocd         = true
  argocd_manage_add_ons = true # Indicates that ArgoCD is responsible for managing/deploying Add-ons.
  argocd_applications = {
    addons    = local.addon_application
    workloads = local.workload_application
  }

 # EKS Addons
  enable_amazon_eks_vpc_cni = true
  amazon_eks_vpc_cni_config = {
    addon_version     = data.aws_eks_addon_version.latest["vpc-cni"].version
    resolve_conflicts = "OVERWRITE"
  }

  enable_amazon_eks_coredns = true
  amazon_eks_coredns_config = {
    addon_version     = data.aws_eks_addon_version.latest["coredns"].version
    resolve_conflicts = "OVERWRITE"
  }

  enable_amazon_eks_kube_proxy = true
  amazon_eks_kube_proxy_config = {
    addon_version     = data.aws_eks_addon_version.default["kube-proxy"].version
    resolve_conflicts = "OVERWRITE"
  }

  enable_amazon_eks_aws_ebs_csi_driver = true
  
    # Prometheus and Amazon Managed Prometheus integration
  enable_prometheus                    = true
  enable_amazon_prometheus             = true
  amazon_prometheus_workspace_endpoint = var.amp_endpoint
  enable_karpenter                    = true

  // setup fluentbit for opensearch from observability
  // opensearch manually or created in previous step and pass endpoint 
  enable_aws_for_fluentbit        = true
  aws_for_fluentbit_irsa_policies = [aws_iam_policy.fluentbit_opensearch_access.arn]
  aws_for_fluentbit_helm_config = {
    values = [templatefile("${path.module}/helm_values/aws-for-fluentbit-values.yaml", {
      aws_region = var.region
      host       = var.opensearch_endpoint
    })]
  }




 // setup fluentbit for cloudwatch_logs from complete-kubernetes-addons
  # enable_aws_for_fluentbit = true
  # aws_for_fluentbit_helm_config = {
  #   name                                      = "aws-for-fluent-bit"
  #   chart                                     = "aws-for-fluent-bit"
  #   repository                                = "https://aws.github.io/eks-charts"
  #   version                                   = "0.1.0"
  #   namespace                                 = "logging"
  #   aws_for_fluent_bit_cw_log_group           = "/${var.eks_cluster_id}/worker-fluentbit-logs" # Optional
  #   aws_for_fluentbit_cwlog_retention_in_days = 90
  #   create_namespace                          = true
  #   values = [templatefile("${path.module}/helm_values/aws-for-fluentbit-values.yaml", {
  #     region                          = local.region
  #     aws_for_fluent_bit_cw_log_group = "/${var.eks_cluster_id}/worker-fluentbit-logs"
  #   })]
  #   set = [
  #     {
  #       name  = "nodeSelector.kubernetes\\.io/os"
  #       value = "linux"
  #     }
  #   ]
  # }

  # enable_fargate_fluentbit = true
  # fargate_fluentbit_addon_config = {
  #   output_conf = <<-EOF
  #   [OUTPUT]
  #     Name cloudwatch_logs
  #     Match *
  #     region ${local.region}
  #     log_group_name /${var.eks_cluster_id}/fargate-fluentbit-logs
  #     log_stream_prefix "fargate-logs-"
  #     auto_create_group true
  #   EOF

  #   filters_conf = <<-EOF
  #   [FILTER]
  #     Name parser
  #     Match *
  #     Key_Name log
  #     Parser regex
  #     Preserve_Key True
  #     Reserve_Data True
  #   EOF

  #   parsers_conf = <<-EOF
  #   [PARSER]
  #     Name regex
  #     Format regex
  #     Regex ^(?<time>[^ ]+) (?<stream>[^ ]+) (?<logtag>[^ ]+) (?<message>.+)$
  #     Time_Key time
  #     Time_Format %Y-%m-%dT%H:%M:%S.%L%z
  #     Time_Keep On
  #     Decode_Field_As json message
  #   EOF
  # }
}

// for openseach

resource "aws_iam_policy" "fluentbit_opensearch_access" {
  name        = "fluentbit_opensearch_access"
  description = "IAM policy to allow Fluentbit access to OpenSearch"
  policy      = data.aws_iam_policy_document.fluentbit_opensearch_access.json
}

resource "aws_elasticsearch_domain_policy" "opensearch_access_policy" {
  domain_name     = "opensearch" //hard code
  access_policies = data.aws_iam_policy_document.opensearch_access_policy.json
}