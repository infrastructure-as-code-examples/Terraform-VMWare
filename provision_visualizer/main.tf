###############################################################################
# Inputs
###############################################################################
variable "ssh_username" {}

variable "ssh_password" {}
variable "docker_manager_ipv4_address" {}
variable "host_port" {}

variable "ipv4_dns" {
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
    command = "echo Dependency Resolved: Visualizer Container depends upon ${element(var.wait_on, count.index)}"
  }
}

###############################################################################
# Provision Docker Swarm Visualizer Container
###############################################################################
resource "null_resource" "run_visualizer" {
  connection {
    user     = "${var.ssh_username}"
    password = "${var.ssh_password}"
    host     = "${var.docker_manager_ipv4_address}"
    type     = "ssh"
  }

  triggers {
    compose_file = "${md5(file("${path.module}/visualizer.yml"))}"
    host_port    = "${md5(var.host_port)}"
    ipv4_dns     = "${md5(element(var.ipv4_dns, 0))}"
  }

  provisioner "file" {
    source      = "${path.module}/visualizer.yml"
    destination = "/tmp/visualizer.yml"
  }

  provisioner "remote-exec" {
    inline = [
      "set -eou pipefail",
      "cd /tmp",
      "export HOST_PORT=${var.host_port}",
      "export DNS_SERVER=${element(var.ipv4_dns, 0)}",
      "sudo -E docker stack deploy --compose-file visualizer.yml VIZ",
      "rm visualizer.yml",
    ]
  }

  depends_on = [
    "null_resource.waited_on",
  ]
}
