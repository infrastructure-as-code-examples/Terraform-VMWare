###############################################################################
# Inputs
###############################################################################
variable "ssh_username" {}

variable "ssh_password" {}

variable "ipv4_address_list" {
  default = []
}

variable "wait_on" {
  default = []
}

variable "disk_name" {}
variable "volume_size_GB" {}

variable "client_ipv4_address_list" {
  default = []
}

variable "client_volume_user" {}
variable "client_volume_group" {}
variable "ca_bundle_content" {}
variable "ca_bundle_filename" {}
variable "public_cert_content" {}
variable "public_cert_filename" {}
variable "private_key_content" {}
variable "private_key_filename" {}

###############################################################################
# Force Inter-Module Dependency
###############################################################################
resource "null_resource" "waited_on" {
  count = "${length(var.wait_on)}"

  provisioner "local-exec" {
    command = "echo Dependency Resolved: Configure GlusterFS depends upon ${element(var.wait_on, count.index)}"
  }
}

###############################################################################
# Create Physical Volume
###############################################################################
resource "null_resource" "create_physical_volume" {
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
      "sudo pvcreate /dev/${var.disk_name}",
    ]
  }

  depends_on = [
    "null_resource.waited_on",
  ]
}

###############################################################################
# Create Volume Group
###############################################################################
resource "null_resource" "create_volume_group" {
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
      "sudo vgcreate vg_gluster /dev/${var.disk_name}",
    ]
  }

  depends_on = [
    "null_resource.create_physical_volume",
  ]
}

###############################################################################
# Create Logical Volume
###############################################################################
resource "null_resource" "create_logical_volume" {
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
      "sudo lvcreate -L ${var.volume_size_GB}G -n brick1 vg_gluster",
    ]
  }

  depends_on = [
    "null_resource.create_volume_group",
  ]
}

###############################################################################
# Make XFS File System
###############################################################################
resource "null_resource" "maks_xfs_file_system" {
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
      "sudo mkfs.xfs /dev/vg_gluster/brick1",
    ]
  }

  depends_on = [
    "null_resource.create_logical_volume",
  ]
}

###############################################################################
# Mount Volume
###############################################################################
resource "null_resource" "mount_volume" {
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
      "sudo mkdir -p /bricks/brick1",
      "sudo mount /dev/vg_gluster/brick1 /bricks/brick1",
    ]
  }

  depends_on = [
    "null_resource.maks_xfs_file_system",
  ]
}

###############################################################################
# Update FSTAB
###############################################################################
resource "null_resource" "update_fstab" {
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
      "sudo chmod 666 /etc/fstab",
      "sudo echo /dev/vg_gluster/brick1  /bricks/brick1    xfs     defaults    0 0 >> /etc/fstab",
      "sudo echo LABEL=/work /bricks/brick1 ext3 rw, acl 14 >> /etc/fstab",
      "sudo chmod 644 /etc/fstab",
    ]
  }

  depends_on = [
    "null_resource.mount_volume",
  ]
}

###############################################################################
# Restart Service and Create Share
###############################################################################
resource "null_resource" "create_share" {
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
      "sudo systemctl restart glusterd.service",
      "sudo mkdir /bricks/brick1/brick",
    ]
  }

  depends_on = [
    "null_resource.update_fstab",
  ]
}

###############################################################################
# Setup Trusted Storage Pool
###############################################################################
resource "null_resource" "setup_trusted_storage_pool" {
  count = "${length(var.ipv4_address_list) - 1}"

  connection {
    user     = "${var.ssh_username}"
    password = "${var.ssh_password}"
    host     = "${element(var.ipv4_address_list, 0)}"
    type     = "ssh"
  }

  provisioner "remote-exec" {
    inline = [
      "set -eou pipefail",
      "sudo gluster peer probe ${element(var.ipv4_address_list, count.index + 1)}",
    ]
  }

  depends_on = [
    "null_resource.create_share",
  ]
}

###############################################################################
# Create Highly Available Volume
###############################################################################
resource "null_resource" "create_volume" {
  connection {
    user     = "${var.ssh_username}"
    password = "${var.ssh_password}"
    host     = "${element(var.ipv4_address_list, 0)}"
    type     = "ssh"
  }

  provisioner "remote-exec" {
    inline = [
      "set -eou pipefail",
      "sudo gluster volume create glustervol1 replica ${length(var.ipv4_address_list)} transport tcp ${join(":/bricks/brick1/data ", var.ipv4_address_list)}:/bricks/brick1/data",
      "sudo gluster volume start glustervol1",
    ]
  }

  depends_on = [
    "null_resource.setup_trusted_storage_pool",
  ]
}

###############################################################################
# Mount Client Volume
###############################################################################
resource "null_resource" "mount_client_volume" {
  count = "${length(var.client_ipv4_address_list)}"

  connection {
    user     = "${var.ssh_username}"
    password = "${var.ssh_password}"
    host     = "${element(var.client_ipv4_address_list, count.index)}"
    type     = "ssh"
  }

  provisioner "remote-exec" {
    inline = [
      "set -eou pipefail",
      "sudo mkdir -p /data",
      "sudo chown ${var.client_volume_user}:${var.client_volume_group} /data",
      "sudo mount -t glusterfs -o acl ${element(var.ipv4_address_list, 0)}:/glustervol1 /data/",
    ]
  }

  depends_on = [
    "null_resource.create_volume",
  ]
}

###############################################################################
# Update Client FSTAB
###############################################################################
resource "null_resource" "update_client_fstab" {
  count = "${length(var.client_ipv4_address_list)}"

  connection {
    user     = "${var.ssh_username}"
    password = "${var.ssh_password}"
    host     = "${element(var.client_ipv4_address_list, count.index)}"
    type     = "ssh"
  }

  provisioner "remote-exec" {
    inline = [
      "set -eou pipefail",
      "sudo chmod 666 /etc/fstab",
      "sudo echo ${element(var.ipv4_address_list, 0)}:/glustervol1  /data    glusterfs     defaults,_netdev    0 0 >> /etc/fstab",
      "sudo chmod 644 /etc/fstab",
    ]
  }

  depends_on = [
    "null_resource.mount_client_volume",
  ]
}

###############################################################################
# Provision Shared Files
###############################################################################
resource "null_resource" "setup_shared_files" {
  connection {
    user     = "${var.ssh_username}"
    password = "${var.ssh_password}"
    host     = "${element(var.client_ipv4_address_list, 0)}"
    type     = "ssh"
  }

  triggers {
    ca_bundle   = "${md5(var.ca_bundle_content)}"
    public_cert = "${md5(var.public_cert_content)}"
    private_key = "${md5(var.private_key_content)}"
  }

  provisioner "file" {
    content     = "${var.ca_bundle_content}"
    destination = "/tmp/${var.ca_bundle_filename}"
  }

  provisioner "file" {
    content     = "${var.public_cert_content}"
    destination = "/tmp/${var.public_cert_filename}"
  }

  provisioner "file" {
    content     = "${var.private_key_content}"
    destination = "/tmp/${var.private_key_filename}"
  }

  provisioner "remote-exec" {
    inline = [
      "set -eou pipefail",
      "sudo mkdir -p /data/share/certificates",
      "sudo mv /tmp/${var.ca_bundle_filename} /data/share/certificates/.",
      "sudo mv /tmp/${var.public_cert_filename} /data/share/certificates/.",
      "sudo mv /tmp/${var.private_key_filename} /data/share/certificates/.",
    ]
  }

  depends_on = [
    "null_resource.update_client_fstab",
  ]
}

###############################################################################
# Outputs
###############################################################################
output "wait_on" {
  value      = "GlusterFS Server and Clients Configured"
  depends_on = ["null_resource.setup_shared_files"]
}
