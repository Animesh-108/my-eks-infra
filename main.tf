terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# Get the user running Terraform to grant them admin access
data "aws_caller_identity" "current" {}

# Get available AZs
data "aws_availability_zones" "available" {}

################################################################################
# VPC Module
# We create a new VPC for each environment (non-prod, prod)
################################################################################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1" # Using a recent, stable version

  name = "${var.cluster_name_prefix}-${terraform.workspace}-vpc"
  cidr = "10.0.0.0/16"

  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  # Tags required by EKS
  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name_prefix}-${terraform.workspace}" = "shared"
    "kubernetes.io/role/elb"                               = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name_prefix}-${terraform.workspace}" = "shared"
    "kubernetes.io/role/internal-elb"                      = "1"
  }
}

################################################################################
# EKS Module
################################################################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.4" # As requested

  cluster_name    = "${var.cluster_name_prefix}-${terraform.workspace}"
  cluster_version = "1.29"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # We enable public access for simplicity in this guide
  cluster_endpoint_public_access = true

  # This is the node group for our application workloads
  eks_managed_node_groups = {
    main_pool = {
      # Use instance type based on environment
      instance_types = [terraform.workspace == "prod" ? var.prod_instance_type : var.non_prod_instance_type]

      min_size     = 1
      max_size     = var.node_group_max_size # Start with 1, then scale to 3
      desired_size = 2
    }
  }

  # =========================================================================
  # CRITICAL: Kubernetes RBAC Mapping
  # This grants YOUR IAM user and the pipeline roles permission to the cluster.
  # =========================================================================

  # 1. Map the IAM User who is running Terraform
  map_users = [
    {
      userarn  = data.aws_caller_identity.current.arn
      username = "animesh-IAM-Admin" # Your admin user
      groups   = ["system:masters"]  # Full admin access
    },
  ]

  # 2. Map the IAM Roles our CI/CD pipelines will use
  # We will create these roles in Phase 5, but define their ARNs as variables now.
  map_roles = [
    {
      rolearn  = var.non_prod_pipeline_role_arn
      username = "non-prod-pipeline"
      groups   = ["system:masters"] # Granting admin for simplicity
    },
    {
      rolearn  = var.prod_pipeline_role_arn
      username = "prod-pipeline"
      groups   = ["system:masters"]
    },
  ]
}

# Output the cluster details so we can connect to it
output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}
