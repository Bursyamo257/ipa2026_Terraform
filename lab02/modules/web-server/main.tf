data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "web" {
  name        = "${var.name_prefix}-web-sg"
  description = "Allow HTTP inbound and all outbound"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidrs
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(var.tags, { Name = "${var.name_prefix}-web-sg" })
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.web.id]

  user_data              = <<-EOF
        #!/bin/bash
        dnf install -y nginx
        echo "<h1>Hello from Terraform - $(hostname)</h1>" > /usr/share/nginx/html/index.html
        ex.html
        systemctl enable --now nginx
    EOF

  root_block_device {
    volume_size = var.root_volume.size_gb
    volume_type = var.root_volume.type
    encrypted   = var.root_volume.encrypted
  }
  tags = merge(var.tags, { Name = "${var.name_prefix}-web" })
}
