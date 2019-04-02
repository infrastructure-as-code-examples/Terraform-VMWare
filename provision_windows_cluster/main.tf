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
variable "salt_master_ipv4_address" {}
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
    command = "echo Dependency Resolved: Windows depends upon ${element(var.wait_on, count.index)}"
  }
}

###############################################################################
# Provision Windows Master
###############################################################################
resource "vsphere_virtual_machine" "build_server" {
  count    = "${var.instance_count}"
  tags     = ["${var.cost_center_id}"]
  name     = "${format("${var.base_hostname}-%02d", count.index+1)}"
  num_cpus = "${var.num_cpus}"
  memory   = "${var.memory}"

  connection {
    host     = "${var.ipv4_subnet}.${var.ipv4_host + count.index + 1}"
    type     = "ssh"
    user     = "${var.ssh_username}"
    password = "${var.ssh_password}"
  }

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
      windows_options {
        computer_name = "${format("${var.base_hostname}-%02d", count.index+1)}"
      }

      network_interface {
        ipv4_address    = "${var.ipv4_subnet}.${var.ipv4_host + count.index + 1}"
        ipv4_netmask    = "${var.ipv4_netmask}"
        dns_domain      = "${var.domain}"
        dns_server_list = "${var.ipv4_dns}"
      }

      ipv4_gateway = "${var.ipv4_gateway}"
    }
  }

  # provisioner "remote-exec" {
  #   inline = [
  #     "powershell -Command \"(New-Object System.Net.WebClient).DownloadFile('https://repo.saltstack.com/windows/Salt-Minion-2017.7.4-Py3-AMD64-Setup.exe', 'C:/Windows/Temp/salt.exe')\" <NUL",
  #     "powershell -Command \"(New-Object System.Net.WebClient).DownloadFile('https://repo.saltstack.com/windows/Salt-Minion-2017.7.4-Py3-AMD64-Setup.exe.md5', 'C:/Windows/Temp/salt.md5')\" <NUL",
  #     "cd C:/Windows/Temp",
  #     "for /f \"tokens=1 delims= \" %%a in ('md5sum salt.exe') do ( set filemd5=%%a",
  #     "for /f \"tokens=1 delims= \" %%a in ('type salt.md5') do ( set md5=%%a",
  #     "if /i %filemd5% NEQ %md5% ( exit /b 1 )",
  #   ]
  # }

  depends_on = [
    "null_resource.waited_on",
  ]
}

###############################################################################
# Outputs
###############################################################################
output "ipv4_max_host" {
  value = "${var.ipv4_host + var.instance_count}"
}

output "ipv4_address" {
  value = "${vsphere_virtual_machine.build_server.*.clone.0.customize.0.network_interface.0.ipv4_address}"
}

output "ipv4_host_list" {
  value = "${split(",", replace(join(",", vsphere_virtual_machine.build_server.*.clone.0.customize.0.network_interface.0.ipv4_address), "${var.ipv4_subnet}.", ""))}"
}

output "hostname_list" {
  value = "${vsphere_virtual_machine.build_server.*.name}"
}

output "wait_on" {
  value      = "Windows Servers Successfully Provisioned"
  depends_on = ["vsphere_virtual_machine.build_server"]
}
