variable "custom_bnext_range" {
  type        = string
  description = "CIDR of bnext network in cloud (available via FGT)"
  default     = "10.208.0.0/24"
}

variable "custom_mc_overlay_range" {
  type        = string
  description = "CIDR of MC network available via FGTs"
  default     = "185.96.11.128/26"
}

resource "google_compute_address" "ic_ilb_obs" {
  name                   = "${var.prefix}ip-icilb-obs-${local.region_short}"
  region                 = var.region
  address_type           = "INTERNAL"
  subnetwork             = data.google_compute_subnetwork.subnets[0].id
  address = "172.17.96.4"
}

resource "google_compute_address" "ic_ilb_atman" {
  name                   = "${var.prefix}ip-icilb-atman-${local.region_short}"
  region                 = var.region
  address_type           = "INTERNAL"
  subnetwork             = data.google_compute_subnetwork.subnets[0].id
  address = "172.17.96.132"
}

resource "google_compute_region_backend_service" "ic_ilb_bes" {
  provider               = google-beta
  name                   = "${var.prefix}bes-icilb-${local.region_short}"
  region                 = var.region
  network                = data.google_compute_subnetwork.subnets[0].network
  protocol               = "UDP"

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

resource "google_compute_forwarding_rule" "ic_ilb_fwd_rule_obs" {
  name                   = "${var.prefix}fwdrule-icilb-obs-${local.region_short}"
  region                 = var.region
  network                = data.google_compute_subnetwork.subnets[0].network
  subnetwork             = data.google_compute_subnetwork.subnets[0].id
  ip_address             = google_compute_address.ic_ilb_obs.address
  ip_protocol            = "UDP"
  all_ports              = true
  load_balancing_scheme  = "INTERNAL"
  backend_service        = google_compute_region_backend_service.ic_ilb_bes.self_link
  allow_global_access    = true
  labels                 = var.labels
}

resource "google_compute_forwarding_rule" "ic_ilb_fwd_rule_atman" {
  name                   = "${var.prefix}fwdrule-icilb-atman-${local.region_short}"
  region                 = var.region
  network                = data.google_compute_subnetwork.subnets[0].network
  subnetwork             = data.google_compute_subnetwork.subnets[0].id
  ip_address             = google_compute_address.ic_ilb_atman.address
  ip_protocol            = "UDP"
  all_ports              = true
  load_balancing_scheme  = "INTERNAL"
  backend_service        = google_compute_region_backend_service.ic_ilb_bes.self_link
  allow_global_access    = true
  labels                 = var.labels
}


resource "google_compute_route" "mc_via_fgt" {
  name                   = "${var.prefix}rt-mc-via-fgt"
  dest_range             = var.custom_mc_overlay_range
  network                = data.google_compute_subnetwork.subnets[1].network
  next_hop_ilb           = google_compute_forwarding_rule.ilb_fwd_rule.self_link
  priority               = 100
}
