##### Local Variables & Data Sources #####
#########################################

locals {
  all_public          = "0.0.0.0/0"
  all_public_ipv6     = "::/0"
  availability_zone_a = "${var.aws_region}a"
  availability_zone_b = "${var.aws_region}b"
  public_subnet_a     = "10.10.11.0/28"
  public_subnet_b     = "10.10.12.0/28"
  private_subnet_a    = "10.10.21.0/24"
  private_subnet_b    = "10.10.22.0/24"
}

data "aws_ami" "ubuntu" {
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners      = ["099720109477"]
  most_recent = true
}

data "aws_ami" "ubuntu_nginx" {
  filter {
    name   = "name"
    values = [var.ami_name]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  most_recent = true
  owners      = ["self"]
}


##### Resources #####
####################


### VPC ###
resource "aws_vpc" "main" {
  cidr_block       = var.vpc_cidr_block
  instance_tenancy = "default"
  tags = {
    "Name" = "main"
  }
}

resource "aws_internet_gateway" "main-igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    "Name" = "main-vpc-igw"
  }
}

resource "aws_nat_gateway" "main-natgw" {
  allocation_id = aws_eip.natgw_eip.id
  subnet_id     = aws_subnet.public_subnet_a.id
  tags = {
    Name = "main-vpc-natgw"
  }
}

resource "aws_eip" "natgw_eip" {
  vpc = true
}

### Route Tables ###
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = local.all_public
    gateway_id = aws_internet_gateway.main-igw.id
  }

  tags = {
    "Name" = "public-route-table"
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = local.all_public
    nat_gateway_id = aws_nat_gateway.main-natgw.id
  }
  tags = {
    "Name" = "private-route-table"
  }
}

resource "aws_route_table_association" "public_subnet_a_rt" {
  subnet_id      = aws_subnet.public_subnet_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_subnet_b_rt" {
  subnet_id      = aws_subnet.public_subnet_b.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_subnet_a_rt" {
  subnet_id      = aws_subnet.private_subnet_a.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_subnet_b_rt" {
  subnet_id      = aws_subnet.private_subnet_a.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_default_route_table" "default_rt" {
  default_route_table_id = aws_vpc.main.main_route_table_id

  tags = {
    Name = "Default route table"
  }
}

### Subnets ###
resource "aws_subnet" "public_subnet_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnet_a
  availability_zone       = local.availability_zone_a
  map_public_ip_on_launch = true
  tags = {
    "Name" = "Main-VPC-Public-Subnet-A"
  }
}

resource "aws_subnet" "public_subnet_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnet_b
  availability_zone       = local.availability_zone_b
  map_public_ip_on_launch = true
  tags = {
    "Name" = "Main-VPC-Public-Subnet-B"
  }
}

resource "aws_subnet" "private_subnet_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.private_subnet_a
  availability_zone       = local.availability_zone_a
  map_public_ip_on_launch = false

  tags = {
    "Name" = "Main-VPC-Private-Subnet-A"
  }
}

resource "aws_subnet" "private_subnet_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.private_subnet_b
  availability_zone       = local.availability_zone_b
  map_public_ip_on_launch = false

  tags = {
    "Name" = "Main-VPC-Private-Subnet-B"
  }
}


### Security Groups ###
resource "aws_security_group" "public_instance_sg" {
  name        = "PublicSubnet-SG"
  description = "Security group for public subnet"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port        = "22"
    to_port          = "22"
    protocol         = "tcp"
    cidr_blocks      = [local.all_public]
    ipv6_cidr_blocks = [local.all_public_ipv6]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = [local.all_public]
    ipv6_cidr_blocks = [local.all_public_ipv6]
  }

  tags = {
    Name = "PublicSubnet-SG"
  }
}

resource "aws_security_group" "private_instance_sg" {
  description = "Security group for private subnet"
  name        = "PrivateSubnet-SG"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = [local.public_subnet_a, local.public_subnet_b]
  }
  ingress {
    from_port        = "80"
    to_port          = "80"
    protocol         = "tcp"
    cidr_blocks      = [local.all_public]
    ipv6_cidr_blocks = [local.all_public_ipv6]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = [local.all_public]
    ipv6_cidr_blocks = [local.all_public_ipv6]
  }

  tags = {
    Name = "PrivateSubnet-SG"
  }
}

## EC2 Instances ###
# Key pair used to login to instances via SSH
resource "tls_private_key" "generated_instance_key" {
  algorithm = "RSA"
  rsa_bits  = "4096"
}

resource "aws_key_pair" "instance_key_pair" {
  key_name   = var.instance_key_pair
  public_key = tls_private_key.generated_instance_key.public_key_openssh
}

resource "aws_instance" "public_instance" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.bastion_host_instance_type
  subnet_id              = aws_subnet.public_subnet_a.id
  vpc_security_group_ids = [aws_security_group.public_instance_sg.id]
  key_name               = aws_key_pair.instance_key_pair.id

  root_block_device {
    volume_size           = 8
    delete_on_termination = true
    tags = {
      "Name" = "EBS-Public-Instance"
    }
  }
  tags = {
    "Name" = "Public-Instance"
  }
  depends_on = [aws_internet_gateway.main-igw]
}

resource "aws_instance" "private_instance" {
  ami                    = data.aws_ami.ubuntu_nginx.id
  instance_type          = var.server_instance_type
  subnet_id              = aws_subnet.private_subnet_a.id
  vpc_security_group_ids = [aws_security_group.private_instance_sg.id]
  key_name               = aws_key_pair.instance_key_pair.id

  root_block_device {
    volume_size           = 8
    delete_on_termination = true
    tags = {
      "Name" = "EBS-Private-Instance"
    }
  }
  tags = {
    "Name" = "Private-Instance"
  }
  depends_on = [aws_nat_gateway.main-natgw]
}
