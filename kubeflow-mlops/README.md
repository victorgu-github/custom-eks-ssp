# Kubeflow on EKS

This example deploys the following resources

- Creates EKS Cluster Control plane with public endpoint (for demo purpose only) with a managed node group
- Deploys application load balancer and EBS SCI driver
- Deploy Kubeflow (v1.5.1) on the EKS cluster

Note: we use EKS 1.21 here which is the latest EKS version supported by Kubeflow. see reference below <br>
https://awslabs.github.io/kubeflow-manifests/docs/about/eks-compatibility/

## Prerequisites:

Ensure that you have installed the following tools on your machine.

1. [aws cli](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
2. [kubectl](https://Kubernetes.io/docs/tasks/tools/)
3. [terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)
4. [Kustomize](https://kubectl.docs.kubernetes.io/installation/kustomize/)



## Deploy EKS Cluster with Kubeflow feature

Clone the repository

```sh
git clone https://github.com/aws-ia/terraform-aws-eks-blueprints.git
```

Navigate into one of the example directories and run `terraform init`

```sh
cd examples/kubeflow-mlops
terraform init
```

Run Terraform plan to verify the resources created by this execution.

```sh
terraform plan
```

**Deploy the EKS cluster**

```sh
terraform apply
```

Enter `yes` to apply.

**Deploy kubeflow**
```sh
cd kubeflow-manifests
while ! kustomize build deployments/vanilla | kubectl apply -f -; do echo "Retrying to apply resources"; sleep 30; done
```

**Set ALB and default storage class**
```sh
aws eks --region <REGION> update-kubeconfig --name <CLSUTER_NAME>
kubectl apply -f ebs-sc.yaml

kubectl patch storageclass ebs-sc -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
kubectl patch storageclass gp2 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

```


## Verify the resources

Let’s verify the resources created by Steps above.



kubectl get nodes # Output shows the EKS Managed Node group nodes

kubectl get ns | kubeflow # Output shows kubeflow namespace

kubectl get pods --namespace=kubeflow # Output shows kubeflow pods



## Execute Machine learning jobs on Kubeflow


```

## Cleanup

To clean up your environment, destroy the Terraform modules in reverse order.

Destroy the Kubernetes Add-ons, EKS cluster with Node groups and VPC

```sh
terraform destroy -target="module.eks_blueprints_kubernetes_addons" -auto-approve
terraform destroy -target="module.eks_blueprints" -auto-approve
terraform destroy -target="module.vpc" -auto-approve
```

Finally, destroy any additional resources that are not in the above modules

```sh
terraform destroy -auto-approve
```



# clone kubeflow and kubeflow on aws repos
export KUBEFLOW_RELEASE_VERSION=v1.5.1
export AWS_RELEASE_VERSION=v1.5.1-aws-b1.0.0
git clone https://github.com/awslabs/kubeflow-manifests.git && cd kubeflow-manifests
git checkout ${AWS_RELEASE_VERSION}
git clone --branch ${KUBEFLOW_RELEASE_VERSION} https://github.com/kubeflow/manifests.git upstream