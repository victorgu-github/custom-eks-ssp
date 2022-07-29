1. how does blueprints deploy an add-on
- 1.1 from blueprint_repo/modules/kubernetes-addons, all the add-on modules are defined in main.tf
    - addon_context is defined in local.tf
    - need to extend argocd_addon_config local.tf if set manage_via_gitops to true
- 1.2 for every add-on, go to the subfolder in kubernetes-addons. take prometheus as example
    - main.tf creates policy and irsa and pass chart default values, reset values and config to helm-addon module
- 1.3 in helm-addon module, irsa can also be defined here if irsa_config is passed
    - will not work if manage_via_gitops is set to true except irsa
    - expose amp_gitops_config in local.tf to argocd_gitops_config in output which can be used by argocd
    - how does argocd captures the config is using GitOps Bridge. no detail info.



reference:
https://github.com/aws-ia/terraform-aws-eks-blueprints/blob/main/docs/extensibility.md