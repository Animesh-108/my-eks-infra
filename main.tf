# 1. Configure the AWS Provider
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

# 2. Define the VPC (Network)
# EKS needs a robust network. This module sets it up perfectly.
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.5.3"

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.region}a", "${var.region}b", "${var.region}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  # Tags required by EKS to find the subnets
  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                  = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"         = "1"
  }
}

# 3. Define the EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.4"

  cluster_name    = var.cluster_name
  cluster_version = "1.29" # Always use a recent, supported version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # This creates the EC2 worker nodes for our apps
  eks_managed_node_groups = {
    default_nodes = {
      min_size       = 1
      max_size       = 1
      instance_types = [var.instance_type]
    }
  }
}

# 4. Output the cluster name (for our scripts)
output "cluster_name" {
  value = module.eks.cluster_name
}
