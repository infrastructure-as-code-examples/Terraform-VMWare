###############################################################################
# Provider Configuration
###############################################################################
provider "vsphere" {
  user           = "${var.vsphere_user}"
  password       = "${var.vsphere_password}"
  vsphere_server = "${var.vsphere_server}"

  allow_unverified_ssl = true
}

###############################################################################
# State Storage
###############################################################################
terraform {
  backend "s3" {}
}

###############################################################################
# Retrieve Information from VSphere for Use in Build and Configuration
###############################################################################
module "initialize_datasources" {
  source = "./initialize_datasources"

  datacenter_name             = "${var.datacenter}"
  cluster_name                = "${var.cluster_name}"
  datastore_cluster_name      = "${var.datastore_cluster_name}"
  datastore_name1             = "${var.datastore_name1}"
  datastore_name2             = "${var.datastore_name2}"
  network_name                = "${var.network}"
  template_name               = "${var.template}"
  windows_template_name       = "${var.windows_template}"
  cost_center_tag_name        = "${var.cost_center_tag_name}"
  cost_center_tag_description = "${var.cost_center_tag_description}"
  cost_center_name            = "${var.cost_center_name}"
  cost_center_description     = "${var.cost_center_description}"
}

###############################################################################
# Provision DNS Servers and Install DNS and Configure DNS Services
###############################################################################
module "provision_dns" {
  source = "./provision_dns"

  instance_count        = "${var.dns_instance_count}"
  cost_center_id        = "${module.initialize_datasources.cost_center_id}"
  hostname              = "${var.dns_base_hostname}"
  domain                = "${var.domain}"
  num_cpus              = "${var.dns_num_cpus}"
  memory                = "${var.dns_memory}"
  resource_pool_id      = "${module.initialize_datasources.resource_pool_id}"
  datastore_cluster_id  = "${module.initialize_datasources.datastore_cluster_id}"
  datastore_list        = "${list(module.initialize_datasources.datastore_id1, module.initialize_datasources.datastore_id2)}"
  guest_id              = "${module.initialize_datasources.guest_id}"
  scsi_type             = "${module.initialize_datasources.scsi_type}"
  network_id            = "${module.initialize_datasources.network_id}"
  network_adapter_type  = "${module.initialize_datasources.network_adapter_type}"
  disk_size             = "${module.initialize_datasources.disk_size}"
  disk_eagerly_scrub    = "${module.initialize_datasources.disk_eagerly_scrub}"
  disk_thin_provisioned = "${module.initialize_datasources.disk_thin_provisioned}"
  template_uuid         = "${module.initialize_datasources.template_uuid}"
  ipv4_subnet           = "${var.ipv4_subnet}"
  ipv4_host             = "${var.ipv4_max_host}"
  ipv4_netmask          = "${var.ipv4_netmask}"
  ipv4_gateway          = "${var.ipv4_gateway}"
  ssh_username          = "${var.ssh_username}"
  ssh_password          = "${var.ssh_password}"
  timeout               = "${var.dns_timeout}"
  reverse_ipv4_subnet   = "${var.reverse_ipv4_subnet}"

  #----------------------------------------------------------------------------
  # The following variable is needed until the
  # vsphere_virtual_machine/clone/customize/dns_server_list field is changed
  # to accept computed values.  It is being passed in to allow downstream
  # modules to reference this module's ipv4_address_list output variable.  This
  # will prevent them from being impacted once this variable is no longer needed.
  #----------------------------------------------------------------------------
  ipv4_address_list = "${var.ipv4_dns}"
}

###############################################################################
# Register DNS Hosts with DNS
###############################################################################
module "configure_dns_hosts" {
  source = "./configure_dns"

  ipv4_address_list   = "${var.ipv4_dns}"
  reverse_ipv4_subnet = "${var.reverse_ipv4_subnet}"
  domain              = "${var.domain}"
  ssh_username        = "${var.ssh_username}"
  ssh_password        = "${var.ssh_password}"
  ipv4_subnet         = "${var.ipv4_subnet}"
  hostname_list       = "${module.provision_dns.hostname_list}"
  ipv4_host_list      = "${module.provision_dns.ipv4_host_list}"

  wait_on = [
    "${module.provision_dns.wait_on}",
  ]
}

###############################################################################
# Provision Salt Servers and Install SaltStack Master and Minion Services
###############################################################################
module "provision_salt_master" {
  source = "./provision_salt_master"

  instance_count        = "${var.salt_instance_count}"
  cost_center_id        = "${module.initialize_datasources.cost_center_id}"
  base_hostname         = "${var.salt_master_base_hostname}"
  domain                = "${var.domain}"
  num_cpus              = "${var.salt_num_cpus}"
  memory                = "${var.salt_memory}"
  resource_pool_id      = "${module.initialize_datasources.resource_pool_id}"
  datastore_cluster_id  = "${module.initialize_datasources.datastore_cluster_id}"
  datastore_list        = "${list(module.initialize_datasources.datastore_id1, module.initialize_datasources.datastore_id2)}"
  guest_id              = "${module.initialize_datasources.guest_id}"
  scsi_type             = "${module.initialize_datasources.scsi_type}"
  network_id            = "${module.initialize_datasources.network_id}"
  network_adapter_type  = "${module.initialize_datasources.network_adapter_type}"
  disk_size             = "${module.initialize_datasources.disk_size}"
  disk_eagerly_scrub    = "${module.initialize_datasources.disk_eagerly_scrub}"
  disk_thin_provisioned = "${module.initialize_datasources.disk_thin_provisioned}"
  template_uuid         = "${module.initialize_datasources.template_uuid}"
  ipv4_subnet           = "${var.ipv4_subnet}"
  ipv4_host             = "${module.provision_dns.ipv4_max_host}"
  ipv4_netmask          = "${var.ipv4_netmask}"
  ipv4_gateway          = "${var.ipv4_gateway}"
  ipv4_dns              = "${var.ipv4_dns}"
  ssh_username          = "${var.ssh_username}"
  ssh_password          = "${var.ssh_password}"
  linux_distribution    = "${var.linux_distribution}"
  timeout               = "${var.salt_timeout}"

  wait_on = [
    "${module.configure_dns_hosts.wait_on}",
  ]
}

###############################################################################
# Provision Docker Servers and Install SaltStack Minion Services
###############################################################################
module "provision_docker" {
  source = "./provision_linux_cluster"

  role                     = "docker"
  instance_count           = "${var.docker_instance_count}"
  cost_center_id           = "${module.initialize_datasources.cost_center_id}"
  base_hostname            = "${var.docker_base_hostname}"
  domain                   = "${var.domain}"
  num_cpus                 = "${var.docker_num_cpus}"
  memory                   = "${var.docker_memory}"
  resource_pool_id         = "${module.initialize_datasources.resource_pool_id}"
  datastore_cluster_id     = "${module.initialize_datasources.datastore_cluster_id}"
  datastore_list           = "${list(module.initialize_datasources.datastore_id1, module.initialize_datasources.datastore_id2)}"
  guest_id                 = "${module.initialize_datasources.guest_id}"
  scsi_type                = "${module.initialize_datasources.scsi_type}"
  network_id               = "${module.initialize_datasources.network_id}"
  network_adapter_type     = "${module.initialize_datasources.network_adapter_type}"
  disk_size                = "${module.initialize_datasources.disk_size}"
  disk_eagerly_scrub       = "${module.initialize_datasources.disk_eagerly_scrub}"
  disk_thin_provisioned    = "${module.initialize_datasources.disk_thin_provisioned}"
  template_uuid            = "${module.initialize_datasources.template_uuid}"
  ipv4_subnet              = "${var.ipv4_subnet}"
  ipv4_host                = "${module.provision_salt_master.ipv4_max_host}"
  ipv4_netmask             = "${var.ipv4_netmask}"
  ipv4_gateway             = "${var.ipv4_gateway}"
  ipv4_dns                 = "${var.ipv4_dns}"
  ssh_username             = "${var.ssh_username}"
  ssh_password             = "${var.ssh_password}"
  salt_master_ipv4_address = "${module.provision_salt_master.ipv4_address_list[0]}"
  timeout                  = "${var.docker_timeout}"

  wait_on = [
    "${module.provision_salt_master.wait_on}",
  ]
}

###############################################################################
# Provision Gluster Servers and Install SaltStack Minion Services
###############################################################################
module "provision_gluster" {
  source = "./provision_gluster_cluster"

  instance_count           = "${var.gluster_instance_count}"
  cost_center_id           = "${module.initialize_datasources.cost_center_id}"
  base_hostname            = "${var.gluster_base_hostname}"
  domain                   = "${var.domain}"
  num_cpus                 = "${var.gluster_num_cpus}"
  memory                   = "${var.gluster_memory}"
  resource_pool_id         = "${module.initialize_datasources.resource_pool_id}"
  datastore_cluster_id     = "${module.initialize_datasources.datastore_cluster_id}"
  datastore_list           = "${list(module.initialize_datasources.datastore_id1, module.initialize_datasources.datastore_id2)}"
  guest_id                 = "${module.initialize_datasources.guest_id}"
  scsi_type                = "${module.initialize_datasources.scsi_type}"
  network_id               = "${module.initialize_datasources.network_id}"
  network_adapter_type     = "${module.initialize_datasources.network_adapter_type}"
  disk_size                = "${module.initialize_datasources.disk_size}"
  disk_eagerly_scrub       = "${module.initialize_datasources.disk_eagerly_scrub}"
  disk_thin_provisioned    = "${module.initialize_datasources.disk_thin_provisioned}"
  template_uuid            = "${module.initialize_datasources.template_uuid}"
  ipv4_subnet              = "${var.ipv4_subnet}"
  ipv4_host                = "${module.provision_docker.ipv4_max_host}"
  ipv4_netmask             = "${var.ipv4_netmask}"
  ipv4_gateway             = "${var.ipv4_gateway}"
  ipv4_dns                 = "${var.ipv4_dns}"
  ssh_username             = "${var.ssh_username}"
  ssh_password             = "${var.ssh_password}"
  salt_master_ipv4_address = "${module.provision_salt_master.ipv4_address_list[0]}"
  timeout                  = "${var.gluster_timeout}"
  gluster_data_volume_size = "${var.gluster_data_volume_size}"

  wait_on = [
    "${module.provision_salt_master.wait_on}",
  ]
}

###############################################################################
# Provision PostgreSQL Servers and Install SaltStack Minion Services
###############################################################################
module "provision_postgres" {
  source = "./provision_linux_cluster"

  role                     = "postgres"
  instance_count           = "${var.postgres_instance_count}"
  cost_center_id           = "${module.initialize_datasources.cost_center_id}"
  base_hostname            = "${var.postgres_base_hostname}"
  domain                   = "${var.domain}"
  num_cpus                 = "${var.postgres_num_cpus}"
  memory                   = "${var.postgres_memory}"
  resource_pool_id         = "${module.initialize_datasources.resource_pool_id}"
  datastore_cluster_id     = "${module.initialize_datasources.datastore_cluster_id}"
  datastore_list           = "${list(module.initialize_datasources.datastore_id1, module.initialize_datasources.datastore_id2)}"
  guest_id                 = "${module.initialize_datasources.guest_id}"
  scsi_type                = "${module.initialize_datasources.scsi_type}"
  network_id               = "${module.initialize_datasources.network_id}"
  network_adapter_type     = "${module.initialize_datasources.network_adapter_type}"
  disk_size                = "${module.initialize_datasources.disk_size}"
  disk_eagerly_scrub       = "${module.initialize_datasources.disk_eagerly_scrub}"
  disk_thin_provisioned    = "${module.initialize_datasources.disk_thin_provisioned}"
  template_uuid            = "${module.initialize_datasources.template_uuid}"
  ipv4_subnet              = "${var.ipv4_subnet}"
  ipv4_host                = "${module.provision_gluster.ipv4_max_host}"
  ipv4_netmask             = "${var.ipv4_netmask}"
  ipv4_gateway             = "${var.ipv4_gateway}"
  ipv4_dns                 = "${var.ipv4_dns}"
  ssh_username             = "${var.ssh_username}"
  ssh_password             = "${var.ssh_password}"
  salt_master_ipv4_address = "${module.provision_salt_master.ipv4_address_list[0]}"
  timeout                  = "${var.postgres_timeout}"

  wait_on = [
    "${module.provision_salt_master.wait_on}",
  ]
}

###############################################################################
# Provision Windows Servers and Install SaltStack Minion Services
###############################################################################
module "provision_windows" {
  source = "./provision_windows_cluster"

  instance_count           = "${var.windows_instance_count}"
  cost_center_id           = "${module.initialize_datasources.cost_center_id}"
  base_hostname            = "${var.windows_base_hostname}"
  domain                   = "${var.domain}"
  num_cpus                 = "${var.windows_num_cpus}"
  memory                   = "${var.windows_memory}"
  resource_pool_id         = "${module.initialize_datasources.resource_pool_id}"
  datastore_cluster_id     = "${module.initialize_datasources.datastore_cluster_id}"
  datastore_list           = "${list(module.initialize_datasources.datastore_id1, module.initialize_datasources.datastore_id2)}"
  guest_id                 = "${module.initialize_datasources.windows_guest_id}"
  scsi_type                = "${module.initialize_datasources.windows_scsi_type}"
  network_id               = "${module.initialize_datasources.network_id}"
  network_adapter_type     = "${module.initialize_datasources.windows_network_adapter_type}"
  disk_size                = "${module.initialize_datasources.windows_disk_size}"
  disk_eagerly_scrub       = "${module.initialize_datasources.windows_disk_eagerly_scrub}"
  disk_thin_provisioned    = "${module.initialize_datasources.windows_disk_thin_provisioned}"
  template_uuid            = "${module.initialize_datasources.windows_template_uuid}"
  ipv4_subnet              = "${var.ipv4_subnet}"
  ipv4_host                = "${module.provision_postgres.ipv4_max_host}"
  ipv4_netmask             = "${var.ipv4_netmask}"
  ipv4_gateway             = "${var.ipv4_gateway}"
  ipv4_dns                 = "${var.ipv4_dns}"
  ssh_username             = "${var.ssh_username}"
  ssh_password             = "${var.ssh_password}"
  salt_master_ipv4_address = "${module.provision_salt_master.ipv4_address_list[0]}"
  timeout                  = "${var.windows_timeout}"

  wait_on = [
    "${module.provision_salt_master.wait_on}",
  ]
}

###############################################################################
# Provision PostgreSQL Servers and Install SaltStack Minion Services
###############################################################################
module "provision_mule" {
  source = "./provision_linux_cluster"

  role                     = "mule"
  instance_count           = "${var.mule_instance_count}"
  cost_center_id           = "${module.initialize_datasources.cost_center_id}"
  base_hostname            = "${var.mule_base_hostname}"
  domain                   = "${var.domain}"
  num_cpus                 = "${var.mule_num_cpus}"
  memory                   = "${var.mule_memory}"
  resource_pool_id         = "${module.initialize_datasources.resource_pool_id}"
  datastore_cluster_id     = "${module.initialize_datasources.datastore_cluster_id}"
  datastore_list           = "${list(module.initialize_datasources.datastore_id1, module.initialize_datasources.datastore_id2)}"
  guest_id                 = "${module.initialize_datasources.guest_id}"
  scsi_type                = "${module.initialize_datasources.scsi_type}"
  network_id               = "${module.initialize_datasources.network_id}"
  network_adapter_type     = "${module.initialize_datasources.network_adapter_type}"
  disk_size                = "${module.initialize_datasources.disk_size}"
  disk_eagerly_scrub       = "${module.initialize_datasources.disk_eagerly_scrub}"
  disk_thin_provisioned    = "${module.initialize_datasources.disk_thin_provisioned}"
  template_uuid            = "${module.initialize_datasources.template_uuid}"
  ipv4_subnet              = "${var.ipv4_subnet}"
  ipv4_host                = "${module.provision_windows.ipv4_max_host}"
  ipv4_netmask             = "${var.ipv4_netmask}"
  ipv4_gateway             = "${var.ipv4_gateway}"
  ipv4_dns                 = "${var.ipv4_dns}"
  ssh_username             = "${var.ssh_username}"
  ssh_password             = "${var.ssh_password}"
  salt_master_ipv4_address = "${module.provision_salt_master.ipv4_address_list[0]}"
  timeout                  = "${var.mule_timeout}"

  wait_on = [
    "${module.provision_salt_master.wait_on}",
  ]
}

###############################################################################
# Accept SaltStack Minion Keys and Restart Salt Server Minion Services
###############################################################################
module "configure_salt_master" {
  source = "./configure_salt_master"

  salt_master_ipv4_address_list = "${module.provision_salt_master.ipv4_address_list}"
  salt_master_ssh_username      = "${var.ssh_username}"
  salt_master_ssh_password      = "${var.ssh_password}"
  salt_minion_ipv4_address_list = "${concat(module.provision_docker.ipv4_address_list, module.provision_gluster.ipv4_address_list, module.provision_postgres.ipv4_address_list)}"

  wait_on = [
    "${module.provision_docker.wait_on}",
    "${module.provision_gluster.wait_on}",
    "${module.provision_windows.wait_on}",
  ]
}

###############################################################################
# Apply Salt States for Docker Role
###############################################################################
module "apply_docker_salt_states" {
  source = "./apply_salt_states"

  role                     = "docker"
  ssh_username             = "${var.ssh_username}"
  ssh_password             = "${var.ssh_password}"
  ipv4_address_list        = "${module.provision_docker.ipv4_address_list}"
  salt_master_ipv4_address = "${module.provision_salt_master.ipv4_address_list[0]}"

  wait_on = [
    "${module.configure_salt_master.wait_on}",
  ]
}

###############################################################################
# Configure Docker Swarm
###############################################################################
module "configure_docker" {
  source = "./configure_docker"

  ssh_username             = "${var.ssh_username}"
  ssh_password             = "${var.ssh_password}"
  ipv4_address_list        = "${module.provision_docker.ipv4_address_list}"
  salt_master_ipv4_address = "${module.provision_salt_master.ipv4_address_list[0]}"
  hostname                 = "${var.docker_base_hostname}"

  wait_on = [
    "${module.apply_docker_salt_states.wait_on}",
  ]
}

###############################################################################
# Apply Salt States for GlusterFS Role
###############################################################################
module "apply_gluster_salt_states" {
  source = "./apply_salt_states"

  role                     = "gluster"
  ssh_username             = "${var.ssh_username}"
  ssh_password             = "${var.ssh_password}"
  ipv4_address_list        = "${module.provision_gluster.ipv4_address_list}"
  salt_master_ipv4_address = "${module.provision_salt_master.ipv4_address_list[0]}"

  wait_on = [
    "${module.configure_salt_master.wait_on}",
  ]
}

###############################################################################
# Create and Configure GlusterFS Shared Volume
###############################################################################
module "configure_gluster" {
  source = "./configure_gluster"

  ssh_username             = "${var.ssh_username}"
  ssh_password             = "${var.ssh_password}"
  ipv4_address_list        = "${module.provision_gluster.ipv4_address_list}"
  disk_name                = "${var.gluster_disk_name}"
  volume_size_GB           = "${var.gluster_volume_size_GB}"
  client_ipv4_address_list = "${module.provision_docker.ipv4_address_list}"
  client_volume_user       = "${var.docker_gluster_volume_user}"
  client_volume_group      = "${var.docker_gluster_volume_group}"
  ca_bundle_content        = "${var.ca_bundle_content}"
  ca_bundle_filename       = "${var.ca_bundle_filename}"
  public_cert_content      = "${var.public_cert_content}"
  public_cert_filename     = "${var.public_cert_filename}"
  private_key_content      = "${var.private_key_content}"
  private_key_filename     = "${var.private_key_filename}"

  # Docker Must be Configured to Grant Permission to Shared Volume
  wait_on = [
    "${module.apply_gluster_salt_states.wait_on}",
    "${module.configure_docker.wait_on}",
  ]
}

###############################################################################
# Apply Salt States for PostgreSQL Role
###############################################################################
module "apply_postgres_salt_states" {
  source = "./apply_salt_states"

  role                     = "postgres"
  ssh_username             = "${var.ssh_username}"
  ssh_password             = "${var.ssh_password}"
  ipv4_address_list        = "${module.provision_postgres.ipv4_address_list}"
  salt_master_ipv4_address = "${module.provision_salt_master.ipv4_address_list[0]}"

  wait_on = [
    "${module.configure_salt_master.wait_on}",
  ]
}

###############################################################################
# Configure PostgreSQL
###############################################################################
module "configure_postgres" {
  source = "./configure_postgres"

  ssh_username            = "${var.ssh_username}"
  ssh_password            = "${var.ssh_password}"
  ipv4_address_list       = "${module.provision_postgres.ipv4_address_list}"
  postgres_password       = "${var.postgres_password}"
  ipv4_cidr_ip_address    = "${var.ipv4_cidr_ip_address}"
  ipv4_cidr_prefix_length = "${var.ipv4_cidr_prefix_length}"
  ipv6_cidr_ip_address    = "${var.ipv6_cidr_ip_address}"
  ipv6_cidr_prefix_length = "${var.ipv6_cidr_prefix_length}"
  ipv4_listen_ip_address  = "${var.ipv4_listen_ip_address}"

  wait_on = [
    "${module.apply_postgres_salt_states.wait_on}",
  ]
}

###############################################################################
# Apply Salt States for Mule Role
###############################################################################
module "apply_mule_salt_states" {
  source = "./apply_salt_states"

  role                     = "mule"
  ssh_username             = "${var.ssh_username}"
  ssh_password             = "${var.ssh_password}"
  ipv4_address_list        = "${module.provision_mule.ipv4_address_list}"
  salt_master_ipv4_address = "${module.provision_salt_master.ipv4_address_list[0]}"

  wait_on = [
    "${module.configure_salt_master.wait_on}",
  ]
}

###############################################################################
# Configure Mule
###############################################################################
module "configure_mule" {
  source = "./configure_mule"

  ssh_username      = "${var.ssh_username}"
  ssh_password      = "${var.ssh_password}"
  ipv4_address_list = "${module.provision_mule.ipv4_address_list}"
  hostname_list     = "${module.provision_mule.hostname_list}"
  mule_token        = "${var.mule_token}"
  client_id         = "${var.mule_client_id}"
  client_secret     = "${var.mule_client_secret}"

  wait_on = [
    "${module.apply_mule_salt_states.wait_on}",
  ]
}

###############################################################################
# Register New Hosts with DNS
###############################################################################
module "configure_dns" {
  source = "./configure_dns"

  ipv4_address_list   = "${var.ipv4_dns}"
  reverse_ipv4_subnet = "${var.reverse_ipv4_subnet}"
  domain              = "${var.domain}"
  ssh_username        = "${var.ssh_username}"
  ssh_password        = "${var.ssh_password}"
  ipv4_subnet         = "${var.ipv4_subnet}"
  hostname_list       = "${concat(module.provision_salt_master.hostname_list, module.provision_docker.hostname_list, module.provision_gluster.hostname_list, module.provision_postgres.hostname_list, module.provision_windows.hostname_list, module.provision_mule.hostname_list)}"
  ipv4_host_list      = "${concat(module.provision_salt_master.ipv4_host_list, module.provision_docker.ipv4_host_list, module.provision_gluster.ipv4_host_list, module.provision_postgres.ipv4_host_list, module.provision_windows.ipv4_host_list, module.provision_mule.ipv4_host_list)}"
}

###############################################################################
# Provision Docker Swarm Visualizer Container
###############################################################################
module "provision_visualizer" {
  source = "./provision_visualizer"

  ssh_username                = "${var.ssh_username}"
  ssh_password                = "${var.ssh_password}"
  docker_manager_ipv4_address = "${module.configure_docker.manager_ipv4_address}"
  host_port                   = "${var.visualizer_host_port}"
  ipv4_dns                    = "${var.ipv4_dns}"

  wait_on = [
    "${module.configure_docker.wait_on}",
  ]
}

###############################################################################
# Provision Gitlab Community Edition Container
###############################################################################
module "provision_gitlab" {
  source = "./provision_gitlab"

  ssh_username                = "${var.ssh_username}"
  ssh_password                = "${var.ssh_password}"
  docker_manager_ipv4_address = "${module.configure_docker.manager_ipv4_address}"
  ipv4_dns                    = "${var.ipv4_dns}"
  database_name               = "${var.gitlab_database_name}"
  database_host_port          = "${var.gitlab_database_host_port}"
  database_user               = "${var.gitlab_database_user}"
  database_host_volume        = "${var.gitlab_database_host_volume}"
  external_url                = "${var.gitlab_external_url}"
  ssl_certificate             = "${var.gitlab_ssl_certificate}"
  ssl_certificate_key         = "${var.gitlab_ssl_certificate_key}"
  database_hostname           = "${var.gitlab_database_hostname}"
  database_password           = "${var.gitlab_database_password}"
  root_password               = "${var.gitlab_root_password}"
  https_port                  = "${var.gitlab_https_port}"
  http_port                   = "${var.gitlab_http_port}"
  ssh_port                    = "${var.gitlab_ssh_port}"
  config_host_volume          = "${var.gitlab_config_host_volume}"
  logs_host_volume            = "${var.gitlab_logs_host_volume}"
  data_host_volume            = "${var.gitlab_data_host_volume}"
  certificate_host_volume     = "${var.certificate_host_volume}"
  smtp_address                = "${var.gitlab_smtp_address}"
  smtp_port                   = "${var.gitlab_smtp_port}"
  smtp_user_name              = "${var.gitlab_smtp_user_name}"
  smtp_password               = "${var.gitlab_smtp_password}"
  smtp_domain                 = "${var.gitlab_smtp_domain}"

  wait_on = [
    "${module.configure_docker.wait_on}",
    "${module.configure_gluster.wait_on}",
  ]
}
