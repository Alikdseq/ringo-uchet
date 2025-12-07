# Outputs уже определены в main.tf, но можно вынести сюда для лучшей организации

output "infrastructure_summary" {
  value = {
    environment      = var.environment
    region           = var.region
    vpc_id          = digitalocean_vpc.ringo_vpc.id
    api_instances   = var.api_instance_count
    worker_instances = var.worker_instance_count
    load_balancer_ip = digitalocean_loadbalancer.ringo_lb.ip
  }
  description = "Infrastructure summary"
}

