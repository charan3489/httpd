provider "aws" {
region = "ap-south-1"
access_key = "AKIATTORJ4TLTZCUQ7US"
private_key = "O4fTZnXLYfss9xmQHfUW1JRZZK2xqCUmW21Nw7/f"
}

resource "aws_vpc" "vpc" {
cidr_block = "10.0.0.0/27"
tags = {
Name = "my-vpc"
}
}

resource "aws_subnet" "public" {
cidr_block = "10.0.0.0/28"
vpc_id = aws_vpc.vpc.id
availability_zone = "ap-south-1a"
tags = {
Name = "public-subnet"
}
}

resource "aws_subnet" "private" {
cidr_block = "10.0.0.0/28"
vpc_id = aws_vpc.vpc.id
availability_zone = "ap-south-1a"
tags = {
Name = "private-subnet"
}
}

resource "aws_internet_gateway" "igw" {
vpc_id = aws_vpc.vpc.id
tags = {
Name = "my-igw"
}
}

resource "aws_eip" "ip" {
vpc = true
}

resource "aws_nat_gateway" "ngw" {
subnet_id = aws_subnet.public.id
allocation_id = aws_vpc.vpc.id
tags = {
Nme = "my-nat"
}
}

resource "aws_route_table" "pubrt" {
vpc_id = aws_vpc.vpc.id
route {
gateway_id = aws_internet_gateway.igw.id
cidr_block = "0.0.0.0/0"
}
tags = {
Name = "public-route"
}
}

resource "aws_route_table" "prirt" {
vpc_id = aws_vpc.vpc.id
route {
gateway_id = aws_nat_gateway.ngw.id
cidr_block = "0.0.0.0/0"
  }
tags = {
Name = "private-route"
}
}

resource "aws_route_table_association" "pubasso" {
subnet_id = aws_subnet.public.id
route_table_id = aws_route_table.pubrt.id
}

resource "aws_route_table_association" "priasso" {
subnet_id = aws_subnet.private.id
route_table_id = aws_route_table.prirt.id
}

resource "aws_security_group" "sg" {
vpc_id = aws_vpc.vpc.id

ingress {
from_port = 22
to_port = 22
protocol = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}

ingress {
from_port = 80
to_port = 80
protocol = "http"
cidr_blocks = ["0.0.0.0/0"]
}

  egress {
from_port = 0
to_port = 0
protocol = "-1"
cidr_blocks = ["0.0.0.0/0"]
}

tags = {
Name = "my-sg2"
}
}

resource "aws_instance" "first" {
ami = "ami-0607784b46cbe5816"
instance_type = "t2.micro"
security_groups = [aws_security_group.sg.id]
subnet_id = aws_route_table.pubrt.id
availability_zone = "ap-south-1a"
key_name = "ansible"
user_data = <<EOF
#!/bin/bash
sudo -i
yum install httpd -y
systemctl start httpd
chkconfig httpd on
echo "this is terraform code deployed in instance one" > /var/www/html/index.html
EOF

tags = {
Name= "test1"
}
}

resource "aws_instance" "second" {
ami = "ami-0607784b46cbe5816"
instance_type = "t2.micro"
security_groups = [aws_security_group.sg.id]
subnet_id = aws_route_table.prirt.id
availability_zone = "ap-south-1a"
key_name = "ansible"
user_data = <<EOF
#!/bin/bash
sudo -i
yum install httpd -y
systemctl start httpd
chkconfig httpd on
echo "this is terraform code deployed in instance two" > /var/www/html/index.html
EOF

tags = {
Name = "test2"
}
}

resource "aws_s3_bucket" "bucket" {
bucket = "test34891"
}

resource "aws_ebs_volume" "v1" {
availability_zone = "ap-south-1a"
size = 25
tags = {
Name = "my-v1"
}
}

resource "aws_ebs_volume" "v2" {
availability_zone = "ap-south-1a"
size = 25
tags = {
Name = "my-v2"
}
}

resource "aws_volume_attachment" "at1" {
instance_id = aws_instance.first.id
device_name = "/dev/xvdf"
volume_id = aws_ebs_volume.v1.id
}

resource "aws_volume_attachment" "at2" {
instance_id = aws_instance.second.id
device_name = "/dev/xvdf"
volume_id = aws_ebs_volume.v2.id
}

resource "aws_elb" "lb" {
name = "my-lb"
availability_zones= ["ap-south-1a", "ap-south-1b"]

listener {
instance_port = 80
instance_protocol = "http"
lb_port = 80
lb_protocol = "http"
}
  
health_check {
healthy_threshold = 3
unhealthy_threshold = 5
timeout =5
target = "HTTP:80/"
interval = 30
}

instances = ["${aws_instance.first.id}", "${aws_instance.second.id}"]
cross_zone_load_balancing = true
idle_timeout = 400
tags = {
Name = "my-lb"
}
}

