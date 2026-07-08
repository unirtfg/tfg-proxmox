output "vms" {
  description = "VMs creadas: id, nombre, IP"
  value = {
    for id, vm in proxmox_virtual_environment_vm.vm :
    id => {
      name = vm.name
      node = vm.node_name
      ipv4 = one(vm.initialization[0].ip_config[0].ipv4).address
    }
  }
}

output "debian_image" {
  description = "Imagen cloud descargada"
  value       = proxmox_virtual_environment_download_file.debian13.id
}
