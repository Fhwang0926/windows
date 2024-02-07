FROM scratch
COPY --from=qemux/qemu-docker:latest / /

ARG DEBCONF_NOWARNINGS="yes"
ARG DEBIAN_FRONTEND "noninteractive"
ARG DEBCONF_NONINTERACTIVE_SEEN "true"

RUN apt-get update \
    && apt-get --no-install-recommends -y install \
        vim net-tools iputils-ping \
        # samba \
        virtiofsd \
        curl \
        7zip \
        wimtools \
        cabextract \
        genisoimage \
        libxml2-utils \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY ./src /run/
COPY ./assets /run/assets
ADD https://github.com/qemus/virtiso/releases/download/v0.1.240/virtio-win-0.1.240.iso /run/drivers.iso
RUN chmod +x /run/*.sh

EXPOSE 8006 3389
VOLUME /storage
# RUN touch /tmp/virtiofsd.sock
# RUN touch /tmp/virtiofs_socket
# VOLUME /opt/data
COPY virtiofsd.sh /etc/init.d/virtiofsd
RUN chmod +x /etc/init.d/virtiofsd
RUN update-rc.d virtiofsd defaults

# RUN mkdir -p /opt/data
# RUN qemu-img create /opt/data/file.img 10G
# RUN echo -e /opt/data *\(rw,sync,no_subtree_check\) >> /etc/exports

ENV RAM_SIZE "4G"
ENV CPU_CORES "2"
ENV DISK_SIZE "64G"
ENV VERSION "win11"

ARG VERSION_ARG "0.0"
RUN echo "$VERSION_ARG" > /run/version
# CMD /etc/init.d/virtiofsd start
# && /run/custom.sh
ENTRYPOINT ["/usr/bin/tini", "--", "bash", "-c", "/run/entry.sh && /run/custom.sh"]
# ENTRYPOINT ["/usr/bin/tini", "-s", "/run/entry.sh"]
