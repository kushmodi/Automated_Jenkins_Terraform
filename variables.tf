variable "username" {}
variable "password" {}
variable "name" {}
variable "key-name" {
  default = "jenkins-slave"
}
variable "security-group" {
  default = "allow-ssh"
}