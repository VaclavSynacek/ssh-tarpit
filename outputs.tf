output "instance_public_ip" {
  description = "Public IP of EC2 instance"
  value       = aws_instance.tarpit.public_ip
}

output "instance_public_dns" {
  description = "Public DNS of EC2 instance"
  value       = aws_instance.tarpit.public_dns
}

output "instance_id" {
  description = "EC2 instance id"
  value       = aws_instance.tarpit.id
}

