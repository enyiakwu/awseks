# Challenge: AWS EKS Deployment with Docker and Terraform

## Objective
In this challenge, you will be provided with a simple Go application that prints "Hello, World!" at the `/hello` endpoint. Your task is to package the application into a Docker container, create theoretical Terraform code to provision an EKS cluster and VPC on AWS, and implement a deployment pipeline to deploy the application onto the EKS cluster. This challenge will assess your expertise in Docker, AWS, Kubernetes, and CI/CD best practices.

## Task 1: Dockerizing the Go Application

1. Dockerfile is present on the current repository and builds successfully.
To set a repository to push to use `docker login -u USER_NAME REPO_URL` replacing the REPO_URL with your desired repository URL

## Task 2: Theoretical Terraform EKS Cluster and VPC
NOTE: the terraform main.tf contains all the IaC definitions, and this hasn't been fully tested on a live AWS account, hence beware of bugs as its theoretical.

## Task 3: Deployment Pipeline for EKS

Pipeline configuration file `pipeline-eks-deploy.yml` is present on the repository.
This is an Azure DevOps pipeline configuration file.
Included in it are the requested three stages: Build and Push Stage coupled together, and then Deploy Stage

## Submission

Deployment flow
1. Checkout or clone the repository as desired to an Azure DevOps repository
2. Configure a the variables.tf file with additional details as needed or include a .tfvars file for each environment: dev, staging, prod.
3. Run your `terraform init`, `terraform plan` and a `terraform apply` accordingly after resolving any issues. You can use ACCESS KEYS on the console for temporary access
4. A backend is not configured, hence state file would be placed on local machine
5. Once EKS Cluster is fully provisioned and running, then you can deploy the deployment configuration using the pipeline. The main.tf contains a kubernetes_manifest resource to create this file to be used in the next step.
6. You can commit this new manifest file to the desired branch for each environment
7. Run the pipeline to deploy according to that environment

