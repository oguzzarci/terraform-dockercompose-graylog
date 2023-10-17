resource "random_password" "graylog_password" {
  length           = 16
  special          = true
  override_special = "_!%^"
}

resource "aws_secretsmanager_secret" "graylog_password" {
  name = "graylog_password"
}

resource "aws_secretsmanager_secret_version" "graylog_password" {
  secret_id     = aws_secretsmanager_secret.graylog_password.id
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
    content     = <<EOF
version: "3.8"

services:
  mongodb:
    image: "mongo:7.0"
    volumes:
      - "mongodb_data:/data/db"
    restart: "on-failure"

  opensearch:
    image: "opensearchproject/opensearch:2.4.0"
    environment:
      - "OPENSEARCH_JAVA_OPTS=-Xms1g -Xmx1g"
      - "bootstrap.memory_lock=true"
      - "discovery.type=single-node"
      - "action.auto_create_index=false"
      - "plugins.security.ssl.http.enabled=false"
      - "plugins.security.disabled=true"
    ulimits:
      memlock:
        hard: -1
        soft: -1
      nofile:
        soft: 65536
        hard: 65536
    volumes:
      - "os_data:/usr/share/opensearch/data"
    restart: "on-failure"

  graylog:
    hostname: "server"
    image: "graylog/graylog:5.0"
    depends_on:
      opensearch:
        condition: "service_started"
      mongodb:
        condition: "service_started"
    entrypoint: "/usr/bin/tini -- wait-for-it opensearch:9200 --  /docker-entrypoint.sh"
    environment:
      GRAYLOG_NODE_ID_FILE: "/usr/share/graylog/data/config/node-id"
      GRAYLOG_PASSWORD_SECRET: "${aws_secretsmanager_secret_version.graylog_password.secret_string}"
      GRAYLOG_ROOT_PASSWORD_SHA2: "${sha256(aws_secretsmanager_secret_version.graylog_password.secret_string)}"
      GRAYLOG_HTTP_BIND_ADDRESS: "0.0.0.0:9000"
      GRAYLOG_HTTP_EXTERNAL_URI: "http://localhost:9000/"
      GRAYLOG_ELASTICSEARCH_HOSTS: "http://opensearch:9200"
      GRAYLOG_MONGODB_URI: "mongodb://mongodb:27017/graylog"
    ports:
    - "5044:5044/tcp"   # Beats
    - "5140:5140/udp"   # Syslog
    - "5140:5140/tcp"   # Syslog
    - "5555:5555/tcp"   # RAW TCP
    - "5555:5555/udp"   # RAW TCP
    - "80:9000/tcp"   # Server API
    - "12201:12201/tcp" # GELF TCP
    - "12201:12201/udp" # GELF UDP
    #- "10000:10000/tcp" # Custom TCP port
    #- "10000:10000/udp" # Custom UDP port
    - "13301:13301/tcp" # Forwarder data
    - "13302:13302/tcp" # Forwarder config
    volumes:
      - "graylog_data:/usr/share/graylog/data/data"
      - "graylog_journal:/usr/share/graylog/data/journal"
    restart: "on-failure"

volumes:
  mongodb_data:
  os_data:
  graylog_data:
  graylog_journal:
EOF
    destination = "/home/ubuntu/docker_compose.yaml"
  }

  //Copy up.sh
  provisioner "file" {
    content     = var.up_script
    destination = "/home/ubuntu/up.sh"
  }

  //Run up.sh
  provisioner "remote-exec" {
    inline = [
      "sudo sh /home/ubuntu/up.sh"
    ]
  }


}