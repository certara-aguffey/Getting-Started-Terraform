##################################################################################
# PROVIDERS - telling the provider what AWS account we want to use and how we are going to access it (and what region)
##################################################################################

provider "aws" {
  access_key = "ACCESS_KEY"
  secret_key = "SECRET_KEY"
  region     = "us-east-1"
}

##################################################################################
# DATA - data object, service manager parameter, named/labeled ami. The value is a path to a parameter (grabs the latest Amazon Linux 2 AMI ID for the region we're currently using)
##################################################################################

data "aws_ssm_parameter" "ami" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

##################################################################################
# RESOURCES
##################################################################################

# NETWORKING #
resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

}

# same vpc ID
# map public IP = true --> so when we spin up an EC2 instance in this subnet, it gets a public IP address
resource "aws_subnet" "subnet1" {
  cidr_block              = "10.0.0.0/24"
  vpc_id                  = aws_vpc.vpc.id
  map_public_ip_on_launch = true
}

# ROUTING #
resource "aws_route_table" "rtb" {
  vpc_id = aws_vpc.vpc.id

  # route to add to route table
  # creating default route, and pointing it at our internet gateway (so traffic can get out through igw)
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# associate the route table with our single subnet
resource "aws_route_table_association" "rta-subnet1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.rtb.id
}

# SECURITY GROUPS #
# Nginx security group - allows port 80 from anywhere to talk to our EC2 instance
resource "aws_security_group" "nginx-sg" {
  name   = "nginx_sg"
  vpc_id = aws_vpc.vpc.id

  # HTTP access from anywhere (0.0.0.0/0 means allow traffic from anywhere)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access (allows outbound traffic to anywhere)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# INSTANCES #
resource "aws_instance" "nginx1" {
  ami                    = nonsensitive(data.aws_ssm_parameter.ami.value)   #for AMI ID, we are referencing our data source (syntax is a little different than regular resources, we first need to specify it is a data source)
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.subnet1.id
  vpc_security_group_ids = [aws_security_group.nginx-sg.id]   #notice the key is plural, it's expecting a list (lists are enclosed in square brackets)

  # Sending some user data. Below is a script that will run when the instance starts up for the first time
    # installs and starts nginx
    # deleting the default "index.html" file, and replace it with something else
  # The "EOF" syntax is a way of passing a block of text that should not be interpreted, it should just be passed directly to the argument as is
  user_data = <<EOF
#! /bin/bash
sudo amazon-linux-extras install -y nginx1
sudo service nginx start
sudo rm /usr/share/nginx/html/index.html
echo '<html><head><title>Taco Team Server</title></head><body style=\"background-color:#1F778D\"><p style=\"text-align: center;\"><span style=\"color:#FFFFFF;\"><span style=\"font-size:28px;\">You did it! Have a &#127790;</span></span></p></body></html>' | sudo tee /usr/share/nginx/html/index.html
EOF

}

