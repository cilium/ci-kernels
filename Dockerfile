FROM debian:latest

# Preserve the APT cache between runs
RUN rm -f /etc/apt/apt.conf.d/docker-clean; echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache

# Update and install dependencies
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
        tar \
        build-essential \
        crossbuild-essential-amd64 \
        crossbuild-essential-arm64 \
        libncurses5-dev \
        bison \
        flex \
        libssl-dev \
        bc \
        xz-utils \
        ccache \
        libelf-dev \
        python3-docutils \
        python3-pip \
        pahole \
        libcap-dev \
        clang \
        llvm \
        lld \
        kmod \
        rsync \
        libc6-dev-i386

# Install virtme-configkernel
RUN pip3 install --break-system-packages https://github.com/amluto/virtme/archive/refs/heads/master.zip
