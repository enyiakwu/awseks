# Environment details
variable "dep_env" {
    type = string
    default = "dev"
}


# VPC variables
variable "dns_enabled" {
    type = bool
    default = false
}


variable "region" {
    type = string
    default = "eu-west-1"
}

variable "main_vpc_cidr" {
    type = string
    default = "10.0.0.0/16"
    }
variable "public_subnets" {
    type = list(string)
    default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"] 
    }
    
variable "private_subnets" {
    type = list(string)
    default = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}


variable "az" {
    type = list(string)
    default = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
}

##################################
# other env specific variables and locals
##################################

variable "vpc_name" {
  type    = string
}

variable "vpc_id" {
  type    = string
}

variable "eks_version" {
  type    = string
  default = "1.22"
}

variable "eks_cluster_name" {
  type    = string
  default = ""
}

variable "project" {
  description = "Name to be used on all the resources as identifier"
  type        = string
  default     = "nitro"
}

variable "app_name" {
  type    = string
  default = "nitro-go" # Update with your application name
}

variable "docker_image" {
  type    = string
  default = "hub.docker.com/repositories/enyiakwu/nitro-go:latest" # Replace with your Docker image URL
}

variable "app_port" {
  type    = number
  default = 8080 # Update with the port your application listens on
}


#####################################
# dev environment
#######################################
locals {
  vpc_name = "${var.dep_env == "dev" ? "${var.dep_env}-vpc" : "" }"
  eks_version = var.eks_version
  eks_cluster_name = "${var.dep_env}-cluster"
  app_name = "${var.dep_env}-${var.app_name}"
  app_port = "${var.dep_env == "dev" ? 8080 : "" }"
}

#####################################
# staging environment
#######################################
locals {
  vpc_name = "${var.dep_env == "staging" ? "${var.dep_env}-vpc" : "" }"
  app_port = "${var.dep_env == "staging" ? 8080 : "" }"
}


#####################################
# prod environment
#######################################
locals {
  vpc_name = "${var.dep_env == "prod" ? "${var.dep_env}-vpc" : "" }"
  app_port = "${var.dep_env == "prod" ? 4040 : "" }"
}
