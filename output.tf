output "public_instance_ip" {
  description = "Public Instance' public ip address"
  value       = aws_instance.public_instance.public_ip
}

output "private_instance_ip" {
  description = "Private Instance' private DNS address"
  value       = aws_instance.private_instance.private_dns
}

output "instance_key_pair_public_pem" {
  description = "Public key as pem file that will used to login to instances via SSH"
  value       = tls_private_key.generated_instance_key.public_key_pem
}

output "instance_key_pair_private_pem" {
  description = "Private key as pem file that will used to login to instances via SSH"
  value       = tls_private_key.generated_instance_key.private_key_pem
  sensitive   = true
}
