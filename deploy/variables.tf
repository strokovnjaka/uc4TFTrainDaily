variable "prefix" {
  default = "ucTFTrain"
  description = "The prefix which should be used for all resources"
}

variable "location" {
  default = "West Europe"
  description = "The Azure Region in which all resources should be created."
}

variable "container_name" {
  default = "traincontainer"
}

variable "model_container_name" {
  default = "modelcontainer"
}

variable "app_name_tftrain" {
  default = "tftrain-app"
  description = "Application name for tftrain"
}

variable "app_name_generatedata" {
  default = "gendata-app"
  description = "Application name for generatedata"
}

variable "client_id" {}

variable "client_secret" {}