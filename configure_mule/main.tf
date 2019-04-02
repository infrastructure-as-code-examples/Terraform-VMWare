###############################################################################
# Inputs
###############################################################################
variable "ssh_username" {}

variable "ssh_password" {}

variable "ipv4_address_list" {
  default = []
}

variable "hostname_list" {
  default = []
}

variable "mule_token" {}

variable "client_id" {}
variable "client_secret" {}

variable "wait_on" {
  default = []
}

###############################################################################
# Force Inter-Module Dependency
###############################################################################
resource "null_resource" "waited_on" {
  count = "${length(var.wait_on)}"

  provisioner "local-exec" {
    command = "echo Dependency Resolved: Configure Mule depends upon ${element(var.wait_on, count.index)}"
  }
}

###############################################################################
# Update Anypoint Credentials
###############################################################################
resource "null_resource" "update_credentials" {
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
      "if [[ $(uname -s) == 'Linux' ]]; then",
      "  sudo sed -i \"s/.*client_id.*/wrapper.java.additional.14=-Danypoint.platform.client_id=${var.client_id}/g\" /opt/mule-enterprise-standalone-4.1.1/conf/wrapper.conf",
      "  sudo sed -i \"s/.*client_secret.*/wrapper.java.additional.15=-Danypoint.platform.client_secret=${var.client_secret}/g\" /opt/mule-enterprise-standalone-4.1.1/conf/wrapper.conf",
      "else",
      "  sudo sed -i '' \"s/.*client_id.*/wrapper.java.additional.14=-Danypoint.platform.client_id=${var.client_id}/g\" /opt/mule-enterprise-standalone-4.1.1/conf/wrapper.conf",
      "  sudo sed -i '' \"s/.*client_secret.*/wrapper.java.additional.15=-Danypoint.platform.client_secret=${var.client_secret}/g\" /opt/mule-enterprise-standalone-4.1.1/conf/wrapper.conf",
      "fi",
    ]
  }

  depends_on = [
    "null_resource.waited_on",
  ]
}

###############################################################################
# Register Runtime with Anypoint Platform
###############################################################################
resource "null_resource" "register_runtime" {
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
      "sudo /opt/mule-enterprise-standalone-4.1.1/bin/amc_setup -H ${var.mule_token} ${element(var.hostname_list, count.index)}",
    ]
  }

  depends_on = [
    "null_resource.update_credentials",
  ]
}

###############################################################################
# Restart Mule Service
###############################################################################
resource "null_resource" "restart_runtime" {
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
      "sudo systemctl restart mule",
    ]
  }

  depends_on = [
    "null_resource.register_runtime",
  ]
}

###############################################################################
# Outputs
###############################################################################
output "wait_on" {
  value      = "Mule Runtime Registered with MuleSoft Anypoint Platform"
  depends_on = ["null_resource.register_runtime"]
}
