# This repo shows as a demo for using components in terraform-aws-eks-blueprints to create and config EKS clusters  


# prerequisite 
- pull terraform-aws-eks-blueprints repo (from https://github.com/aws-ia/terraform-aws-eks-blueprints) and put it next to this repo 


# Here is the high level design of the solution. The solution has been split into 3 different Terraform stacks for simplicity.
1. VPC, 
 - Creates a new VPC and 3 Public and Private Subnets
 - VPC Endpoints for various services and S3 VPC Endpoint gateway
 - security groups for ingress and egress, NAT, IGW, dns...
2. EKS
 - Creates EKS Cluster Control plane with a private/public endpoint 
 - Managed node group     https://aws-ia.github.io/terraform-aws-eks-blueprints/node-groups/#managed-node-groups
 - self managed node group
 - fargate_profiles
 - 
3. ADD-ONS
 - EKS adds-on
 - Argo CD 

# terraform instructions
need to modify backend.conf and base.tfvars in each subfolder and make sure the variables are matched

    terraform init -backend-config backend.conf -reconfigure

    terraform plan -var-file base.tfvars

    terraform apply -var-file base.tfvars -auto-approve

    terraform destroy -var-file base.tfvars -auto-approve  
    
# Deploy the individual stacks from each of the sub folders. i.e.
    2.1 VPC - Please refer to the [instructions](./vpc/README.md) to deploy a new VPC. 
      output: vpc_id, private_subnets, public_subnets

    2.2 EKS - Please refer to the [instructions](./eks/README.md) to deploy a private EKS cluster
      refer to VPC status bucket to get vpc and subnets
      output: cluster_id, configure_kubectl

    2.3 Add-ons - Please refer to the [instructions](./add-ons/README.md) to deploy the add-ons to the private EKS cluster using GitOps.
      manually add cluster id, region and amp_endpoint



