###############################################################################
# Inputs
###############################################################################
variable "datacenter_name" {}

variable "cluster_name" {}
variable "datastore_cluster_name" {}

variable "datastore_name1" {}

variable "datastore_name2" {}

variable "network_name" {}
variable "template_name" {}
variable "windows_template_name" {}
variable "cost_center_tag_name" {}
variable "cost_center_tag_description" {}
variable "cost_center_name" {}
variable "cost_center_description" {}

###############################################################################
# Data Source Configurations
###############################################################################
data "vsphere_datacenter" "datacenter" {
  name = "${var.datacenter_name}"
}

data "vsphere_compute_cluster" "cluster" {
  name          = "${var.cluster_name}"
  datacenter_id = "${data.vsphere_datacenter.datacenter.id}"
}

data "vsphere_datastore_cluster" "datastore_cluster" {
  name          = "${var.datastore_cluster_name}"
  datacenter_id = "${data.vsphere_datacenter.datacenter.id}"
}

data "vsphere_datastore" "datastore1" {
  name          = "${var.datastore_name1}"
  datacenter_id = "${data.vsphere_datacenter.datacenter.id}"
}

data "vsphere_datastore" "datastore2" {
  name          = "${var.datastore_name2}"
  datacenter_id = "${data.vsphere_datacenter.datacenter.id}"
}

data "vsphere_network" "network" {
  name          = "${var.network_name}"
  datacenter_id = "${data.vsphere_datacenter.datacenter.id}"
}

data "vsphere_virtual_machine" "template" {
  name          = "${var.template_name}"
  datacenter_id = "${data.vsphere_datacenter.datacenter.id}"
}

data "vsphere_virtual_machine" "windows_template" {
  name          = "${var.windows_template_name}"
  datacenter_id = "${data.vsphere_datacenter.datacenter.id}"
}

resource "vsphere_tag_category" "cost_center" {
  name        = "${var.cost_center_tag_name}"
  cardinality = "SINGLE"
  description = "${var.cost_center_tag_description}"

  associable_types = [
    "VirtualMachine",
  ]
}

resource "vsphere_tag" "cost_center" {
  name        = "${var.cost_center_name}"
  category_id = "${vsphere_tag_category.cost_center.id}"
  description = "${var.cost_center_description}"
}

# data "vsphere_tag_category" "cost_center" {
#   name = "${var.cost_center_tag_name}"
# }

# data "vsphere_tag" "cost_center" {
#   name        = "${var.cost_center_name}"
#   category_id = "${data.vsphere_tag_category.cost_center.id}"
# }

###############################################################################
# Outputs
# ###############################################################################
# output "cost_center_id" {
#   value = "${data.vsphere_tag.cost_center.id}"
# }

output "cost_center_id" {
  value = "${vsphere_tag.cost_center.id}"
}

output "resource_pool_id" {
  value = "${data.vsphere_compute_cluster.cluster.resource_pool_id}"
}

output "datastore_cluster_id" {
  value = "${data.vsphere_datastore_cluster.datastore_cluster.id}"
}

output "datastore_id1" {
  value = "${data.vsphere_datastore.datastore1.id}"
}

output "datastore_id2" {
  value = "${data.vsphere_datastore.datastore2.id}"
}

# CentOS Template Information

output "guest_id" {
  value = "${data.vsphere_virtual_machine.template.guest_id}"
}

output "scsi_type" {
  value = "${data.vsphere_virtual_machine.template.scsi_type}"
}

output "network_id" {
  value = "${data.vsphere_network.network.id}"
}

output "network_adapter_type" {
  value = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
}

output "disk_size" {
  value = "${data.vsphere_virtual_machine.template.disks.0.size}"
}

output "disk_eagerly_scrub" {
  value = "${data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
}

output "disk_thin_provisioned" {
  value = "${data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
}

output "template_uuid" {
  value = "${data.vsphere_virtual_machine.template.id}"
}

# Windows Template Information

output "windows_guest_id" {
  value = "${data.vsphere_virtual_machine.windows_template.guest_id}"
}

output "windows_scsi_type" {
  value = "${data.vsphere_virtual_machine.windows_template.scsi_type}"
}

output "windows_network_adapter_type" {
  value = "${data.vsphere_virtual_machine.windows_template.network_interface_types[0]}"
}

output "windows_disk_size" {
  value = "${data.vsphere_virtual_machine.windows_template.disks.0.size}"
}

output "windows_disk_eagerly_scrub" {
  value = "${data.vsphere_virtual_machine.windows_template.disks.0.eagerly_scrub}"
}

output "windows_disk_thin_provisioned" {
  value = "${data.vsphere_virtual_machine.windows_template.disks.0.thin_provisioned}"
}

output "windows_template_uuid" {
  value = "${data.vsphere_virtual_machine.windows_template.id}"
}
