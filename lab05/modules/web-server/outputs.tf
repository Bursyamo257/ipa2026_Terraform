#output "instance_id" {
#  value       = aws_instance.web.id
#  description = "ID of the created instance"
#}

#output "public_ip" {
#  value       = aws_instance.web.public_ip
#  description = "Public IPv4 address"
#}

#output "public_dns" {
#  value       = aws_instance.web.public_dns
#  description = "Public DNS hostname"
#}

output "security_group_id" {
  value       = aws_security_group.web.id
  description = "ID of the created security group"
}

#output "instance_ids" {
#  value = aws_instance.web[*].id # splat expression
#}

#output "public_ips" {
#  value = aws_instance.web[*].public_ip
#}

output "server_ids" {
  value = { for k, v in aws_instance.server : k => v.id }
}

output "instances" {
  description = "Instance details, keyed by the key from var.servers"
  value = {
    for name, inst in aws_instance.server : name => {
      id                = inst.id
      instance_type     = inst.instance_type
      private_ip        = inst.private_ip
      public_ip         = inst.public_ip
      public_dns        = inst.public_dns
      availability_zone = inst.availability_zone
    }
  }
}