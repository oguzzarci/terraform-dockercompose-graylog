# Provides EC2 key pair
resource "aws_key_pair" "ec2_aws_key_pair" {
  key_name   = "ec2_ssh_key"
  public_key = tls_private_key.ec2_tls_private_key.public_key_openssh
}

# Create (and display) an SSH key
resource "tls_private_key" "ec2_tls_private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
# Create local key
resource "local_file" "keyfile" {
  content         = tls_private_key.ec2_tls_private_key.private_key_pem
  filename        = "ec2_key.pem"
  file_permission = "0400"
}