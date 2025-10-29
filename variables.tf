variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name_prefix" {
  description = "Prefix for the EKS cluster name"
  type        = string
  default     = "my-app"
}

variable "non_prod_instance_type" {
  description = "Instance type for non-prod nodes"
  type        = string
}

variable "prod_instance_type" {
  description = "Instance type for prod nodes"
  type        = string
}

variable "node_group_max_size" {
  description = "Initial max size for node group"
  type        = number
  default     = 1 # Start with 1 to deploy quickly
}

variable "non_prod_pipeline_role_arn" {
  description = "ARN of the non-prod pipeline IAM role (Create in Phase 5)"
  type        = string
}

variable "prod_pipeline_role_arn" {
  description = "ARN of the prod pipeline IAM role (Create in Phase 5)"
  type        = string
}
