####
# Add your custom resources here...
# such as IRSA policy statement
####

# Invokes the generic helm-addon module which is a convenience module
# EKS Blueprints framework provides to create helm based addons easily
module "helm_addon" {
  source            = "../aws-eks-accelerator-for-terraform//modules/kubernetes-addons/helm-addon"
  manage_via_gitops = var.manage_via_gitops
  set_values        = local.set_values
  helm_config       = local.helm_config
  irsa_config       = local.irsa_config
  addon_context     = var.addon_context
}

// if need to set policy
# resource "aws_iam_policy" "aws_load_balancer_controller" {
#   name        = "${var.addon_context.eks_cluster_id}-lb-irsa"
#   description = "Allows lb controller to manage ALB and NLB"
#   policy      = data.aws_iam_policy_document.aws_lb.json
#   tags        = var.addon_context.tags
# }