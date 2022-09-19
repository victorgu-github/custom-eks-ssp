## This repo shows as a demo for using components in terraform-aws-eks-blueprints to create and config EKS clusters  


## prerequisite 
- pull terraform-aws-eks-blueprints repo (from https://github.com/aws-ia/terraform-aws-eks-blueprints) and put it next to this repo 


## Here is the high level design of the solution. The solution has been split into 3 different Terraform stacks for simplicity.
1. VPC, 
 - Creates a new VPC and 3 Public and Private Subnets
 - VPC Endpoints for various services and S3 VPC Endpoint gateway
 - security groups for ingress and egress, NAT, IGW, dns...
2. EKS
 - Creates EKS Cluster Control plane with a private/public endpoint 
 - Managed node group     https://aws-ia.github.io/terraform-aws-eks-blueprints/node-groups/#managed-node-groups
 - self managed node group
 - fargate_profiles
 - enable AMP for next step
 - create opensearch (VPC mode) in public subnet for next step
 - launch template for karpenter autoscalling (even optional for karpenter)
 - 
2a. EKS with addon
 - create a eks cluster with fargate and managed node group
 - also includes add-ons
 - cannot use with eks folder together since they share the same VPC

3. ADD-ONS
 - EKS adds-on
 - Argo CD 
 - AMP (/ at end in workspace url) tf deploys irsa and workspace. argocd deploys promethus chart
 - log with fluent bit  
       observability/amp-amg-opensearch goes to opensearch (vpc) not work. even work, it is for damonset not built-in. nothing need to deploy for built-in except configmap

       
       note: fargate built-in fluentbit deploy manually https://docs.aws.amazon.com/eks/latest/userguide/fargate-logging.html  
       note: fluentbit demaonset and opensearch how to do manually https://www.eksworkshop.com/intermediate/230_logging/
       note: complete-kubernetes-addons goes to cloudwatch log
 - karpenter with irsa  
     test karpenter deploy default_provisioner and inflate.yaml  
     kubectl get deployment inflate  
     kubectl scale deployment inflate --replicas 1  
     kubectl describe node --selector=intent=apps  

4. optional. for add-ons not covered, you can get charts and check in your git repo for argocd. You may need to manaully create IRSA. 

5. fargate-serverless-VPC is a seperate example which puts VPC, EKS-fargate and addons into the same folder.  
It creates a eks cluster with fargate only, opensearch service and irsa for adot. 

## terraform instructions
need to modify backend.conf and base.tfvars in each subfolder and make sure the variables are matched

    terraform init -backend-config backend.conf -reconfigure

    terraform plan -var-file base.tfvars

    terraform apply -var-file base.tfvars -auto-approve

    terraform destroy -var-file base.tfvars -auto-approve  
    
## Deploy the individual stacks from each of the sub folders. i.e.
    2.1 VPC - Please refer to the [instructions](./vpc/README.md) to deploy a new VPC. 
      output: vpc_id, private_subnets, public_subnets

    2.2 EKS - Please refer to the [instructions](./eks/README.md) to deploy a private EKS cluster
      refer to VPC status bucket to get vpc and subnets
      output: cluster_id, configure_kubectl

    2.3 Add-ons - Please refer to the [instructions](./add-ons/README.md) to deploy the add-ons to the private EKS cluster using GitOps.
      manually add cluster id, region and amp_endpoint


## Destroy

To teardown and remove the resources created in this example:

```sh
terraform destroy -target="module.eks_blueprints_kubernetes_addons" -var-file base.tfvars -auto-approve
terraform destroy -target="module.eks_blueprints" -var-file base.tfvars -auto-approve
terraform destroy -target="module.vpc" -var-file base.tfvars -auto-approve
```

Finally, destroy any additional resources that are not in the above modules

```sh
terraform destroy -auto-approve -var-file base.tfvars

# known issues:
1. affinity settings in some applications can only work on one node group. so better create node group with >3 nodes
2. the default alb image is too old in blueprints. reset image in argocd repo alb chart value.yaml
3. fluentbit deploy with argocd error
