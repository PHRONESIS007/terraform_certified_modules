# provider "aws" {
#   region = "us-east-1"
#   assume_role {
#     role_arn = "arn:aws:iam::117527926098:role/Dev-Engineer"
#   }

# }

# terraform {
#   backend "s3" {
#     bucket   = "oluwa-remote-state"
#     key      = "dev/layer16/terraform.tfstate"
#     region   = "us-east-1"
#     role_arn = "arn:aws:iam::117527926098:role/Dev-Engineer"
#   }
# }

data "aws_availability_zones" "current" {}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags       = merge(var.tags, { Name = "${var.env}-vpc" })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = merge(var.tags, { Name = "${var.env}-igw" })
}

resource "aws_subnet" "public_subnets" {
  vpc_id                  = aws_vpc.main.id
  count                   = length(var.public_subnet_cidrs)
  cidr_block              = element(var.public_subnet_cidrs, count.index)
  availability_zone       = data.aws_availability_zones.current.names[count.index]
  map_public_ip_on_launch = true
  tags                    = merge(var.tags, { Name = "${var.env}-public-subnet-${count.index + 1}" })

}

resource "aws_route_table" "public_subnets" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = merge(var.tags, { Name = "${var.env}-route-public-subnets" })
}

resource "aws_route_table_association" "public_subnets" {
  count          = length(var.public_subnet_cidrs)
  route_table_id = aws_route_table.public_subnets.id
  subnet_id      = element(aws_subnet.public_subnets[*].id, count.index)
}

resource "aws_eip" "nat" {
  vpc        = true
  count      = length(var.private_subnet_cidrs)
  tags       = merge(var.tags, { Name = "${var.env}-eip-${count.index + 1}" })
  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "nat" {
  count         = length(var.private_subnet_cidrs)
  allocation_id = element(aws_eip.nat[*].id, count.index)
  subnet_id     = aws_subnet.public_subnets[count.index].id
  tags          = merge(var.tags, { Name = "${var.env}-nat-gw-${count.index + 1}" })
}

resource "aws_subnet" "private_subnets" {
  vpc_id            = aws_vpc.main.id
  count             = length(var.private_subnet_cidrs)
  cidr_block        = element(var.private_subnet_cidrs, count.index)
  availability_zone = data.aws_availability_zones.current.names[count.index]
  tags              = merge(var.tags, { Name = "${var.env}-private-subnet-${count.index + 1}" })
}

resource "aws_route_table" "private_subnets" {
  vpc_id = aws_vpc.main.id
  count  = length(var.private_subnet_cidrs)
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat[count.index].id
  }
  tags = merge(var.tags, { Name = "${var.env}-route-private-subnets-${count.index + 1}" })
}

resource "aws_route_table_association" "private_route" {
  count          = length(var.private_subnet_cidrs)
  route_table_id = aws_route_table.private_subnets[count.index].id
  subnet_id      = aws_subnet.private_subnets[count.index].id
}
