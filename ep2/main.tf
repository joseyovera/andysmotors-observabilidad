terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# Firewall: SSH, sitio web, Grafana y Prometheus
resource "aws_security_group" "ep2" {
  name        = "andysmotors-ep2-sg"
  description = "EP2 - plataforma AndysMotors + Prometheus + Grafana"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Sitio web AndysMotors (HAProxy)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Prometheus"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "ep2" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.medium"
  key_name               = "vockey"
  iam_instance_profile   = "LabInstanceProfile"
  vpc_security_group_ids = [aws_security_group.ep2.id]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  # Al arrancar: instala Docker, el plugin "docker compose" y Git
  user_data = <<-EOF
    #!/bin/bash
    dnf install -y docker git
    systemctl enable --now docker
    usermod -aG docker ec2-user
    mkdir -p /usr/local/lib/docker/cli-plugins
    curl -fsSL https://github.com/docker/compose/releases/download/v2.29.7/docker-compose-linux-x86_64 \
      -o /usr/local/lib/docker/cli-plugins/docker-compose
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
  EOF

  tags = {
    Name = "AndysMotors-EP2"
  }
}

output "ip_publica" {
  value = aws_instance.ep2.public_ip
}

