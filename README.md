# kea-dhcp-bootc

A bootable container ([bootc](https://bootc-dev.github.io/bootc/)) image that runs the
Kea DHCPv4 server on Fedora.

## Layout

| Path | Purpose |
|------|---------|
| `Containerfile` | Image definition (Fedora bootc + kea + firewalld) |
| `rootfs/etc/kea/kea-dhcp4.conf` | Kea DHCPv4 config, checked at build time |
| `rootfs/etc/NetworkManager/system-connections/dhcp-lan.nmconnection` | Static IP for the served interface |
| `rootfs/usr/lib/systemd/system/kea-dhcp4.service.d/10-bootc.conf` | Restart policy |
| `config.toml.example` | bootc-image-builder user/disk customizations |

## Before building

1. Set your interface name, subnet, pool, router and DNS in `kea-dhcp4.conf`.
2. Set the same interface and the server's static IP in `dhcp-lan.nmconnection`.
3. `cp config.toml.example config.toml` and add your SSH key.

## Build and deploy

```sh
make build                 # sudo podman build -> localhost/kea-dhcp-bootc:latest
make lint                  # bootc container lint
make disk                  # qcow2 in ./output (DISK_TYPE=raw|iso|anaconda-iso|...)
make run-vm                # quick boot test with QEMU (ssh -p 2222 admin@localhost)
```

To change a machine that is already running, push the image to a registry and switch to it:

```sh
sudo bootc switch registry.example.com/kea-dhcp-bootc:latest
sudo bootc upgrade --apply   # later updates
sudo bootc rollback          # if an update is bad
```

## Notes

- **Leases** are stored in `/var/lib/kea`. bootc keeps `/var` across updates, so they survive upgrades and rollbacks.
- **`/etc` changes** made on the host are merged three-way during updates. Change Kea config in this repo, not on the host, so the image stays the source of truth.
- **Kea 3.x path rules**: the control socket must be under `/var/run/kea` and leases under `/var/lib/kea`.
- **Build-time config check**: the build runs `kea-dhcp4 -t` on a copy of the config with no interfaces, because the real NIC doesn't exist in the build container.
- **Logs**: `journalctl -u kea-dhcp4`. Leases: `/var/lib/kea/kea-leases4.csv`.
