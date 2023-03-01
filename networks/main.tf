terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
    }
  }
}

resource "google_compute_network" "nets" {
  for_each = toset([ "mc", "ic", "int", "hasync", "mgmt"])

  name = "${var.prefix}-${each.value}"
  auto_create_subnetworks = false
  routing_mode = "GLOBAL"
}

resource "google_compute_subnetwork" "subs" {
  for_each = toset([ "mc", "ic", "int", "hasync", "mgmt"])

  name = "${var.prefix}-sb-${each.value}"
  ip_cidr_range = var.cidrs[ each.value ]
  region = "europe-west1"
  network = google_compute_network.nets[each.value].self_link
}

resource "google_compute_subnetwork" "mc-euw3" {
  name = "${var.prefix}-sb-mc-euw3"
  ip_cidr_range = var.cidrs[ "mc-euw3" ]
  region = "europe-west3"
  network = google_compute_network.nets["mc"].self_link
}

resource "google_compute_firewall" "mc_internal" {
  name = "${var.prefix}-mc-allow-mc"
  network = google_compute_network.nets["mc"].id
  allow {
    protocol = "all"
  }
  source_ranges = ["172.17.0.0/28","182.168.201.0/28"]
}

################################################################################

resource "google_compute_ha_vpn_gateway" "mc1" {
  region   = "europe-west1"
  name     = "${var.prefix}-mc-vpngw-euw1"
  network  = google_compute_network.nets["mc"].id
  vpn_interfaces {
    id = 0
  }
  vpn_interfaces {
    id = 1
  }
}

resource "google_compute_ha_vpn_gateway" "mc3" {
  region   = "europe-west3"
  name     = "${var.prefix}-mc-vpngw-euw3"
  network  = google_compute_network.nets["mc"].id
}

resource "google_compute_ha_vpn_gateway" "bnext1" {
  region   = "europe-west1"
  name     = "${var.prefix}-bnext-vpngw-euw1"
  network  = google_compute_network.nets["ic"].id
  vpn_interfaces {
    id = 0
    # ip_address = 1.2.3.4
  }
  vpn_interfaces {
    id = 1
  }
}

resource "google_compute_ha_vpn_gateway" "bnext3" {
  region   = "europe-west3"
  name     = "${var.prefix}-bnext-vpngw-euw3"
  network  = google_compute_network.nets["ic"].id
}

resource "google_compute_router" "mc1" {
  name = "${var.prefix}-rt-mc-euw1"
  region ="europe-west1"
  network = google_compute_network.nets["mc"].id
  bgp {
    asn = 64601
  }
}

resource "google_compute_router" "mc3" {
  name = "${var.prefix}-rt-mc-euw3"
  region ="europe-west3"
  network = google_compute_network.nets["mc"].id
  bgp {
    asn = 64603
  }
}

resource "google_compute_router" "ic1" {
  name = "${var.prefix}-rt-ic-euw1"
  region ="europe-west1"
  network = google_compute_network.nets["ic"].id
  bgp {
    asn = 64602
    advertise_mode = "CUSTOM"
    advertised_ip_ranges {
      range = "172.17.96.0/28"
    }
  }
}

resource "google_compute_router" "ic3" {
  name = "${var.prefix}-rt-ic-euw3"
  region ="europe-west3"
  network = google_compute_network.nets["ic"].id
  bgp {
    asn = 64604
    advertise_mode = "CUSTOM"
    advertised_ip_ranges {
      range = "172.17.96.128/28"
    }
  }
}

resource "random_password" "secret" {
  length                 = 30
  special                = false
  numeric                = true
}

resource "google_compute_vpn_tunnel" "mc_euw1" {
  count = 2

  name = "${var.prefix}-tun${count.index}-mc-bnext-euw1"
  region = "europe-west1"
  shared_secret = random_password.secret.result
  vpn_gateway = google_compute_ha_vpn_gateway.mc1.self_link
  vpn_gateway_interface = count.index
  peer_gcp_gateway = google_compute_ha_vpn_gateway.bnext1.self_link
  router = google_compute_router.mc1.self_link
}

resource "google_compute_vpn_tunnel" "ic_euw1" {
  count = 2

  name = "${var.prefix}-tun${count.index}-bnext-mc-euw1"
  region = "europe-west1"
  shared_secret = random_password.secret.result
  vpn_gateway = google_compute_ha_vpn_gateway.bnext1.self_link
  vpn_gateway_interface = count.index
  peer_gcp_gateway = google_compute_ha_vpn_gateway.mc1.self_link
  router = google_compute_router.ic1.self_link
}

resource "google_compute_vpn_tunnel" "mc_euw3" {
  count = 2

  name = "${var.prefix}-tun${count.index}-mc-bnext-euw3"
  region = "europe-west3"
  shared_secret = random_password.secret.result
  vpn_gateway = google_compute_ha_vpn_gateway.mc3.self_link
  vpn_gateway_interface = count.index
  peer_gcp_gateway = google_compute_ha_vpn_gateway.bnext3.self_link
  router = google_compute_router.mc3.self_link
}

resource "google_compute_vpn_tunnel" "ic_euw3" {
  count = 2

  name = "${var.prefix}-tun${count.index}-bnext-mc-euw3"
  region = "europe-west3"
  shared_secret = random_password.secret.result
  vpn_gateway = google_compute_ha_vpn_gateway.bnext3.self_link
  vpn_gateway_interface = count.index
  peer_gcp_gateway = google_compute_ha_vpn_gateway.mc3.self_link
  router = google_compute_router.ic3.self_link
}


resource "google_compute_router_interface" "mc1" {
  count = 2

  name       = "${var.prefix}-mc-crif${count.index}-euw1"
  router     = google_compute_router.mc1.name
  region     = "europe-west1"
  ip_range   = "169.254.1${count.index}.1/30"
  vpn_tunnel = google_compute_vpn_tunnel.mc_euw1[count.index].name
}

resource "google_compute_router_interface" "ic1" {
  count = 2

  name       = "${var.prefix}-ic-crif${count.index}-euw1"
  router     = google_compute_router.ic1.name
  region     = "europe-west1"
  ip_range   = "169.254.1${count.index}.2/30"
  vpn_tunnel = google_compute_vpn_tunnel.ic_euw1[count.index].name
}

resource "google_compute_router_interface" "mc3" {
  count = 2

  name       = "${var.prefix}-mc-crif${count.index}-euw3"
  router     = google_compute_router.mc3.name
  region     = "europe-west3"
  ip_range   = "169.254.3${count.index}.1/30"
  vpn_tunnel = google_compute_vpn_tunnel.mc_euw3[count.index].name
}

resource "google_compute_router_interface" "ic3" {
  count = 2

  name       = "${var.prefix}-ic-crif${count.index}-euw3"
  router     = google_compute_router.ic3.name
  region     = "europe-west3"
  ip_range   = "169.254.3${count.index}.2/30"
  vpn_tunnel = google_compute_vpn_tunnel.ic_euw3[count.index].name
}


resource "google_compute_router_peer" "mc1_ic1" {
  count = 2

  name                      = "${var.prefix}-vpnpeer${count.index}-ic-euw1"
  router                    = google_compute_router.mc1.name
  region                    = "europe-west1"
  peer_ip_address           = split( "/", google_compute_router_interface.ic1[count.index].ip_range)[0]
  peer_asn                  = google_compute_router.ic1.bgp[0].asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.mc1[count.index].name
}

resource "google_compute_router_peer" "ic1_mc1" {
  count = 2

  name                      = "${var.prefix}-vpnpeer${count.index}-mc-euw1"
  router                    = google_compute_router.ic1.name
  region                    = "europe-west1"
  peer_ip_address           = split( "/", google_compute_router_interface.mc1[count.index].ip_range)[0]
  peer_asn                  = google_compute_router.mc1.bgp[0].asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.ic1[count.index].name
}

resource "google_compute_router_peer" "mc3_ic3" {
  count = 2

  name                      = "${var.prefix}-vpnpeer${count.index}-ic-euw3"
  router                    = google_compute_router.mc3.name
  region                    = "europe-west3"
  peer_ip_address           = split( "/", google_compute_router_interface.ic3[count.index].ip_range)[0]
  peer_asn                  = google_compute_router.ic3.bgp[0].asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.mc3[count.index].name
}

resource "google_compute_router_peer" "ic3_mc3" {
  count = 2

  name                      = "${var.prefix}-vpnpeer${count.index}-mc-euw3"
  router                    = google_compute_router.ic3.name
  region                    = "europe-west3"
  peer_ip_address           = split( "/", google_compute_router_interface.mc3[count.index].ip_range)[0]
  peer_asn                  = google_compute_router.mc3.bgp[0].asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.ic3[count.index].name
}
