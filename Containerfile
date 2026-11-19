# Kea DHCP server as a bootable container (bootc) image.
ARG BASE_IMAGE=quay.io/fedora/fedora-bootc
ARG FEDORA_VERSION=45
FROM ${BASE_IMAGE}:${FEDORA_VERSION}

# Packages: Kea DHCPv4/v6 + control agent, firewalld, and a few admin tools.
RUN dnf -y install \
        kea \
        firewalld \
        tcpdump \
        jq \
    && dnf clean all \
    && rm -rf /var/cache/* /var/log/dnf* /var/lib/dnf /run/dnf /run/kea /var/log/kea \
    # Empty lease files from the RPM; kea creates them in /var at runtime.
    && rm -f /var/lib/kea/*.csv

# Configuration and systemd drop-ins.
COPY rootfs/ /

# Kea refuses world-readable configs; keep them root:kea 0640.
RUN chown -R root:kea /etc/kea \
    && chmod 0750 /etc/kea \
    && chmod 0640 /etc/kea/*.conf \
    && chmod 0600 /etc/NetworkManager/system-connections/*.nmconnection

# Validate the Kea config at build time so a broken config never ships.
# The real interface doesn't exist in the build container, so the check runs on
# a copy with an empty interface list.
RUN sed 's/"interfaces": *\[[^]]*\]/"interfaces": []/' /etc/kea/kea-dhcp4.conf \
        > /etc/kea/.build-check.conf \
    && kea-dhcp4 -t /etc/kea/.build-check.conf \
    ; rc=$?; rm -f /etc/kea/.build-check.conf; exit $rc

# Open DHCP in the firewall (offline, since firewalld isn't running at build time).
RUN firewall-offline-cmd --add-service=dhcp

RUN systemctl enable kea-dhcp4.service firewalld.service

# Catch common bootc image mistakes.
RUN bootc container lint
