FROM scratch
COPY --from=qemux/qemu-docker:4.14 / /

ARG DEBCONF_NOWARNINGS="yes"
ARG DEBIAN_FRONTEND "noninteractive"
ARG DEBCONF_NONINTERACTIVE_SEEN "true"

RUN apt-get update \
    && apt-get --no-install-recommends -y install \
        bridge-utils virtinst libvirt-daemon virt-manager libvirt-clients \
        curl iputils-ping net-tools dbus \
        libvirt-daemon-system policykit-1 \
        vim \
        7zip \
        wsdd \
        samba \
        wimtools \
        dos2unix \
        cabextract \
        genisoimage \
        libxml2-utils \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN mkdir -p /utils
COPY ./src /run/
COPY ./utils/*.bat /utils/
COPY ./assets /run/assets

# custom
COPY ./custom/img/favicon.ico /usr/share/novnc/app/images/icons/novnc.ico
COPY ./custom/img/custom.png /usr/share/novnc/app/images/custom.png
COPY ./custom/custom.css /usr/share/novnc/app/styles/custom.css
RUN echo "<link href=\"app/styles/custom.css\" rel=\"stylesheet\" type=\"text/css\" />" >> /usr/share/novnc/vnc.html

ADD https://raw.githubusercontent.com/christgau/wsdd/master/src/wsdd.py /usr/sbin/wsdd
ADD https://github.com/qemus/virtiso/releases/download/v0.1.240/virtio-win-0.1.240.iso /run/drivers.iso

RUN chmod +x /run/*.sh && chmod +x /usr/sbin/wsdd

EXPOSE 8006 3389
VOLUME /storage

ENV RAM_SIZE "4G"
ENV CPU_CORES "2"
ENV DISK_SIZE "64G"
ENV VERSION "win11"
ENV CPU_CORES "4"

ARG VERSION_ARG "0.0"
RUN echo "$VERSION_ARG" > /run/version

ENTRYPOINT ["/usr/bin/tini", "-s", "/run/entry.sh"]
