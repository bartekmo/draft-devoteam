module "fgt_ha" {
  source        = "../../"

  prefix        = "bm-byol-test"
  license_files = ["FGVM04TM22000194.lic", "FGVM04TM22000195.lic"]
  image_family  = "fortigate-72-byol"
  subnets       = [ var.subnet_external, var.subnet_internal, var.subnet_hasync, var.subnet_mgmt]
  region        = "europe-west2"
  api_token_secret_name = "bm-test-secret"
  frontends = ["bm-test1","bm-test2"]
}

output outputs {
  value = module.fgt_ha
}
