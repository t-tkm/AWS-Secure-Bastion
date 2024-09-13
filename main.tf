################
# Create a VPC #
################
resource "aws_vpc" "main" {
  cidr_block           = var.main_vpc_cidr
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.system_name}-vpc"
  }
}

##############################
# Internet Gateway & NAT GW  #
##############################
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.system_name}-igw"
  }
}

resource "aws_eip" "nat_eip" {
  vpc = true

  tags = {
    Name = "${var.system_name}-nat-eip"
  }
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name = "${var.system_name}-nat-gw"
  }
}

###########################
# Public Subnet Resources #
###########################
resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.main.id
  availability_zone = var.az1
  cidr_block        = var.public_subnet

  tags = {
    Name = "${var.system_name}-public-subnet-1a"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.system_name}-public-rt"
  }
}

resource "aws_route_table_association" "public_rt_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

#####################################
# Private Firewall Subnet Resources #
#####################################
resource "aws_subnet" "private_firewall_subnet" {
  vpc_id            = aws_vpc.main.id
  availability_zone = var.az1
  cidr_block        = var.private_subnet_firewall

  tags = {
    Name = "${var.system_name}-private-firewall-subnet-1a"
  }
}

resource "aws_route_table" "private_firewall_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "${var.system_name}-private-firewall-rt"
  }
}

resource "aws_route_table_association" "private_firewall_rt_association" {
  subnet_id      = aws_subnet.private_firewall_subnet.id
  route_table_id = aws_route_table.private_firewall_rt.id
}

###############################
# AWS Network Firewall Setup  #
###############################
resource "aws_networkfirewall_rule_group" "stateful_rule_group" {
  name     = "${var.system_name}-stateful-rule-group"
  capacity = 100
  type     = "STATEFUL"

  rule_group {
    rules_source {
      rules_source_list {
        generated_rules_type = "DENYLIST"
        target_types         = ["HTTP_HOST"]
        targets              = ["www.yahoo.co.jp"]
      }
    }
  }
}

resource "aws_networkfirewall_firewall_policy" "firewall_policy" {
  name = "${var.system_name}-firewall-policy"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]

    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.stateful_rule_group.arn
    }
  }
}

resource "aws_networkfirewall_firewall" "firewall" {
  name                = "${var.system_name}-firewall"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.firewall_policy.arn
  vpc_id              = aws_vpc.main.id

  subnet_mapping {
    subnet_id = aws_subnet.private_firewall_subnet.id
  }

  tags = {
    Name = "${var.system_name}-firewall"
  }
}

############################
# S3 Bucket for Firewall Logs #
############################
resource "aws_s3_bucket" "firewall_logs" {
  bucket = "${var.system_name}-firewall-logs"
  acl    = "private"

  tags = {
    Name = "${var.system_name}-firewall-logs"
  }
}

resource "aws_networkfirewall_logging_configuration" "firewall_logging" {
  firewall_arn = aws_networkfirewall_firewall.firewall.arn

  logging_configuration {
    log_destination_config {
      log_destination = {
        bucketName = aws_s3_bucket.firewall_logs.bucket
        prefix     = "flow"
      }
      log_destination_type = "S3"
      log_type             = "FLOW"
    }

    log_destination_config {
      log_destination = {
        bucketName = aws_s3_bucket.firewall_logs.bucket
        prefix     = "alert"
      }
      log_destination_type = "S3"
      log_type             = "ALERT"
    }
  }
}

####################################
# Private Bastion Subnet Resources #
####################################
resource "aws_subnet" "private_bastion_subnet" {
  vpc_id            = aws_vpc.main.id
  availability_zone = var.az1
  cidr_block        = var.private_subnet_bastion

  tags = {
    Name = "${var.system_name}-private-bastion-subnet-1a"
  }
}

resource "aws_route_table" "private_bastion_rt" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.system_name}-private-bastion-rt"
  }
}

resource "aws_route_table_association" "private_bastion_rt_association" {
  subnet_id      = aws_subnet.private_bastion_subnet.id
  route_table_id = aws_route_table.private_bastion_rt.id
}

resource "aws_security_group" "private_bastion_sg" {
  name        = "${var.system_name}-private-bastion-sg"
  description = "${var.system_name}-private-bastion-sg"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.system_name}-private-bastion-sg"
  }
}

###################################
# Private Egress Subnet Resources #
###################################
resource "aws_subnet" "private_egress_subnet" {
  vpc_id            = aws_vpc.main.id
  availability_zone = var.az1
  cidr_block        = var.private_subnet_egress

  tags = {
    Name = "${var.system_name}-private-egress-subnet-1a"
  }
}

resource "aws_route_table" "private_egress_rt" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.system_name}-private-egress-rt"
  }
}

resource "aws_route_table_association" "private_egress_rt_association" {
  subnet_id      = aws_subnet.private_egress_subnet.id
  route_table_id = aws_route_table.private_egress_rt.id
}

resource "aws_security_group" "private_egress_sg" {
  name        = "${var.system_name}-private-egress-sg"
  description = "${var.system_name}-private-egress-sg"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.main_vpc_cidr]
    description = "Allow HTTPS traffic from within VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.system_name}-private-egress-sg"
  }
}

#######################
# VPC Endpoints Setup #
#######################
resource "aws_vpc_endpoint" "ssm" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.ssm"
  vpc_endpoint_type = "Interface"
  subnet_ids        = [aws_subnet.private_egress_subnet.id]
  security_group_ids = [aws_security_group.private_egress_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.system_name}-vpce-ssm"
  }
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.ssmmessages"
  vpc_endpoint_type = "Interface"
  subnet_ids        = [aws_subnet.private_egress_subnet.id]
  security_group_ids = [aws_security_group.private_egress_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.system_name}-vpce-ssmmessages"
  }
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.ec2messages"
  vpc_endpoint_type = "Interface"
  subnet_ids        = [aws_subnet.private_egress_subnet.id]
  security_group_ids = [aws_security_group.private_egress_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.system_name}-vpce-ec2messages"
  }
}
