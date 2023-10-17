variable "vpc_id" {
  default = ""
}

variable "public_subnet_id" {
  default = ""
}

variable "graglog_ui_port" {
  default = "9000"
}

variable "ami_id" {
  default = "ami-0136ddddd07f0584f"
}

variable "instance_type" {
  default = "t3.medium"
}


variable "up_script" {
  type    = string
  default = <<EOF
#!/bin/bash
sudo apt update -y
curl https://releases.rancher.com/install-docker/20.10.sh | sh
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/bin/docker-compose
sudo chmod +x /usr/bin/docker-compose
docker-compose -f /home/ubuntu/docker_compose.yaml up -d
EOF
}

variable "docker_compose" {
  type    = string
  default = <<EOF
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
      GRAYLOG_PASSWORD_SECRET: "graylog123456789asd"
      GRAYLOG_ROOT_PASSWORD_SHA2: "2001b7167d7ac966c3fef6ccc248dcf62842755e4ee9229dd7e5b90abc5573bc"
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
}