# Find the public image to be used for deployment. You can indicate image by either
# image family or image name. By default, the Fortinet's public project and newest
# 72 PAYG image is used.
data "google_compute_image" "fgt_image" {
  project         = var.image_project
  family          = var.image_name == "" ? var.image_family : null
  name            = var.image_name != "" ? var.image_name : null
}


# Pull information about subnets we will connect to FortiGate instances. Subnets must
# already exist (can be created in parent module).
data "google_compute_subnetwork" "subnets" {
  count           = length(var.subnets)
  name            = var.subnets[count.index]
  region          = var.region
}

# Pull default zones and the service account. Both can be overridden in variables if needed.
data "google_compute_zones" "zones_in_region" {
  region          = var.region
}

data "google_compute_default_service_account" "default" {
}

locals {
  zones = [
    var.zones[0]  != "" ? var.zones[0] : data.google_compute_zones.zones_in_region.names[0],
    var.zones[1]  != "" ? var.zones[1] : data.google_compute_zones.zones_in_region.names[1]
  ]
}

# We'll use shortened region and zone names for some resource names. This is a standard shortening described in
# GCP security foundations.
locals {
  region_short    = replace( replace( replace( replace(var.region, "europe-", "eu"), "australia", "au" ), "northamerica", "na"), "southamerica", "sa")
  zones_short     = [
    replace( replace( replace( replace(local.zones[0], "europe-", "eu"), "australia", "au" ), "northamerica", "na"), "southamerica", "sa"),
    replace( replace( replace( replace(local.zones[1], "europe-", "eu"), "australia", "au" ), "northamerica", "na"), "southamerica", "sa")
  ]
}

# Create new random API key to be provisioned in FortiGates.
resource "random_string" "api_key" {
  length                 = 30
  special                = false
  numeric                = true
}

# Create FortiGate instances with secondary logdisks and configuration. Everything 2 times (active + passive)
resource "google_compute_disk" "logdisk" {
  count                  = 2

  name                   = "${var.prefix}disk-logdisk${count.index+1}-${local.zones_short[count.index]}"
  size                   = var.logdisk_size
  type                   = "pd-ssd"
  zone                   = local.zones[count.index]
  labels                 = var.labels
}



locals {
  config_active          = templatefile("${path.module}/fgt-base-config-custom.tpl", {
    hostname               = "${var.prefix}vm-${local.zones_short[0]}"
    unicast_peer_ip        = google_compute_address.hasync_priv[1].address
    unicast_peer_netmask   = cidrnetmask(data.google_compute_subnetwork.subnets[2].ip_cidr_range)
    ha_prio                = 1
    healthcheck_port       = var.healthcheck_port
    ext_ip                 = google_compute_address.ext_priv[0].address
    ext_gw                 = data.google_compute_subnetwork.subnets[0].gateway_address
    int_ip                 = google_compute_address.int_priv[0].address
    int_gw                 = data.google_compute_subnetwork.subnets[1].gateway_address
    int_cidr               = data.google_compute_subnetwork.subnets[1].ip_cidr_range
    hasync_ip              = google_compute_address.hasync_priv[0].address
    mgmt_ip                = google_compute_address.mgmt_priv[0].address
    mgmt_gw                = data.google_compute_subnetwork.subnets[3].gateway_address
    ilb_ip                 = google_compute_address.ilb.address
    frontend_eips          = {
      "obs":   google_compute_address.ic_ilb_obs.address,
      "atman": google_compute_address.ic_ilb_atman.address }
    fgt_config             = var.fgt_config
  })

  config_passive         = templatefile("${path.module}/fgt-base-config-custom.tpl", {
    hostname               = "${var.prefix}vm-${local.zones_short[1]}"
    unicast_peer_ip        = google_compute_address.hasync_priv[0].address
    unicast_peer_netmask   = cidrnetmask(data.google_compute_subnetwork.subnets[2].ip_cidr_range)
    ha_prio                = 0
    healthcheck_port       = var.healthcheck_port
    ext_ip                 = google_compute_address.ext_priv[1].address
    ext_gw                 = data.google_compute_subnetwork.subnets[0].gateway_address
    int_ip                 = google_compute_address.int_priv[1].address
    int_gw                 = data.google_compute_subnetwork.subnets[1].gateway_address
    int_cidr               = data.google_compute_subnetwork.subnets[1].ip_cidr_range
    hasync_ip              = google_compute_address.hasync_priv[1].address
    mgmt_ip                = google_compute_address.mgmt_priv[1].address
    mgmt_gw                = data.google_compute_subnetwork.subnets[3].gateway_address
    ilb_ip                 = google_compute_address.ilb.address
    frontend_eips          = {
      "obs":   google_compute_address.ic_ilb_obs.address,
      "atman": google_compute_address.ic_ilb_atman.address }
    fgt_config             = var.fgt_config
  })

}

resource "google_compute_instance" "fgt-vm" {
  count                  = 2

  zone                   = local.zones[count.index]
  name                   = "${var.prefix}vm${count.index+1}-${local.zones_short[count.index]}"
  machine_type           = var.machine_type
  can_ip_forward         = true
  tags                   = ["fgt"]
  labels                 = var.labels

  boot_disk {
    initialize_params {
      image              = data.google_compute_image.fgt_image.self_link
      labels             = var.labels
    }
  }
  attached_disk {
    source               = google_compute_disk.logdisk[count.index].name
  }

  service_account {
    email                = (var.service_account != "" ? var.service_account : data.google_compute_default_service_account.default.email)
    scopes               = ["cloud-platform"]
  }

  metadata = {
    user-data            = (count.index == 0 ? local.config_active : local.config_passive )
    license              = fileexists(var.license_files[count.index]) ? file(var.license_files[count.index]) : null
    serial-port-enable   = true
  }

  network_interface {
    subnetwork           = data.google_compute_subnetwork.subnets[0].id
    network_ip           = google_compute_address.ext_priv[count.index].address
  }
  network_interface {
    subnetwork           = data.google_compute_subnetwork.subnets[1].id
    network_ip           = google_compute_address.int_priv[count.index].address
  }
  network_interface {
    subnetwork           = data.google_compute_subnetwork.subnets[2].id
    network_ip           = google_compute_address.hasync_priv[count.index].address
  }
  network_interface {
    subnetwork           = data.google_compute_subnetwork.subnets[3].id
    network_ip           = google_compute_address.mgmt_priv[count.index].address
    access_config {
      nat_ip             = google_compute_address.mgmt_pub[count.index].address
    }
  }
} //fgt-vm


# Common Load Balancer resources
resource "google_compute_region_health_check" "health_check" {
  name                   = "${var.prefix}healthcheck-http${var.healthcheck_port}-${local.region_short}"
  region                 = var.region
  timeout_sec            = 2
  check_interval_sec     = 2

  http_health_check {
    port                 = var.healthcheck_port
  }
}

resource "google_compute_instance_group" "fgt-umigs" {
  count                  = 2

  name                   = "${var.prefix}umig${count.index}-${local.zones_short[count.index]}"
  zone                   = google_compute_instance.fgt-vm[count.index].zone
  instances              = [google_compute_instance.fgt-vm[count.index].self_link]
}

# Resources building Internal Load Balancer
resource "google_compute_region_backend_service" "ilb_bes" {
  provider               = google-beta
  name                   = "${var.prefix}bes-ilb-${local.region_short}"
  region                 = var.region
  network                = data.google_compute_subnetwork.subnets[1].network

  backend {
    group                = google_compute_instance_group.fgt-umigs[0].self_link
  }
  backend {
    group                = google_compute_instance_group.fgt-umigs[1].self_link
  }

  health_checks          = [google_compute_region_health_check.health_check.self_link]
  connection_tracking_policy {
    connection_persistence_on_unhealthy_backends = "NEVER_PERSIST"
  }
}

resource "google_compute_forwarding_rule" "ilb_fwd_rule" {
  name                   = "${var.prefix}fwdrule-ilb-${local.region_short}"
  region                 = var.region
  network                = data.google_compute_subnetwork.subnets[1].network
  subnetwork             = data.google_compute_subnetwork.subnets[1].id
  ip_address             = google_compute_address.ilb.address
  all_ports              = true
  load_balancing_scheme  = "INTERNAL"
  backend_service        = google_compute_region_backend_service.ilb_bes.self_link
  allow_global_access    = true
  labels                 = var.labels
}

#resource "google_compute_route" "default_route" {
#  name                   = "${var.prefix}rt-default-via-fgt"
#  dest_range             = "0.0.0.0/0"
#  network                = data.google_compute_subnetwork.subnets[1].network
#  next_hop_ilb           = google_compute_forwarding_rule.ilb_fwd_rule.self_link
#  priority               = 100
#}

# ELB BES
resource "google_compute_region_backend_service" "elb_bes" {
  provider               = google-beta
  name                   = "${var.prefix}bes-elb-${local.region_short}"
  region                 = var.region
  load_balancing_scheme  = "EXTERNAL"
  protocol               = "UNSPECIFIED"

  backend {
    group                = google_compute_instance_group.fgt-umigs[0].self_link
  }
  backend {
    group                = google_compute_instance_group.fgt-umigs[1].self_link
  }

  health_checks          = [google_compute_region_health_check.health_check.self_link]
  connection_tracking_policy {
    connection_persistence_on_unhealthy_backends = "NEVER_PERSIST"
  }
}



# Firewall rules
resource "google_compute_firewall" "allow-mgmt" {
  name                   = "${var.prefix}fw-mgmt-allow-admin"
  network                = data.google_compute_subnetwork.subnets[3].network
  source_ranges          = var.admin_acl
  target_tags            = ["fgt"]

  allow {
    protocol             = "all"
  }
}

resource "google_compute_firewall" "allow-hasync" {
  name                   = "${var.prefix}fw-hasync-allow-fgt"
  network                = data.google_compute_subnetwork.subnets[2].network
  source_tags            = ["fgt"]
  target_tags            = ["fgt"]

  allow {
    protocol             = "all"
  }
}

resource "google_compute_firewall" "allow-port1" {
  name                   = "${var.prefix}fw-ext-allowall"
  network                = data.google_compute_subnetwork.subnets[0].network
  source_ranges          = ["0.0.0.0/0"]

  allow {
    protocol             = "all"
  }
}

resource "google_compute_firewall" "allow-port2" {
  name                   = "${var.prefix}fw-int-allowall"
  network                = data.google_compute_subnetwork.subnets[1].network
  source_ranges          = ["0.0.0.0/0"]

  allow {
    protocol             = "all"
  }
}

# Enable outbound connectivity via Cloud NAT
resource "google_compute_router" "nat_router" {
  name                   = "${var.prefix}cr-cloudnat-${local.region_short}"
  region                 = var.region
  network                = data.google_compute_subnetwork.subnets[0].network
}

resource "google_compute_router_nat" "cloud_nat" {
  name                   = "${var.prefix}nat-cloudnat-${local.region_short}"
  router                 = google_compute_router.nat_router.name
  region                 = var.region
  nat_ip_allocate_option = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  subnetwork {
    name                    = data.google_compute_subnetwork.subnets[0].self_link
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

# ELB Frontends
resource "google_compute_address" "frontends" {
  for_each              = toset(var.frontends)

  name                  = "${var.prefix}eip-${each.value}"
  region                = var.region
  address_type          = "EXTERNAL"
}

resource "google_compute_forwarding_rule" "frontends" {
  for_each              = toset(var.frontends)

  name                  = "${var.prefix}fr-${each.value}"
  region                = var.region
  ip_address            = google_compute_address.frontends[each.value].self_link
  ip_protocol           = "L3_DEFAULT"
  all_ports             = true
  load_balancing_scheme = "EXTERNAL"
  backend_service       = google_compute_region_backend_service.elb_bes.self_link
  labels                = var.labels
}

# OPTIONAL

# Save api_key to Secret Manager
resource "google_secret_manager_secret" "api-secret" {
  count                  = var.api_token_secret_name!="" ? 1 : 0
  secret_id              = var.api_token_secret_name

  replication {
    automatic            = true
  }
}

resource "google_secret_manager_secret_version" "api_key" {
  count                  = var.api_token_secret_name!="" ? 1 : 0
  secret                 = google_secret_manager_secret.api-secret[0].id
  secret_data            = random_string.api_key.id
}
