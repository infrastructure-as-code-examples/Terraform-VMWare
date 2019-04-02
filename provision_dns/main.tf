###############################################################################
# Inputs
###############################################################################
variable "instance_count" {}

variable "cost_center_id" {}
variable "hostname" {}
variable "domain" {}
variable "num_cpus" {}
variable "memory" {}
variable "resource_pool_id" {}

variable "datastore_cluster_id" {}

variable "datastore_list" {
  default = []
}

variable "guest_id" {}
variable "scsi_type" {}
variable "network_id" {}
variable "network_adapter_type" {}
variable "disk_size" {}
variable "disk_eagerly_scrub" {}
variable "disk_thin_provisioned" {}
variable "template_uuid" {}
variable "ipv4_subnet" {}
variable "ipv4_host" {}
variable "ipv4_netmask" {}
variable "ipv4_gateway" {}
variable "ssh_username" {}
variable "ssh_password" {}
variable "timeout" {}
variable "reverse_ipv4_subnet" {}

#------------------------------------------------------------------------------
# The following variable is needed until the
# vsphere_virtual_machine/clone/customize/dns_server_list field is changed
# to accept computed values.  It is being passed in to allow downstream
# modules to reference this module's ipv4_address_list output variable.  This
# will prevent them from being impacted once this variable is no longer needed.
#------------------------------------------------------------------------------
variable "ipv4_address_list" {
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
    command = "echo Dependency Resolved: DNS depends upon ${element(var.wait_on, count.index)}"
  }
}

###############################################################################
# Provision DNS Server
###############################################################################
resource "vsphere_virtual_machine" "build_server" {
  count    = "${var.instance_count}"
  tags     = ["${var.cost_center_id}"]
  name     = "${format("${var.hostname}-%02d", count.index+1)}"
  num_cpus = "${var.num_cpus}"
  memory   = "${var.memory}"

  resource_pool_id = "${var.resource_pool_id}"

  # datastore_cluster_id = "${var.datastore_cluster_id}"
  datastore_id = "${element(var.datastore_list, count.index % length(var.datastore_list))}"
  guest_id     = "${var.guest_id}"
  scsi_type    = "${var.scsi_type}"

  network_interface {
    network_id   = "${var.network_id}"
    adapter_type = "${var.network_adapter_type}"
  }

  disk {
    label            = "${format("${var.hostname}-%02d", count.index+1)}.vmdk"
    size             = "${var.disk_size}"
    eagerly_scrub    = "${var.disk_eagerly_scrub}"
    thin_provisioned = "${var.disk_thin_provisioned}"
  }

  clone {
    template_uuid = "${var.template_uuid}"
    timeout       = "${var.timeout}"

    customize {
      linux_options {
        host_name = "${format("${var.hostname}-%02d", count.index+1)}"
        domain    = "${var.domain}"
      }

      network_interface {
        ipv4_address = "${var.ipv4_subnet}.${var.ipv4_host + count.index + 1}"
        ipv4_netmask = "${var.ipv4_netmask}"
      }

      ipv4_gateway = "${var.ipv4_gateway}"

      dns_server_list = [
        "${var.ipv4_gateway}",
      ]
    }
  }

  depends_on = [
    "null_resource.waited_on",
  ]
}

###############################################################################
# Install DNS Server
###############################################################################
resource "null_resource" "install_dns" {
  count = "${var.instance_count}"

  connection {
    user     = "${var.ssh_username}"
    password = "${var.ssh_password}"
    host     = "${element(vsphere_virtual_machine.build_server.*.clone.0.customize.0.network_interface.0.ipv4_address, count.index)}"
    type     = "ssh"
  }

  provisioner "salt-masterless" {
    local_state_tree  = "${path.module}/config/salt/master"
    remote_state_tree = "/srv/salt"
  }
}

###############################################################################
# Configure DNS Server
###############################################################################
resource "null_resource" "configure_server" {
  count = "${var.instance_count}"

  connection {
    user     = "${var.ssh_username}"
    password = "${var.ssh_password}"
    host     = "${element(vsphere_virtual_machine.build_server.*.clone.0.customize.0.network_interface.0.ipv4_address, count.index)}"
    type     = "ssh"
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/prep_named_conf.sh ${path.module} ${var.domain} ${var.reverse_ipv4_subnet} ${var.ipv4_subnet} ${var.ipv4_netmask}"
  }

  provisioner "file" {
    source      = "${path.module}/config/bind/named.conf"
    destination = "/tmp/named.conf"
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/prep_zone_files.sh ${path.module} ${var.domain} ${var.reverse_ipv4_subnet} ${var.ipv4_host + count.index + 1} ${element(vsphere_virtual_machine.build_server.*.clone.0.customize.0.network_interface.0.ipv4_address, count.index)} ${element(vsphere_virtual_machine.build_server.*.name, count.index)}.${var.domain} fwd.${var.domain}.db ${var.reverse_ipv4_subnet}.db"
  }

  provisioner "file" {
    source      = "${path.module}/config/bind/fwd.${var.domain}.db"
    destination = "/tmp/fwd.${var.domain}.db"
  }

  provisioner "file" {
    source      = "${path.module}/config/bind/${var.reverse_ipv4_subnet}.db"
    destination = "/tmp/${var.reverse_ipv4_subnet}.db"
  }

  provisioner "remote-exec" {
    inline = [
      "set -eou pipefail",
      "sudo chown root:named /tmp/named.conf",
      "sudo chown root:named /tmp/*.db",
      "sudo chmod 640 /tmp/named.conf",
      "sudo chmod 640 /tmp/*.db",
      "sudo rm -rf /etc/named.conf",
      "sudo mv /tmp/named.conf /etc/named.conf",
      "sudo mv /tmp/fwd.${var.domain}.db /var/named/fwd.${var.domain}.db",
      "sudo mv /tmp/${var.reverse_ipv4_subnet}.db /var/named/${var.reverse_ipv4_subnet}.db",
    ]
  }

  depends_on = [
    "null_resource.install_dns",
  ]
}

###############################################################################
# Outputs
###############################################################################
output "ipv4_max_host" {
  value = "${var.ipv4_host + var.instance_count}"
}

# The VMware Virtual Machine Resource Doesn't Support Computed Values for dns_server_list.
# output "ipv4_address_list" {
#   value = "${vsphere_virtual_machine.build_server.*.clone.0.customize.0.network_interface.0.ipv4_address}"
# }

output "ipv4_address_list" {
  value = "${var.ipv4_address_list}"
}

output "ipv4_host_list" {
  value = "${split(",", replace(join(",", vsphere_virtual_machine.build_server.*.clone.0.customize.0.network_interface.0.ipv4_address), "${var.ipv4_subnet}.", ""))}"
}

output "hostname_list" {
  value = "${vsphere_virtual_machine.build_server.*.name}"
}

output "wait_on" {
  value      = "DNS Servers Successfully Provisioned"
  depends_on = ["null_resource.configure_server"]
}
