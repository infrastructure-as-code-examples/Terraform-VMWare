###############################################################################
# Inputs
###############################################################################
variable "role" {}

variable "ssh_username" {}
variable "ssh_password" {}

variable "ipv4_address_list" {
  default = []
}

variable "salt_master_ipv4_address" {}

variable "wait_on" {
  default = []
}

###############################################################################
# Force Inter-Module Dependency
###############################################################################
resource "null_resource" "waited_on" {
  count = "${length(var.wait_on)}"

  provisioner "local-exec" {
    command = "echo Dependency Resolved: Configure ${var.role} depends upon ${element(var.wait_on, count.index)}"
  }
}

###############################################################################
# Restart Salt Minion Service
###############################################################################
resource "null_resource" "restart_salt_minion" {
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
      "sudo service salt-minion restart",
      "sleep 60",
    ]
  }

  depends_on = [
    "null_resource.waited_on",
  ]
}

###############################################################################
# Apply Docker Role
###############################################################################
resource "null_resource" "apply_salt_states" {
  connection {
    user     = "${var.ssh_username}"
    password = "${var.ssh_password}"
    host     = "${var.salt_master_ipv4_address}"
    type     = "ssh"
  }

  provisioner "remote-exec" {
    inline = [
      "set -eou pipefail",
      "sudo salt -t 30 -G 'roles:${var.role}' test.ping",
      "sudo salt -t 30 -G 'roles:${var.role}' state.apply",
    ]
  }

  depends_on = [
    "null_resource.restart_salt_minion",
  ]
}

###############################################################################
# Outputs
###############################################################################
output "wait_on" {
  value      = "Salt States Applied: ${var.role}"
  depends_on = ["null_resource.apply_salt_states"]
}
