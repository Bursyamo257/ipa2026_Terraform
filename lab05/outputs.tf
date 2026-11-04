
#output "public_ip" {
#  value       = module.web_server.public_ip
#  description = "Public IPv4 address of the web server"
#}

#output "web_url" {
#  value       = "http://${module.web_server.public_dns}"
#  description = "Ready-to-click URL for the web server"
#}

output "admin_password" {
  value       = var.admin_password
  description = "Demonstration of a sensitive output"
  sensitive   = true
}

output "server_summary" {
  description = "Map of server name to its public DNS"
  value = {
    for name, inst in module.web_server.instances :
    name => inst.public_dns
  }
}

output "frontend_servers" {
  description = "Names of frontend servers only"
  value = [
    for name, cfg in var.servers : name
    if cfg.role == "frontend"
  ]
}

output "all_private_ips" {
  description = "Splat over all instances"
  value       = values(module.web_server.instances)[*].private_ip
}