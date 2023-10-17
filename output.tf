output "ssh_gralog_instance" {
  value = "ssh -i ${local_file.keyfile.filename} ubuntu@${aws_instance.graylog_instance.public_ip}"
}

output "gralog_ui" {
  value = "http://${aws_instance.graylog_instance.public_ip}"
}

output "graylog_password" {
  value = nonsensitive(aws_secretsmanager_secret_version.graylog_password.secret_string)

}