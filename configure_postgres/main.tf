###############################################################################
# Inputs
###############################################################################
variable "ssh_username" {}

variable "ssh_password" {}

variable "ipv4_address_list" {
  default = []
}

variable "postgres_password" {}
variable "ipv4_cidr_ip_address" {}
variable "ipv4_cidr_prefix_length" {}
variable "ipv6_cidr_ip_address" {}
variable "ipv6_cidr_prefix_length" {}
variable "ipv4_listen_ip_address" {}

variable "wait_on" {
  default = []
}

###############################################################################
# Force Inter-Module Dependency
###############################################################################
resource "null_resource" "waited_on" {
  count = "${length(var.wait_on)}"

  provisioner "local-exec" {
    command = "echo Dependency Resolved: Configure PostgreSQL depends upon ${element(var.wait_on, count.index)}"
  }
}

###############################################################################
# Update Host-Based Authentication
###############################################################################
resource "null_resource" "update_hba" {
  count = "${length(var.ipv4_address_list)}"

  triggers {
    ipv4_cidr_ip_address    = "${var.ipv4_cidr_ip_address}"
    ipv4_cidr_prefix_length = "${var.ipv4_cidr_prefix_length}"
    ipv6_cidr_ip_address    = "${var.ipv6_cidr_ip_address}"
    ipv6_cidr_prefix_length = "${var.ipv6_cidr_prefix_length}"
  }

  connection {
    user     = "${var.ssh_username}"
    password = "${var.ssh_password}"
    host     = "${element(var.ipv4_address_list, count.index)}"
    type     = "ssh"
  }

  provisioner "remote-exec" {
    inline = [
      "set -eou pipefail",
      "sudo -u postgres sh -c \"mv /var/lib/pgsql/10/data/pg_hba.conf /var/lib/pgsql/10/data/pg_hba.original\"",
      "sudo -u postgres sh -c \"echo 'host all all ${var.ipv4_cidr_ip_address}/${var.ipv4_cidr_prefix_length} md5' > /var/lib/pgsql/10/data/pg_hba.conf\"",
      "sudo -u postgres sh -c \"echo 'host all all ${var.ipv6_cidr_ip_address}/${var.ipv6_cidr_prefix_length} md5' >> /var/lib/pgsql/10/data/pg_hba.conf\"",
      "sudo -u postgres sh -c \"echo 'local replication all peer' >> /var/lib/pgsql/10/data/pg_hba.conf\"",
      "sudo -u postgres sh -c \"echo 'host replication all ${var.ipv4_cidr_ip_address}/${var.ipv4_cidr_prefix_length} md5' >> /var/lib/pgsql/10/data/pg_hba.conf\"",
      "sudo -u postgres sh -c \"echo 'host replication all ${var.ipv6_cidr_ip_address}/${var.ipv6_cidr_prefix_length} md5' >> /var/lib/pgsql/10/data/pg_hba.conf\"",
      "sudo -u postgres sh -c \"chmod 600 /var/lib/pgsql/10/data/pg_hba.conf\"",
    ]
  }

  depends_on = [
    "null_resource.waited_on",
  ]
}

###############################################################################
# Change Password
###############################################################################
resource "null_resource" "update_password" {
  count = "${length(var.ipv4_address_list)}"

  triggers {
    postgres_password = "${md5(var.postgres_password)}"
  }

  connection {
    user     = "${var.ssh_username}"
    password = "${var.ssh_password}"
    host     = "${element(var.ipv4_address_list, count.index)}"
    type     = "ssh"
  }

  provisioner "remote-exec" {
    inline = [
      "set -eou pipefail",
      "cd /tmp",
      "sudo -u postgres psql -c \"ALTER USER postgres WITH PASSWORD '${var.postgres_password}';\"",
    ]
  }

  depends_on = [
    "null_resource.waited_on",
  ]
}

###############################################################################
# Main Server Configuration
###############################################################################
resource "null_resource" "update_postgresql" {
  count = "${length(var.ipv4_address_list)}"

  triggers {
    ipv4_listen_ip_address = "${var.ipv4_listen_ip_address}"
  }

  connection {
    user     = "${var.ssh_username}"
    password = "${var.ssh_password}"
    host     = "${element(var.ipv4_address_list, count.index)}"
    type     = "ssh"
  }

  provisioner "remote-exec" {
    inline = [
      "set -eou pipefail",
      "sudo -u postgres sh -c \"test -f \"/var/lib/pgsql/10/data/postgresql.original\" || cp /var/lib/pgsql/10/data/postgresql.conf /var/lib/pgsql/10/data/postgresql.original\"",
      "if [[ $(uname -s) == 'Linux' ]]; then",
      "  sudo -u postgres sed -i \"s/.*listen_addresses.*/listen_addresses = '${var.ipv4_listen_ip_address}'/g\" /var/lib/pgsql/10/data/postgresql.conf",
      "else",
      "  sudu -u postgres sed -i '' \"s/.*listen_addresses.*/listen_addresses = '${var.ipv4_listen_ip_address}'/g\" /var/lib/pgsql/10/data/postgresql.conf",
      "fi",
    ]
  }

  depends_on = [
    "null_resource.waited_on",
  ]
}

###############################################################################
# Restart PostgreSQL Service
###############################################################################
resource "null_resource" "restart_postgres" {
  count = "${length(var.ipv4_address_list)}"

  connection {
    user     = "${var.ssh_username}"
    password = "${var.ssh_password}"
    host     = "${element(var.ipv4_address_list, count.index)}"
    type     = "ssh"
  }

  provisioner "remote-exec" {
    inline = [
      "set -eou pipefail",
      "sudo systemctl restart postgresql-10",
    ]
  }

  depends_on = [
    "null_resource.update_hba",
    "null_resource.update_postgresql",
    "null_resource.update_password",
  ]
}
