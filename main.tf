resource "openstack_compute_keypair_v2" "ssh_pub_key" {
  name       = "ssh_pub_key"
  public_key = file("~/.ssh/id_ed25519.pub")
}

data "openstack_networking_secgroup_v2" "default" {
  name = "default"
}

resource "openstack_networking_secgroup_rule_v2" "ssh_rule" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = data.openstack_networking_secgroup_v2.default.id
}

data "openstack_images_image_v2" "debian13" {
  name        = "Debian 13 trixie"
  most_recent = true
}

resource "openstack_blockstorage_volume_v3" "persistent_volume" {
  name        = "instance-volume"
  size        = 20
  image_id    = data.openstack_images_image_v2.debian13.id
}

resource "openstack_compute_instance_v2" "gpu_instance" {
  name        = "gpu_instance"
  flavor_name = "nvl4-a8-ram16-disk0"
  key_pair    = openstack_compute_keypair_v2.ssh_pub_key.id

  block_device {
    uuid                  = openstack_blockstorage_volume_v3.persistent_volume.id
    source_type           = "volume"
    destination_type      = "volume"
    boot_index            = 0
    delete_on_termination = false
  }

  network {
    name = "ext-net1"
  }
}

output "gpu_instance_ip" {
  value = openstack_compute_instance_v2.gpu_instance.access_ip_v4
}

resource "local_file" "ansible_inventory_yaml" {
  content  = <<-EOT
all:
  hosts:
    gpu_instance:
      ansible_host: ${openstack_compute_instance_v2.gpu_instance.access_ip_v4}
      ansible_user: debian
EOT
  filename = "inventory.yaml"
}
