###############################################################################
# Inputs
###############################################################################
variable "instance_count" {}

variable "cost_center_id" {}
variable "base_hostname" {}
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

variable "ipv4_dns" {
  default = []
}

variable "ssh_username" {}
variable "ssh_password" {}
variable "linux_distribution" {}
variable "timeout" {}

variable "wait_on" {
  default = []
}

###############################################################################
# Force Inter-Module Dependency
###############################################################################
resource "null_resource" "waited_on" {
  count = "${length(var.wait_on)}"

  provisioner "local-exec" {
    command = "echo Dependency Resolved: Salt Master depends upon ${element(var.wait_on, count.index)}"
  }
}

###############################################################################
# Provision Salt Master
###############################################################################
resource "vsphere_virtual_machine" "build_server" {
  count    = "${var.instance_count}"
  tags     = ["${var.cost_center_id}"]
  name     = "${format("${var.base_hostname}-%02d", count.index+1)}"
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
    label            = "${format("${var.base_hostname}-%02d", count.index+1)}.vmdk"
    size             = "${var.disk_size}"
    eagerly_scrub    = "${var.disk_eagerly_scrub}"
    thin_provisioned = "${var.disk_thin_provisioned}"
  }

  clone {
    template_uuid = "${var.template_uuid}"
    timeout       = "${var.timeout}"

    customize {
      linux_options {
        host_name = "${format("${var.base_hostname}-%02d", count.index+1)}"
        domain    = "${var.domain}"
      }

      network_interface {
        ipv4_address = "${var.ipv4_subnet}.${var.ipv4_host + count.index + 1}"
        ipv4_netmask = "${var.ipv4_netmask}"
      }

      ipv4_gateway    = "${var.ipv4_gateway}"
      dns_server_list = "${var.ipv4_dns}"
    }
  }

  depends_on = [
    "null_resource.waited_on",
  ]
}

###############################################################################
# Migrate Top File
###############################################################################
module "migrate_top" {
  source = "git::ssh://git@gitlab.com/iac-example/example-iac-salt.git//migrate_top"

  salt_master_ip4v_address_list = "${vsphere_virtual_machine.build_server.*.clone.0.customize.0.network_interface.0.ipv4_address}"
  salt_master_ssh_username      = "${var.ssh_username}"
  salt_master_ssh_password      = "${var.ssh_password}"
}

###############################################################################
# Migrate State Files
###############################################################################
module "migrate_all_state_files" {
  source = "git::ssh://git@gitlab.com/iac-example/example-iac-salt.git//migrate_all_state_files"

  salt_master_ip4v_address_list = "${vsphere_virtual_machine.build_server.*.clone.0.customize.0.network_interface.0.ipv4_address}"
  salt_master_ssh_username      = "${var.ssh_username}"
  salt_master_ssh_password      = "${var.ssh_password}"
  linux_distribution            = "${var.linux_distribution}"
}

###############################################################################
# Configure Salt Master and Minion
###############################################################################
resource "null_resource" "configure_salt" {
  count = "${var.instance_count}"

  connection {
    user     = "${var.ssh_username}"
    password = "${var.ssh_password}"
    host     = "${element(vsphere_virtual_machine.build_server.*.clone.0.customize.0.network_interface.0.ipv4_address, count.index)}"
    type     = "ssh"
  }

  provisioner "remote-exec" {
    inline = [
      "set -eou pipefail",
      "curl -o /tmp/bootstrap-salt.sh -L https://bootstrap.saltstack.com",
      "chmod +x /tmp/bootstrap-salt.sh",
      "sudo /tmp/bootstrap-salt.sh -M -A 127.0.0.1",
      "rm /tmp/bootstrap-salt.sh",
    ]
  }

  depends_on = [
    "module.migrate_all_state_files",
  ]
}

###############################################################################
# Outputs
###############################################################################
output "ipv4_max_host" {
  value = "${var.ipv4_host + var.instance_count}"
}

output "ipv4_address_list" {
  value = "${vsphere_virtual_machine.build_server.*.clone.0.customize.0.network_interface.0.ipv4_address}"
}

output "ipv4_host_list" {
  value = "${split(",", replace(join(",", vsphere_virtual_machine.build_server.*.clone.0.customize.0.network_interface.0.ipv4_address), "${var.ipv4_subnet}.", ""))}"
}

output "hostname_list" {
  value = "${vsphere_virtual_machine.build_server.*.name}"
}

output "wait_on" {
  value      = "Salt Master Servers Successfully Provisioned"
  depends_on = ["null_resource.configure_salt"]
}
