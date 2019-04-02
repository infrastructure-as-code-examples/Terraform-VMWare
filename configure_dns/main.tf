###############################################################################
# Inputs
###############################################################################
variable "ipv4_address_list" {
  default = []
}

variable "reverse_ipv4_subnet" {}
variable "domain" {}
variable "ssh_username" {}
variable "ssh_password" {}
variable "ipv4_subnet" {}

variable "hostname_list" {
  default = []
}

variable "ipv4_host_list" {
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
    command = "echo Dependency Resolved: Configure DNS depends upon ${element(var.wait_on, count.index)}"
  }
}

###############################################################################
# Register Hosts - Part 1
###############################################################################
resource "null_resource" "register_hosts_part1" {
  count = "${length(var.ipv4_address_list) * length(var.ipv4_host_list)}"

  connection {
    user     = "${var.ssh_username}"
    password = "${var.ssh_password}"
    host     = "${element(var.ipv4_address_list, count.index / length(var.ipv4_host_list))}"
    type     = "ssh"
  }

  provisioner "remote-exec" {
    inline = [
      "set -eou pipefail",
      "echo ${element(var.hostname_list, count.index % length(var.ipv4_host_list))} IN A ${var.ipv4_subnet}.${element(var.ipv4_host_list, count.index % length(var.ipv4_host_list))} > /tmp/fwd.${count.index % length(var.ipv4_host_list)}.tmp",
      "echo ${element(var.ipv4_host_list, count.index % length(var.ipv4_host_list))} IN PTR ${element(var.hostname_list, count.index % length(var.ipv4_host_list))}.${var.domain}. > /tmp/rev.${count.index % length(var.ipv4_host_list)}.tmp",
    ]
  }

  depends_on = [
    "null_resource.waited_on",
  ]
}

###############################################################################
# Register Hosts - Part 2
###############################################################################
resource "null_resource" "register_hosts_part2" {
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
      "sudo systemctl stop named.service",
      "sudo sh -c 'cat /tmp/fwd.*.tmp >> /var/named/fwd.${var.domain}.db'",
      "sudo sh -c 'cat /tmp/rev.*.tmp >> /var/named/${var.reverse_ipv4_subnet}.db'",
      "sudo rm /tmp/fwd.*.tmp",
      "sudo rm /tmp/rev.*.tmp",
      "sudo systemctl start named.service",
    ]
  }

  depends_on = [
    "null_resource.register_hosts_part1",
  ]
}

###############################################################################
# Outputs
###############################################################################
output "wait_on" {
  value      = "New Hosts Successfully Configured on DNS Servers"
  depends_on = ["null_resource.register_hosts_part2"]
}
