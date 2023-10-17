resource "random_password" "graylog_password"{
  length           = 16
  special          = true
  override_special = "_!%^"
}

resource "aws_secretsmanager_secret" "graylog_password" {
  name = "graylog_password"
}

resource "aws_secretsmanager_secret_version" "graylog_password" {
  secret_id = aws_secretsmanager_secret.graylog_password.id
  secret_string = random_password.graylog_password.result
}

resource "aws_instance" "graylog_instance" {
  depends_on                  = [local_file.keyfile]
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.ec2_aws_key_pair.key_name
  associate_public_ip_address = true
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [aws_security_group.graylog_sg.id]
  root_block_device {
    volume_size = 30
  }
  tags = {
    Name         = "GrayLog"
    "Management" = "Terraform"
  }

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ubuntu"
    private_key = tls_private_key.ec2_tls_private_key.private_key_pem
  }

  //Copy docker_compose.yaml
  provisioner "file" {
    content     = "${var.docker_compose}"
    destination = "/home/ubuntu/docker_compose.yaml"
  }

  //Copy up.sh
  provisioner "file" {
    content     = "${var.up_script}"
    destination = "/home/ubuntu/up.sh"
  }

  //Run up.sh
  provisioner "remote-exec" {
    inline = [
      "sudo sh /home/ubuntu/up.sh"
    ]
  }


}