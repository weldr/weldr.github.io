FROM fedora:latest
RUN dnf --setopt=deltarpm=0 --verbose install -y passwd sudo vim-enhanced less redhat-rpm-config \
@development-tools gcc-c++ autoconf automake libtool zlib-devel \
rubygem-bundler ruby-devel kernel-headers
WORKDIR /weldr.io/

# Run as user passed in with --env LOCAL_UID=`id -u`
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
