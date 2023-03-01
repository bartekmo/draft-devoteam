variable "prefix" {
  default = "bmdevo"
}

variable "cidrs" {
  default = {
    "mc": "172.17.0.0/28"
    "ic": "172.17.96.0/24"
    "int": "10.208.0.0/24"
    "hasync": "172.20.2.0/24"
    "mgmt": "172.20.3.0/24"
    "mc-euw3": "192.168.201.0/28"
  }
}
