variable "aws_region" {
  default = "ap-south-1"
}
variable "vpc_cidr_block" {
  default = "10.10.0.0/16"
}

variable "server_instance_type" {
  default = "t3a.medium"
}

variable "bastion_host_instance_type" {
  default = "t3a.micro"
}

variable "ami_name" {
  default     = "ubuntu1804-nginx"
  description = "AMI backed using packer"
}

variable "instance_key_pair" {
  default     = "terraform_ubuntu"
  description = "Name of key pair used to login to instances via SSH"
}
