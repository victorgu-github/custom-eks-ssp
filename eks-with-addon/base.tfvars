region      = "us-west-2"
cluster_name = "aws014-preprod-test-eks"
cluster_version = "1.23"
vpc_id = "vpc-0eceb8665a337eca0"
private_subnet_ids = ["subnet-0f5797fc0140a39e9","subnet-04ce734627c705b75","subnet-036b648012dec0d67"]
public_subnet_ids = ["subnet-0ebec8747442be2c1","subnet-0ed3199a6f79e9a45","subnet-00dd060a7950def7b"]

cluster_security_group_additional_rules = {
  ingress_from_jenkins_host = {
    description = "Ingress from Jenkins/Bastion Host"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    type        = "ingress"
    cidr_blocks = ["172.31.0.0/16"]
  }
}

