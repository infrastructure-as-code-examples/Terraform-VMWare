###############################################################################
# Inputs
###############################################################################
variable "ssh_username" {}

variable "ssh_password" {}
variable "docker_manager_ipv4_address" {}

variable "ipv4_dns" {
  default = []
}

variable "database_name" {}
variable "database_host_port" {}
variable "database_user" {}
variable "database_host_volume" {}
variable "external_url" {}
variable "ssl_certificate" {}
variable "ssl_certificate_key" {}
variable "database_hostname" {}
variable "database_password" {}
variable "root_password" {}
variable "https_port" {}
variable "http_port" {}
variable "ssh_port" {}
variable "config_host_volume" {}
variable "logs_host_volume" {}
variable "data_host_volume" {}
variable "certificate_host_volume" {}
variable "smtp_address" {}
variable "smtp_port" {}
variable "smtp_user_name" {}
variable "smtp_password" {}
variable "smtp_domain" {}

variable "wait_on" {
  default = []
}

###############################################################################
# Force Inter-Module Dependency
###############################################################################
resource "null_resource" "waited_on" {
  count = "${length(var.wait_on)}"

  provisioner "local-exec" {
    command = "echo Dependency Resolved: Gitlab Container depends upon ${element(var.wait_on, count.index)}"
  }
}

###############################################################################
# Provision Gitlab Community Edition Container
###############################################################################
resource "null_resource" "run_gitlab" {
  connection {
    user     = "${var.ssh_username}"
    password = "${var.ssh_password}"
    host     = "${var.docker_manager_ipv4_address}"
    type     = "ssh"
  }

  triggers {
    compose_file       = "${md5(file("${path.module}/gitlab.yml"))}"
    database_host_port = "${md5(var.database_host_port)}"
    https_port         = "${md5(var.https_port)}"
    http_port          = "${md5(var.http_port)}"
    ssh_port           = "${md5(var.ssh_port)}"
    ipv4_dns           = "${md5(element(var.ipv4_dns, 0))}"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/create_secret.sh"
    destination = "/tmp/create_secret.sh"
  }

  provisioner "file" {
    source      = "${path.module}/gitlab.yml"
    destination = "/tmp/gitlab.yml"
  }

  provisioner "remote-exec" {
    inline = [
      "set -eou pipefail",
      "cd /tmp",
      "chmod +x create_secret.sh",
      "sudo ./create_secret.sh GITLAB_POSTGRES_PASSWORD_SECRET ${var.database_password}",
      "export DNS_SERVER=${element(var.ipv4_dns, 0)}",
      "export POSTGRES_DB=${var.database_name}",
      "export POSTGRES_HOST_PORT=${var.database_host_port}",
      "export POSTGRES_USER=${var.database_user}",
      "export GITLAB_DATABASE_HOST_VOLUME=${var.database_host_volume}",
      "export EXTERNAL_URL=${var.external_url}",
      "export SSL_CERTIFICATE=${var.ssl_certificate}",
      "export SSL_CERTIFICATE_KEY=${var.ssl_certificate_key}",
      "export POSTGRES_HOST=${var.database_hostname}",
      "export POSTGRES_PASSWORD=${var.database_password}",
      "export INITIAL_ROOT_PASSWORD=${var.root_password}",
      "export HTTPS_PORT=${var.https_port}",
      "export HTTP_PORT=${var.http_port}",
      "export SSH_PORT=${var.ssh_port}",
      "export GITLAB_CONFIG_HOST_VOLUME=${var.config_host_volume}",
      "export GITLAB_LOGS_HOST_VOLUME=${var.logs_host_volume}",
      "export GITLAB_DATA_HOST_VOLUME=${var.data_host_volume}",
      "export CERTIFICATE_HOST_VOLUME=${var.certificate_host_volume}",
      "export SMTP_ADDRESS=${var.smtp_address}",
      "export SMTP_PORT=${var.smtp_port}",
      "export SMTP_USER_NAME=${var.smtp_user_name}",
      "export SMTP_PASSWORD=${var.smtp_password}",
      "export SMTP_DOMAIN=${var.smtp_domain}",
      "sudo mkdir -p ${var.database_host_volume}",
      "sudo setfacl -R -m default:group:docker:rwx ${var.database_host_volume}",
      "sudo mkdir -p ${var.config_host_volume}",
      "sudo setfacl -R -m default:group:docker:rwx ${var.config_host_volume}",
      "sudo mkdir -p ${var.logs_host_volume}",
      "sudo setfacl -R -m default:group:docker:rwx ${var.logs_host_volume}",
      "sudo mkdir -p ${var.data_host_volume}",
      "sudo setfacl -R -m default:group:docker:rwx ${var.data_host_volume}",
      "sudo -E docker stack deploy --compose-file gitlab.yml GITLAB",
      "rm create_secret.sh",
      "rm gitlab.yml",
    ]
  }

  depends_on = [
    "null_resource.waited_on",
  ]
}
