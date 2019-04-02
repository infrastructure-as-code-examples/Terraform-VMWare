###############################################################################
# Inputs
###############################################################################
variable "salt_master_ipv4_address_list" {
  default = []
}

variable "salt_master_ssh_username" {}
variable "salt_master_ssh_password" {}

variable "salt_minion_ipv4_address_list" {
  default = []
}

variable "wait_on" {
  default = []
}

###############################################################################
# Force Inter-Module Dependency
###############################################################################
resource "null_resource" "waited_on" {
  count = "${length(var.wait_on)}"

  provisioner "local-exec" {
    command = "echo Dependency Resolved: Configure Salt Master depends upon ${element(var.wait_on, count.index)}"
  }
}

###############################################################################
# Accept Pending Minion Keys and Restart the Salt Master's Minion
###############################################################################
resource "null_resource" "accept_salt_keys" {
  count = "${length(var.salt_master_ipv4_address_list)}"

  connection {
    user     = "${var.salt_master_ssh_username}"
    password = "${var.salt_master_ssh_password}"
    host     = "${element(var.salt_master_ipv4_address_list, count.index)}"
    type     = "ssh"
  }

  triggers {
    minions = "${join(", ", var.salt_minion_ipv4_address_list)}"
  }

  provisioner "remote-exec" {
    inline = [
      "set -eou pipefail",
      "sudo salt-key -A -y",
      "sudo salt-key",
      "sudo service salt-minion restart",
    ]
  }

  depends_on = [
    "null_resource.waited_on",
  ]
}

###############################################################################
# Outputs
###############################################################################
output "wait_on" {
  value = "Salt Minion Keys Accepted"

  depends_on = [
    "null_resource.accept_salt_keys",
  ]
}
