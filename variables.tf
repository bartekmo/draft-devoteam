variable "prod_sb_name" {
  type = string
  description = "Name of subnet in Bnext production VPC network. FortiGates port2 will be connected here"
}

variable "interconnect_sb_name" {
  type = string
  description = "Name of subnet in Interconnect VPC. FortiGates port1 will be connected here."
}

variable "fgthasync_sb_name" {
  type = string
  description = "Name of subnet in VPC used for FortiGate HA synchronization (port3)"
}

variable "fgtmgmt_sb_name" {
  type = string
  description = "Name of subnet in management VPC. FortiGates port4 will be connected here."
}

variable "region" {
  type = string
  description = "Region to deploy the solution"
  default = "europe-west1"
}

variable "mc_cidrs_underlay" {
  type = list(string)
  description = "List of CIDRs available on MC side"
  default = ["172.17.0.0/23", "192.168.201.0/30", "192.168.201.4/30"]
}

variable "mc_cidr_overlay" {
  type        = string
  description = "CIDR of MC network available via FGTs"
  default     = "185.96.11.128/26"
}

variable "bnext_cidr" {
  type = string
  description = "CIDR available on bnext cloud side"
  default = "10.208.0.0/24"
}
