
output "public_ip" {
  value       = module.web_server.public_ip
  description = "Public IPv4 address of the web server"
}

output "web_url" {
  value       = "http://${module.web_server.public_dns}"
  description = "Ready-to-click URL for the web server"
}

output "admin_password" {
  value       = var.admin_password
  description = "Demonstration of a sensitive output"
  sensitive   = true
}