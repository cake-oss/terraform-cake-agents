variable "name" {
  type        = string
  description = "Apex hostname for the cluster's hosted zone (e.g. agents.example.com). A wildcard ACM cert is issued for this name and *.<name>."
}
