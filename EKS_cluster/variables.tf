locals {
  region                    = "ap-northeast-1"
  azs                       = ["ap-northeast-1a", "ap-northeast-1c"]
  cidr                      = "10.0.0.0/16"
  public_subnets            = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets           = ["10.0.11.0/24", "10.0.12.0/24"]
  tag                       = "nam-terra"
  worker_node_instance_type = "t3.small"
  bastion_instance_type     = "t3.small"
  any_protocol              = "-1"
  tcp_protocol              = "tcp"
  ssh_port                  = "22"
  icmp_protocol             = "icmp"
  all_network               = "0.0.0.0/0"
}
