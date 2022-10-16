################
# Create a VPC #
################
 resource "aws_vpc" "Main" {
   cidr_block       = var.main_vpc_cidr
   instance_tenancy = "default"
   enable_dns_hostnames = true
   enable_dns_support   = true
   tags = {
        Name = "${var.system_name}-vpc"
    }
 }

/* step2

 resource "aws_internet_gateway" "IGW" {
    vpc_id =  aws_vpc.Main.id
 }

###########################
# Public subnet resources #
###########################
 resource "aws_subnet" "public_subnet" {
   vpc_id =  aws_vpc.Main.id
   availability_zone = "${var.az1}"
   cidr_block = "${var.public_subnet}"
   tags = {
        Name = "secure-public-1a"
    }
 }

 resource "aws_route_table" "PublicRT" {
    vpc_id =  aws_vpc.Main.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.IGW.id
     }
   tags = {
        Name = "secure-public-rt"
    }
 }

 resource "aws_route_table_association" "PublicRTassociation" {
    subnet_id = aws_subnet.public_subnet.id
    route_table_id = aws_route_table.PublicRT.id
 }

 resource "aws_eip" "nateIP" {
   vpc   = true
 }

 resource "aws_nat_gateway" "NATgw" {
   allocation_id = aws_eip.nateIP.id
   subnet_id = aws_subnet.public_subnet.id
 }
 

#####################################
# Private firewall subnet resources #
#####################################

 resource "aws_subnet" "private_subnet_firewall" {
   vpc_id =  aws_vpc.Main.id
   availability_zone = "${var.az1}"
   cidr_block = "${var.private_subnet_firewall}"
   tags = {
        Name = "secure-private-firewall-1a"
    }
 }
 
 resource "aws_route_table" "PrivateRT_firewall" {
   vpc_id = aws_vpc.Main.id
   route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.NATgw.id
   }
   tags = {
        Name = "secure-private-firewall-rt"
    }
 }

 resource "aws_route_table_association" "PrivateRTassociation_firewall" {
    subnet_id = aws_subnet.private_subnet_firewall.id
    route_table_id = aws_route_table.PrivateRT_firewall.id
 }

resource "aws_networkfirewall_rule_group" "my_ips" {
  capacity = 100
  name     = "example"
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
  name = "network-firewall-policy"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]
    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.my_ips.arn
    }
  }
}

resource "aws_networkfirewall_firewall" "firewall" {
  name                = "network-firewall"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.firewall_policy.arn
  vpc_id              = aws_vpc.Main.id

  subnet_mapping {
    subnet_id     = aws_subnet.private_subnet_firewall.id
  }
}

resource "aws_s3_bucket" "example" {
  bucket = "t-tkm-firewall-logs"
}

resource "aws_s3_bucket_acl" "example" {
  bucket = aws_s3_bucket.example.id
  acl    = "private"
}

resource "aws_networkfirewall_logging_configuration" "firewall_logging" {
  firewall_arn = aws_networkfirewall_firewall.firewall.arn
  logging_configuration {
    log_destination_config {
      log_destination = {
        bucketName = aws_s3_bucket.example.bucket
        prefix     = "flow"
      }
      log_destination_type = "S3"
      log_type             = "FLOW"
    }
  log_destination_config {
      log_destination = {
        bucketName = aws_s3_bucket.example.bucket
        prefix     = "alert"
      }
      log_destination_type = "S3"
      log_type             = "ALERT"
    }
  }
}
*/

####################################
# Private bastion subnet resources #
####################################
 resource "aws_subnet" "private_subnet_bastion" {
   vpc_id =  aws_vpc.Main.id
   availability_zone = "${var.az1}"
   cidr_block = "${var.private_subnet_bastion}"
   tags = {
        Name = "${var.system_name}-private-bastion-subnet-1a"
    }
 }
 
 resource "aws_route_table" "PrivateRT_bastion" {
   vpc_id = aws_vpc.Main.id
   tags = {
        Name = "${var.system_name}-private-bastion-route-table"
    }

 }

 resource "aws_route_table_association" "PrivateRTassociation_bastion" {
    subnet_id = aws_subnet.private_subnet_bastion.id
    route_table_id = aws_route_table.PrivateRT_bastion.id
 }

resource "aws_security_group" "private_bastion_sg" {
    name = "${var.system_name}-private-bastion-sg"
    vpc_id = aws_vpc.Main.id
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    description = "${var.system_name}-private-bastion-sg"
}

###################################
# Private egress subnet resources #
###################################
 resource "aws_subnet" "private_subnet_egress" {
   vpc_id =  aws_vpc.Main.id
   availability_zone = "${var.az1}"
   cidr_block = "${var.private_subnet_egress}"
   tags = {
        Name = "${var.system_name}-private-egress-subnet-1a"
    }
 }
 
 resource "aws_route_table" "PrivateRT_egress" {
   vpc_id = aws_vpc.Main.id
   tags = {
        Name = "${var.system_name}-private-egress-route-table"
    }
 }

 resource "aws_route_table_association" "PrivateRTassociation_egress" {
    subnet_id = aws_subnet.private_subnet_egress.id
    route_table_id = aws_route_table.PrivateRT_egress.id
 }

resource "aws_security_group" "private_egress_sg" {
    name = "${var.system_name}-private-egress-sg"
    vpc_id = aws_vpc.Main.id
    ingress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["${var.main_vpc_cidr}"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    description = "${var.system_name}-private-egress-route-sg"
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.Main.id
  service_name        = "com.amazonaws.${var.region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids = [
    aws_subnet.private_subnet_egress.id
  ]
  security_group_ids = [
    aws_security_group.private_egress_sg.id
  ]
  private_dns_enabled = true
  tags = {
        Name = "vpce_ssm"
    }
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = aws_vpc.Main.id
  service_name        = "com.amazonaws.${var.region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids = [
    aws_subnet.private_subnet_egress.id
  ]
  security_group_ids = [
    aws_security_group.private_egress_sg.id
  ]
  private_dns_enabled = true
  tags = {
        Name = "vpce_ssmmessages"
    }
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = aws_vpc.Main.id
  service_name        = "com.amazonaws.${var.region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids = [
    aws_subnet.private_subnet_egress.id
  ]
  security_group_ids = [
    aws_security_group.private_egress_sg.id
  ]
  private_dns_enabled = true
  tags = {
        Name = "vpce_ec2messages"
    }
}