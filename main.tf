module "my_ip_address" {
  source = "matti/resource/shell"

  command = "curl https://ipinfo.io/ip"
}

module "hashistack_cluster" {
  source = "./modules/aws-hashistack"

  # stack_name         = "hc-jb-nomad-demo"
  owner_name         = var.owner_name
  owner_email        = var.owner_email
  region             = var.region
  availability_zones = var.availability_zones
  ami                = var.ami
  key_name           = var.key_name
  # allowlist_ip       = ["${module.my_ip_address.stdout}/32"]

  client_instance_types = [
    {
      instance_type     = "t3.small",
      weighted_capacity = 1,
    },
    {
      instance_type     = "c4.large",
      weighted_capacity = 1,
    },
    {
      instance_type     = "c5.large",
      weighted_capacity = 1,
    },
    {
      instance_type     = "m3.large",
      weighted_capacity = 1,
    },
    {
      instance_type     = "m4.large",
      weighted_capacity = 1,
    },
    {
      instance_type     = "m5.large",
      weighted_capacity = 1,
    },

  ]
}

module "hashistack_jobs" {
  source = "./modules/shared-nomad-jobs"

  nomad_addr = "http://${module.hashistack_cluster.server_elb_dns}:4646"
}
