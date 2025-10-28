variable "region" {
  description = "AWS region for the cluster"
  type        = string
  default     = "us-east-1"
}
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}
variable "instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
}
