# Versión de Terraform y del "plugin" de AWS que vamos a usar
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Conexión con AWS: región del Learner Lab.
# Las credenciales las toma solo de tu archivo .aws\credentials
provider "aws" {
  region = "us-east-1"
}

# Busca la imagen (AMI) más reciente de Amazon Linux 2023.
# "data" = buscar algo que YA existe en AWS, no crearlo.
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# Security Group: qué puertos de la EC2 quedan abiertos.
# "resource" = algo que Terraform SÍ va a crear.
resource "aws_security_group" "ep1" {
  name        = "andysmotors-ep1-sg"
  description = "EP1 - acceso SSH a la EC2"

  # Entrada: SSH (puerto 22), para conectarse con EC2 Instance Connect
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Salida: todo permitido (para instalar paquetes desde internet)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# La EC2 de la EP1
resource "aws_instance" "ep1" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  key_name               = "vockey"
  iam_instance_profile   = "LabInstanceProfile"
  vpc_security_group_ids = [aws_security_group.ep1.id]

  # Monitoreo detallado: CloudWatch toma datos cada 1 minuto (no cada 5)
  monitoring = true

  # Se ejecuta una sola vez al crear la EC2: instala la herramienta de estrés
  user_data = <<-EOF
    #!/bin/bash
    dnf install -y stress-ng
  EOF

  tags = {
    Name = "AndysMotors-EP1"
  }
}

# Datos que Terraform muestra al terminar
output "instance_id" {
  value = aws_instance.ep1.id
}

output "ip_publica" {
  value = aws_instance.ep1.public_ip
}
