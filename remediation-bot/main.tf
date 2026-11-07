terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 5.0"
    } 
    kubernetes = {
        source = "hashicorp/kubernetes"
        version = "~> 2.0"
    }
  }

  backend "s3" {
    bucket = "yoder-terraform-state-bucket"
    key = "ai-ops/remediation-bot/terraform.tfstate"
    region = "eu-south-2"
    use_lockfile = true
    encrypt = true
  }
}

provider "aws" {
  region = "eu-south-2"
}

variable "cluster_name" {
  description = "Name of already existing EKS Cluster"
  type = string
  default = "eks-multitier-cluster"
}

data "aws_eks_cluster" "main" {
    name = var.cluster_name
}

data "aws_eks_cluster_auth" "main" {
  name = var.cluster_name
}

provider "kubernetes" {
  host = data.aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
  token = data.aws_eks_cluster_auth.main.token
}