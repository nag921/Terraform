##############################################################################
# VPC
# The top-level network boundary for all resources in this landing zone.
##############################################################################

resource "aws_vpc" "dev_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "dev-vpc"
  }
}

##############################################################################
# Subnets
# Public subnets have a route to the Internet Gateway (direct internet access).
# Private subnets route outbound traffic through the NAT Gateway only.
##############################################################################

# --- Public Subnets ---

resource "aws_subnet" "public_dev_subnet_1" {
  vpc_id            = aws_vpc.dev_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "dev-subnet-1"
  }
}

resource "aws_subnet" "public_dev_subnet_2" {
  vpc_id            = aws_vpc.dev_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "dev-subnet-2"
  }
}

# --- Private Subnets ---

resource "aws_subnet" "private_dev_subnet_1" {
  vpc_id            = aws_vpc.dev_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "dev-private-subnet-1"
  }
}

resource "aws_subnet" "private_dev_subnet_2" {
  vpc_id            = aws_vpc.dev_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "dev-private-subnet-2"
  }
}

##############################################################################
# Internet Gateway
# Attached to the VPC to allow inbound/outbound internet traffic for
# resources in public subnets.
##############################################################################

resource "aws_internet_gateway" "igw_dev" {
  vpc_id = aws_vpc.dev_vpc.id
  tags = {
    Name = "dev-igw"
  }
}

##############################################################################
# NAT Gateway
# Placed in a public subnet so private subnet resources can initiate outbound
# internet connections without being directly reachable from the internet.
# Requires an Elastic IP address.
##############################################################################

# Elastic IP allocated for the NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

# NAT Gateway resides in public_dev_subnet_1 (us-east-1a)
resource "aws_nat_gateway" "dev_nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_dev_subnet_1.id
  tags = {
    Name = "dev-nat-gw"
  }
  # Must wait for the IGW to be attached before the NAT GW can route traffic
  depends_on = [aws_internet_gateway.igw_dev]
}

##############################################################################
# Route Tables
# Public route table sends all traffic (0.0.0.0/0) to the Internet Gateway.
# Private route table sends all traffic (0.0.0.0/0) to the NAT Gateway.
##############################################################################

# --- Public Route Table ---

resource "aws_route_table" "rt_dev" {
  vpc_id = aws_vpc.dev_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_dev.id
  }
  tags = {
    Name = "dev-rt"
  }
}

# --- Private Route Table ---

resource "aws_route_table" "rt_dev_private" {
  vpc_id = aws_vpc.dev_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.dev_nat_gw.id
  }
  tags = {
    Name = "dev-private-rt"
  }
}

##############################################################################
# Route Table Associations
# Links each subnet to its corresponding route table.
##############################################################################

# --- Public Subnet Associations (→ Public Route Table) ---

resource "aws_route_table_association" "public_dev_subnet_1_association" {
  subnet_id      = aws_subnet.public_dev_subnet_1.id
  route_table_id = aws_route_table.rt_dev.id
}

resource "aws_route_table_association" "public_dev_subnet_2_association" {
  subnet_id      = aws_subnet.public_dev_subnet_2.id
  route_table_id = aws_route_table.rt_dev.id
}

# --- Private Subnet Associations (→ Private Route Table) ---

resource "aws_route_table_association" "private_dev_subnet_1_association" {
  subnet_id      = aws_subnet.private_dev_subnet_1.id
  route_table_id = aws_route_table.rt_dev_private.id
}

resource "aws_route_table_association" "private_dev_subnet_2_association" {
  subnet_id      = aws_subnet.private_dev_subnet_2.id
  route_table_id = aws_route_table.rt_dev_private.id
}