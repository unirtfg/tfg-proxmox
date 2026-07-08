terraform {
  required_version = ">= 1.5"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.66"
    }
  }
}

provider "proxmox" {
  endpoint  = var.pve_endpoint          # https://192.168.2.111:8006/
  api_token = var.pve_api_token         # root@pam!token=<uuid>
  insecure  = var.pve_insecure          # true si cert autofirmado

  ssh {
    agent    = false
    username = "root"
  }
}

# --------------------------------------------------------------------------
# Imagen cloud de Debian 13 (descargada al storage "local" de un nodo)
# --------------------------------------------------------------------------
resource "proxmox_virtual_environment_download_file" "debian13" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = var.template_node
  url          = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
  file_name    = "debian-13-genericcloud-amd64.img"
  overwrite    = false
}

# --------------------------------------------------------------------------
# VMs Debian: 101 seguridad, 102 monitorizacion, 103 productividad, 104 aplicaciones
# --------------------------------------------------------------------------
resource "proxmox_virtual_environment_vm" "vm" {
  for_each = var.vms

  name      = each.value.name
  vm_id     = each.key
  node_name = each.value.node
  tags      = ["tfg", "iac"]
  on_boot   = true

  agent {
    enabled = true
  }

  cpu {
    cores = each.value.cores
    type  = "host"
  }

  memory {
    dedicated = each.value.memory
  }

  scsi_hardware = "virtio-scsi-single"

  disk {
    datastore_id = "local-zfs"
    file_id      = proxmox_virtual_environment_download_file.debian13.id
    interface    = "scsi0"
    size         = each.value.disk
    discard      = "on"
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  serial_device {} # consola serie para imágenes cloud

  initialization {
    datastore_id = "local-zfs"

    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = var.gateway
      }
    }

    dns {
      servers = [var.dns_server]
    }

    user_account {
      username = var.ci_user
      password = var.ci_password
      keys     = [var.ssh_public_key]
    }
  }

  lifecycle {
    ignore_changes = [disk[0].file_id] # no recrear si cambia el nombre de la imagen
  }
}
