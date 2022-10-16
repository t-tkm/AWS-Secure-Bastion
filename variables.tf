variable "system_name" {
    default = "secure-bastion"
}
variable "region" {}
variable "main_vpc_cidr" {}
variable "az1" {}
variable "public_subnet" {}
variable "private_subnet_firewall" {}
variable "private_subnet_bastion" {}
variable "private_subnet_egress" {}