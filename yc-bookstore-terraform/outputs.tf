output "ssh_connect" {
  description = "SSH команда для подключения к серверу"
  value       = "ssh -i ${path.module}/bookstore_id_ed25519 ubuntu@${yandex_compute_instance.bookstore_vm.network_interface.0.nat_ip_address}"
}

output "web_url" {
  description = "URL для доступа к веб-приложению"
  value       = "http://${yandex_compute_instance.bookstore_vm.network_interface.0.nat_ip_address}"
}

