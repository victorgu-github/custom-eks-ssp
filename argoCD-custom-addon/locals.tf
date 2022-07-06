locals {

  eks_oidc_issuer_url  =  replace(data.aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer, "https://", "")


  name                 = "kube-state-metrics-argocustom"
  chartname =            "kube-state-metrics"
  service_account_name = local.name

  default_helm_config = {
    name        = local.name
    chart       = local.chartname
    repository  = "https://prometheus-community.github.io/helm-charts"
    version     = "4.4.3"
    namespace   = local.name
    description = "Kube State Metrics AddOn Helm Chart"
    values      = local.default_helm_values
  }

  default_helm_values = [templatefile("${path.module}/values.yaml", {
    sa-name = local.service_account_name
  })]

  helm_config = merge(
    local.default_helm_config,
    var.helm_config
  )

  # Set serviceAccount.create to False explicity
  # even if its set to true in customer provided values.yaml
  set_values = [
    {
      name  = "serviceAccount.name"
      value = local.service_account_name
    },
    {
      name  = "serviceAccount.create"
      value = false
    }
  ]

  # An IRSA config must be passed
  irsa_config = {
    kubernetes_namespace              = local.name
    kubernetes_service_account        = local.service_account_name
    create_kubernetes_namespace       = true
    create_kubernetes_service_account = true
    iam_role_path                     = "/"
    tags                              = var.addon_context.tags
    eks_cluster_id                    = var.addon_context.eks_cluster_id
    irsa_iam_policies                 = var.irsa_policies
    irsa_iam_permissions_boundary     = var.irsa_permissions_boundary
  }

  # If you would like customers to be able to use GitOps via ArgoCD
  # open a PR in the https://github.com/aws-samples/ssp-eks-add-ons/
  # repo in order to create an ArgoCD application for your addon.
  argocd_gitops_config = {
    enable             = true
    serviceAccountName = local.service_account_name
  }

  addon_context = {
    aws_caller_identity_account_id = data.aws_caller_identity.current.account_id
    aws_caller_identity_arn        = data.aws_caller_identity.current.arn
    aws_eks_cluster_endpoint       = data.aws_eks_cluster.eks_cluster.endpoint
    aws_partition_id               = data.aws_partition.current.partition
    aws_region_name                = data.aws_region.current.name
    eks_cluster_id                 = var.eks_cluster_id
    eks_oidc_issuer_url            = local.eks_oidc_issuer_url
    eks_oidc_provider_arn          = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.eks_oidc_issuer_url}"
    tags                           = var.tags
    irsa_iam_role_path             = var.irsa_iam_role_path
    irsa_iam_permissions_boundary  = var.irsa_iam_permissions_boundary
  }

}
