###############################################################################
# Inputs
###############################################################################
variable "ssh_username" {}

variable "ssh_password" {}

variable "ipv4_address_list" {
  default = []
}

variable "salt_master_ipv4_address" {}
variable "hostname" {}

variable "wait_on" {
  default = []
}

###############################################################################
# Force Inter-Module Dependency
###############################################################################
resource "null_resource" "waited_on" {
  count = "${length(var.wait_on)}"

  provisioner "local-exec" {
    command = "echo Dependency Resolved: Configure Docker depends upon ${element(var.wait_on, count.index)}"
  }
}

###############################################################################
# Initialize Docker Swarm
###############################################################################
resource "null_resource" "initialize_swarm" {
  connection {
    user     = "${var.ssh_username}"
    password = "${var.ssh_password}"
    host     = "${var.salt_master_ipv4_address}"
    type     = "ssh"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/swarm_init.sh"
    destination = "/tmp/swarm_init.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "set -eou pipefail",
      "chmod +x /tmp/swarm_init.sh",
      "echo Docker Count: ${length(var.ipv4_address_list)}",
      "sudo /tmp/swarm_init.sh ${var.hostname} ${length(var.ipv4_address_list)}",
      "rm /tmp/swarm_init.sh",
    ]
  }

  depends_on = [
    "null_resource.waited_on",
  ]
}

###############################################################################
# Outputs
###############################################################################
# This may seem like a strange place to expose this but I chose to do so
# because the initialize_swarm resource of this module decides which nodes
# should be assigned the manager role.  The logic for this is contained within
# the swarm_init.sh script.
output "manager_ipv4_address" {
  value = "${element(var.ipv4_address_list, 0)}"
}

output "wait_on" {
  value      = "Docker Swarm Initialized"
  depends_on = ["null_resource.initialize_swarm"]
}
