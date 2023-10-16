# Create security group
resource "aws_security_group" "graylog_sg" {
  name        = "Allow Public Access for Graylog UI"
  description = "Allow Public Access for Graylog UI"
  vpc_id      = var.vpc_id
  ingress {
    description = "Allow All"
    from_port   = "80"
    to_port     = "80"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow SSH"
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    Name         = "Graylog UI"
    "Management" = "Terraform"
  }
}