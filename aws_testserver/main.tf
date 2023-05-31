

data "aws_ami" "latest_amazon_linux" {
  owners      = ["137112412989"]
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

data "aws_subnet" "web" {
    id = var.subnet_id  
}

resource "aws_instance" "web_server" {
  ami                    = data.aws_ami.latest_amazon_linux.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.webserver.id]
  subnet_id              = var.subnet_id
  user_data              = <<EOF
    #!/bin/bash
    sudo su -
    yum update -y
    yum install httpd -y
    systemctl start httpd
    myip=`curl http://169.254.169.254/latest/meta-data/local-ipv4`
    
    cat <<HTMLTEXT > /var/www/html/index.html
    <h2>
    ${var.name} Webserver with IP: $myip <br>
    ${var.name} WebServer in AZ: ${data.aws_subnet.web.availability_zone}<br>
    Message:</h2> ${var.message}
    HTMLTEXT
    
    service httpd start
    chkconfig httpd on
    EOF
  tags = {
    Name  = "${var.name}-webserver-${var.subnet_id}"
    Owner = "Victoria O"
  }
}

resource "aws_security_group" "webserver" {
  name_prefix       = "${var.name}-webserver_sg-"
  description = "Security Group for Web server"
  vpc_id      = data.aws_subnet.web.vpc_id
  dynamic "ingress" {
    for_each = ["80", "22"]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name  = "${var.name}-web-server-sg"
    Owner = "Victoria O"
  }

}
