provider "yandex" {
  token     = var.yc_token
  cloud_id  = var.yc_cloud_id
  folder_id = var.yc_folder_id
  zone      = var.yc_zone
}

resource "yandex_vpc_network" "bookstore_network" {
  name = "bookstore-network"
}

resource "yandex_vpc_subnet" "bookstore_subnet" {
  name           = "bookstore-subnet"
  zone           = var.yc_zone
  network_id     = yandex_vpc_network.bookstore_network.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

resource "tls_private_key" "ssh_key" {
  algorithm = "ED25519"
}

resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_openssh
  filename        = "${path.module}/bookstore_id_ed25519"
  file_permission = "0600"
}

resource "local_file" "public_key" {
  content  = tls_private_key.ssh_key.public_key_openssh
  filename = "${path.module}/bookstore_id_ed25519.pub"
}

data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}

resource "yandex_compute_instance" "bookstore_vm" {
  name        = "bookstore-vm"
  platform_id = "standard-v3"
  zone        = var.yc_zone

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 20
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.bookstore_subnet.id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${tls_private_key.ssh_key.public_key_openssh}"
    user-data = <<-EOT
      #cloud-config
      users:
        - name: ubuntu
          sudo: ['ALL=(ALL) NOPASSWD:ALL']
          shell: /bin/bash
          ssh-authorized-keys:
            - ${tls_private_key.ssh_key.public_key_openssh}
      package_update: true
      package_upgrade: true
      packages:
        - apt-transport-https
        - ca-certificates
        - curl
        - gnupg
        - lsb-release
      runcmd:
        - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        - echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        - apt-get update
        - apt-get install -y docker-ce docker-ce-cli containerd.io
        - systemctl start docker
        - systemctl enable docker
        - docker run -d -p 80:8080 jmix/jmix-bookstore
    EOT
  }
}
