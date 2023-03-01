data "google_compute_subnetwork" "ic" {
  region = var.region
  name   = var.interconnect_sb_name
}

module "fgt_ha" {
  source        = "./fortigate-gcp-ha-ap-lb-terraform"

  prefix        = "bnext-fgt"
  region        = var.region
  subnets       = [
    var.interconnect_sb_name,
    var.prod_sb_name,
    var.fgthasync_sb_name,
    var.fgtmgmt_sb_name
  ]
  labels        = {
    owner : "bmoczulski"
    project: "devoteam-bnext"
  }
  image_family  = "fortigate-72-byol"
  frontends     = []

  custom_bnext_range = var.bnext_cidr
  custom_mc_overlay_range = var.mc_cidr_overlay

  fgt_config =<<EOT
config router static
%{ for cidr in var.mc_cidrs_underlay }
  edit 0
    set dst ${cidr}
    set device port1
    set gateway ${data.google_compute_subnetwork.ic.gateway_address}
  next
%{ endfor ~}
end
EOT
}
