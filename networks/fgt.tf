data "google_compute_image" "fgt_image" {
  project         = "fortigcp-project-001"
  family          = "fortigate-72-byol"
}

resource "google_compute_instance" "fgt1" {
  name                   = "${var.prefix}-fakecisco-euw1"
  zone                   = "europe-west1-b"
  machine_type           = "e2-standard-2"
  can_ip_forward         = true
  tags                   = ["fgt"]

  boot_disk {
    initialize_params {
      image              = data.google_compute_image.fgt_image.self_link
    }
  }

  network_interface {
    subnetwork           = google_compute_subnetwork.subs["mc"].id
    network_ip           = "172.17.0.5"

    alias_ip_range {
      ip_cidr_range = "172.17.0.6/32"
    }
    access_config {}
  }
}

resource "google_compute_instance" "fgt3" {
  name                   = "${var.prefix}-fakecisco-euw3"
  zone                   = "europe-west3-b"
  machine_type           = "e2-standard-2"
  can_ip_forward         = true
  tags                   = ["fgt"]

  boot_disk {
    initialize_params {
      image              = data.google_compute_image.fgt_image.self_link
    }
  }

  network_interface {
    subnetwork           = google_compute_subnetwork.mc-euw3.id
    network_ip           = "192.168.201.2"

    alias_ip_range {
      ip_cidr_range = "192.168.201.6/32"
    }
    access_config {}
  }
}

resource "google_compute_firewall" "mc_admin" {
  name = "${var.prefix}-mc-fgt-admin"
  network = google_compute_network.nets["mc"].id
  allow {
    protocol = "tcp"
    ports = ["443", "22"]
  }
  target_tags = ["fgt"]
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "mc_ipsec" {
  name = "${var.prefix}-mc-allow-ipsec"
  network = google_compute_network.nets["mc"].id
  allow {
    protocol = "udp"
    ports = ["500", "4500"]
  }
  target_tags = ["fgt"]
  source_ranges = ["172.17.96.0/28"]
}
