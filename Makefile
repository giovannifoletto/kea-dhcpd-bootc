IMAGE          ?= localhost/kea-dhcp-bootc
TAG            ?= latest
FEDORA_VERSION ?= 45
DISK_TYPE      ?= qcow2   # qcow2 | raw | iso | anaconda-iso | vmdk | ami
BIB_IMAGE      ?= quay.io/centos-bootc/bootc-image-builder:latest

.PHONY: build lint disk run-vm clean

## Build the bootc container image.
## Rootful podman is used because bootc-image-builder reads from root's storage.
build:
	sudo podman build \
		--build-arg FEDORA_VERSION=$(FEDORA_VERSION) \
		-t $(IMAGE):$(TAG) .

## Run bootc's image linter against the built image.
lint:
	sudo podman run --rm $(IMAGE):$(TAG) bootc container lint

## Convert the container image into a bootable disk under ./output.
disk: config.toml
	mkdir -p output
	sudo podman run --rm -it --privileged --pull=newer \
		--security-opt label=type:unconfined_t \
		-v ./config.toml:/config.toml:ro \
		-v ./output:/output \
		-v /var/lib/containers/storage:/var/lib/containers/storage \
		$(BIB_IMAGE) \
		--type $(strip $(DISK_TYPE)) \
		--rootfs xfs \
		--use-librepo=True \
		$(IMAGE):$(TAG)

config.toml:
	@echo "config.toml missing: copy config.toml.example and add your SSH key" >&2; exit 1

## Boot the qcow2 for a quick test (user-mode network, so kea won't serve real clients).
run-vm:
	qemu-system-x86_64 -enable-kvm -m 2048 -cpu host -smp 2 \
		-drive file=output/qcow2/disk.qcow2,if=virtio \
		-nic user,model=virtio-net-pci,hostfwd=tcp::2222-:22 \
		-nographic

clean:
	sudo rm -rf output/*
