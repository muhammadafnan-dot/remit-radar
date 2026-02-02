variable  aws_region {
    type = string
    default = "eu-central-1"
}
variable "aws_profile" {
    type = string
    default = "remit-radar"
}
variable "project_name" {
    type = string
    default = "remit-radar"
}
variable "environment" {
    type = string
    default = "dev"
}
variable "db_username" {
    type = string
    default = "remit-radar"
}
variable "db_password" {
    type = string
    default = "remit-radar"
    sensitive = true
}
variable "rails_master_key" {
    type = string
    sensitive = true
}
