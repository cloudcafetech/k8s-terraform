variable "project" {
  type        = string
  description = "The project ID to deploy to"
  default     = "x-pulsar-414702"
}

variable "region" {
  type        = string
  description = "The region to deploy to"
  default     = "us-west4"

}

variable "zone" {
  type        = string
  description = "The zone to deploy to"
  default     = "us-west4-b"
}

variable "machine_type" {
  type        = string
  description = "The machine type to deploy to"
  default     = "e2-medium"
}

variable "image" {
  type        = map(string)
  description = "The image to deploy to"
  default     = {
     centos   = "projects/centos-cloud/global/images/centos-stream-8-v20240110"
     ubuntu   = "projects/ubuntu-os-cloud/global/images/ubuntu-2004-focal-v20240209"
  }
}

variable "user" {
  type    = string
  default = "k8sgcp"
}

variable "email" {
  type    = string
  default = "test@gmail.com"
}

variable "privatekeypath" {
  type    = string
  default = "./gcpkey"
}

variable "publickeypath" {
  type    = string
  default = "./gcpkey.pub"
}

variable "ldapip" {
  type    = string
  default = "10.182.15.208"
}
