##########################################
# NETWORKING
##########################################
# VPC components
##########################################
resource "aws_vpc" "main" {
    cidr_block       = var.main_vpc_cidr     # Defining the CIDR block use 10.0.0.0/24 for demo
    instance_tenancy = "default"

    enable_dns_hostnames = var.dns_enabled
    enable_dns_support = var.dns_enabled ? true : false

    tags = {
    Name = "${var.dep_env}-vpc"
    }

#     lifecycle {
#       ignore_changes = [ 
#         aws_route53_zone_association,
#        ]
# }
}

# Create a Public Subnets
resource "aws_subnet" "public_subnets" {
    count             = length(var.public_subnets)
    vpc_id            = aws_vpc.main.id
    cidr_block        = var.public_subnets[count.index]    # CIDR block of public subnets

    tags = {
    Name = "${var.dep_env}-public-subnet-${count.index + 1}"
    }
}

# Create a Private Subnet                   # Creating Private Subnets
resource "aws_subnet" "private_subnets" {
    count             = length(var.private_subnets)
    vpc_id            = aws_vpc.main.id
    cidr_block        = var.private_subnets[count.index]          # CIDR block of private subnets
    availability_zone = element(var.az, count.index)

    tags = {
    Name = "${var.dep_env}-private-subnet-${count.index + 1}"
    }
}

# Create Internet Gateway and attach it to VPC
resource "aws_internet_gateway" "IGW" {    # Creating Internet Gateway
    vpc_id =  aws_vpc.main.id               # vpc_id will be generated after we create VPC

    tags = {
    Name = "${var.dep_env}-igw"
    }
}

# Route table for Public Subnet
resource "aws_route_table" "public_RT" {    # Creating RT for Public Subnet
    vpc_id =  aws_vpc.main.id
        route {
    cidr_block = "0.0.0.0/0"               # Traffic from Public Subnet reaches Internet via Internet Gateway
    gateway_id = aws_internet_gateway.IGW.id
    }

    tags = {
    Name = "${var.dep_env}-public-RT"
    }
}

# Route table Association with Public Subnet's
resource "aws_route_table_association" "publicRTassociation" {
    count = length(var.public_subnets)
    subnet_id = element(aws_subnet.public_subnets.id, count.index)
    route_table_id = aws_route_table.public_RT.id
}

########################################################
# VPC components END
########################################################


########################################################
# EKS Cluster Configuration
########################################################
resource "aws_eks_cluster" "main" {
  name     = local.eks_cluster_name
  role_arn = aws_iam_service_linked_role.eks_cluster_role.arn # "your-eks-service-role-arn" # Replace with your EKS service role ARN
  version  = local.eks_version

  vpc_config {
    subnet_ids = concat(aws_subnet.public_subnets[*].id, aws_subnet.private_subnets[*].id)
  }

  tags = {
    Environment = var.dep_env
    Project     = var.project
  }

}

resource "aws_iam_service_linked_role" "eks_cluster_role" {
  aws_service_name = "eks.amazonaws.com"
}

# EKS Cluster Security Group
resource "aws_security_group" "eks_cluster" {
  name        = "${var.project}-${var.dep_env}-cluster-sg"
  description = "Cluster communication with worker nodes"
  vpc_id      = var.vpc_id #data.aws_vpc.this.id

# Egress allows Outbound traffic from the EKS cluster to the  Internet 

  egress {                   # Outbound Rule
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
# Ingress allows Inbound traffic to EKS cluster from the  Internet 

  ingress {                  # Inbound Rule
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # tags = local.common_tags
}

resource "aws_security_group_rule" "cluster_inbound" {
  description              = "Allow worker nodes to communicate with the cluster API Server"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_cluster.id
  source_security_group_id = aws_security_group.eks_nodes.id
  to_port                  = 443
  type                     = "ingress"
}

resource "aws_security_group_rule" "cluster_outbound" {
  description              = "Allow cluster API Server to communicate with the worker nodes"
  from_port                = 1024
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_cluster.id
  source_security_group_id = aws_security_group.eks_nodes.id
  to_port                  = 65535
  type                     = "egress"
}

###################
# EKS Cluter End
###################

###################
# EKS Cluster Nodes
###################

locals {
  name              = "${var.project}-${var.dep_env}" // maintain only two syllabus
  region            = "eu-west-1"
  # environment       = var.env
  eks_node_policies = ["AmazonEKSWorkerNodePolicy", "AmazonEKS_CNI_Policy", "AmazonEC2ContainerRegistryReadOnly"]
  common_tags = {
    Name        = "${local.name}"
  }
  vpc_id = try(var.vpc_id, "")

}


# EKS Node Groups
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project}-node-group"
  node_role_arn   = aws_iam_service_linked_role.eks_cluster_role.arn # aws_iam_role.node.arn
  subnet_ids      = concat(aws_subnet.public_subnets[*].id, aws_subnet.private_subnets[*].id) # var.subnet_ids

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 2
  }

  ami_type       = "AL2_x86_64" # AL2_x86_64, AL2_x86_64_GPU, AL2_ARM_64, CUSTOM
  capacity_type  = "ON_DEMAND"  # ON_DEMAND, SPOT
  disk_size      = 100
  instance_types = ["t2.medium"]

  # timeouts {
  #   create = "30m"
  #   delete = "30m"
  # }

  lifecycle {
    create_before_destroy = true
    # ignore_changes = [
    #   scaling_config[0].desired_size,
    # ]
  }

  tags = {
    "kubernetes.io/cluster/${aws_eks_cluster.main.name}" = "owned"
    "k8s.io/cluster/${aws_eks_cluster.main.name}"        = "owned"    
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
  ]
}


# EKS Node IAM Role
resource "aws_iam_role" "node" {
  name = "${var.project}-node-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
  
  tags = {
    Name                                           = "${var.project}-node-role"
    "kubernetes.io/cluster/${aws_eks_cluster.main.name}" = "owned"
  }

}


resource "aws_iam_role_policy_attachment" "eks_node_role" {
  for_each = toset(local.eks_node_policies)
  policy_arn = "arn:aws:iam::aws:policy/${each.value}"
  role       = aws_iam_role.node.name
}

# resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
#   role       = aws_iam_role.node.name
# }

# resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
#   role       = aws_iam_role.node.name
# }

# resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
#   role       = aws_iam_role.node.name
# }


# EKS Node Security Group
resource "aws_security_group" "eks_nodes" {
  name        = "${var.project}-node-sg"
  description = "Security group for all nodes in the cluster"
  vpc_id      = local.vpc_id # data.aws_vpc.this.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name                                           = "${var.project}-node-sg"
    "kubernetes.io/cluster/${var.project}-cluster" = "owned"
  }
}

resource "aws_security_group_rule" "nodes_internal" {
  description              = "Allow nodes to communicate with each other"
  from_port                = 0
  protocol                 = -1
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.eks_nodes.id
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "nodes_cluster_inbound" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 1024
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.eks_cluster.id
  to_port                  = 65535
  type                     = "ingress"
}

#############################
resource "aws_security_group_rule" "egress_cluster_443" {
  description              = "Node groups to cluster API"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_cluster.id # aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.eks_nodes.id
  
  type                     = "egress"
  # source_cluster_security_group = true
}

resource "aws_security_group_rule" "ingress_cluster_443" {
  description              = "Cluster API to node groups"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.eks_cluster.id
  
  type                     = "ingress"
  # source_cluster_security_group = true
}

resource "aws_security_group_rule" "ingress_cluster_kubelet" {
  description              = "Cluster API to node kubelets"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.eks_cluster.id
  
  type                     = "ingress"
  # source_cluster_security_group = true
}

resource "aws_security_group_rule" "ingress_self_coredns_tcp" {
  description              = "Node to node CoreDNS"
  from_port                = 53
  to_port                  = 53
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.eks_nodes.id
  
  type                     = "ingress"
  # self                     = true
}

resource "aws_security_group_rule" "egress_self_coredns_tcp" {
  description              = "Node to node CoreDNS"
  from_port                = 53
  to_port                  = 53
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.eks_nodes.id
  
  type                     = "egress"
  # self                     = true
}

resource "aws_security_group_rule" "ingress_self_coredns_udp" {
  description              = "Node to node CoreDNS"
  from_port                = 53
  to_port                  = 53
  protocol                 = "udp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.eks_nodes.id
  
  type                     = "ingress"
  # self                     = true
}

resource "aws_security_group_rule" "egress_self_coredns_udp" {
  description              = "Node to node CoreDNS"
  from_port                = 53
  to_port                  = 53
  protocol                 = "udp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.eks_nodes.id
  
  type                     = "egress"
  # self                     = true
}

resource "aws_security_group_rule" "egress_https" {
  description              = "Egress all HTTPS to internet"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.eks_nodes.id
  
  type                     = "egress"
}

resource "aws_security_group_rule" "egress_ntp_tcp" {
  description              = "Egress NTP/TCP to internet"
  from_port                = 123
  to_port                  = 123
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.eks_nodes.id
  
  type                     = "egress"
}


################################################
# node-group null resource
################################################

resource "null_resource" "gen_cluster_auth" {
triggers = {
    always_run = timestamp()
}
depends_on = [aws_eks_node_group.main]
provisioner "local-exec" {
    on_failure  = fail
    when = create
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOT
        ./c9-auth.sh
        echo "************************************************************************************"
     EOT
}
}

###############################
# node-groups END
###############################



########################################################
# End of EKS Configuration
########################################################

########################################################
# Generate a Kuberenetes Manifest for the app
########################################################
resource "kubernetes_manifest" "app_deployment" {
  manifest = <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${local.app_name}
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ${local.app_name}
  template:
    metadata:
      labels:
        app: ${local.app_name}
    spec:
      containers:
      - name: ${local.app_name}
        image: ${var.docker_image}
        ports:
        - containerPort: ${local.app_port}
        env:
        - name: PORT  # Assuming you want to pass an environment variable 'PORT'
          value: "${local.app_port}"
        # Other container configurations like environment variables, resources, etc. can be added here
EOF
}
