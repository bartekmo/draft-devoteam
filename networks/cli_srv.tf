resource "google_compute_instance" "cli" {
  name                   = "${var.prefix}-cli"
  zone                   = "europe-west1-b"
  machine_type           = "e2-standard-2"
  can_ip_forward         = true

  boot_disk {
    initialize_params {
      image              = "https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/ubuntu-2004-focal-v20230213"
    }
  }

  network_interface {
    subnetwork           = google_compute_subnetwork.subs["int"].id
    network_ip           = "10.208.0.10"
  }
}

resource "google_compute_instance" "srv" {
  name                   = "${var.prefix}-srv"
  zone                   = "europe-west1-b"
  machine_type           = "e2-standard-2"
  can_ip_forward         = true

  boot_disk {
    initialize_params {
      image              = "https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/ubuntu-2004-focal-v20230213"
    }
  }

  network_interface {
    subnetwork           = google_compute_subnetwork.subs["mc"].id
    network_ip           = "172.17.0.10"
  }
}
