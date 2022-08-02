resource "aws_elasticsearch_domain" "opensearch" {
  domain_name           = "${local.name}-demo"
  elasticsearch_version = "OpenSearch_1.2"

  cluster_config {
    instance_type          = "m6g.large.elasticsearch"
    instance_count         = 1
   
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  encrypt_at_rest {
    enabled = true
  }
  
  ebs_options {
    ebs_enabled = true
    volume_size = 10
  }

  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = true

    master_user_options {
      master_user_name     = var.opensearch_dashboard_user
      master_user_password = var.opensearch_dashboard_pw
    }
  }

  tags = local.tags
}



// access policy in opensearch
resource "aws_elasticsearch_domain_policy" "opensearch_access_policy" {
  domain_name     = aws_elasticsearch_domain.opensearch.domain_name
  access_policies = data.aws_iam_policy_document.opensearch_access_policy.json
}
data "aws_iam_policy_document" "opensearch_access_policy" {
  statement {
    effect    = "Allow"
    resources = ["${aws_elasticsearch_domain.opensearch.arn}/*"]
    actions   = ["es:ESHttp*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}


// access policy for fargate execution role 
resource "aws_iam_policy" "fluentbit_opensearch_access" {
  name        = "${local.name}-eks-fargate-logging-policy"
  description = "IAM policy to allow Fluentbit access to OpenSearch"
  policy      = data.aws_iam_policy_document.fluentbit_opensearch_access.json
}
data "aws_iam_policy_document" "fluentbit_opensearch_access" {
  statement {
    sid       = "OpenSearchAccess"
    effect    = "Allow"
    resources = ["${aws_elasticsearch_domain.opensearch.arn}/*"]
    actions   = ["es:ESHttp*"]
  }
}

//AMP
module "managed_prometheus" {
  source  = "terraform-aws-modules/managed-service-prometheus/aws"
  version = "~> 2.1"

  workspace_alias = local.name

  tags = local.tags
}

# create irsa for adot 
resource "aws_iam_role" "amp_ingest_role" {
  name = "${local.name}-amp-ingest-irsa"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Federated = "${module.eks_blueprints.eks_oidc_provider_arn}"
        }
        
      },
    ]
  })
  
  inline_policy {
    name = "my_inline_policy"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action   = [
             "aps:RemoteWrite", 
             "aps:GetSeries", 
             "aps:GetLabels",
             "aps:GetMetricMetadata"
          ]
          Effect   = "Allow"
          Resource = "*"
        },
      ]
    })
  }

  tags = local.tags
}
