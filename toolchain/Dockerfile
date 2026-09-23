FROM debian:trixie

LABEL org.opencontainers.image.source=https://github.com/cilium/ci-kernels

# Preserve the APT cache between runs
RUN rm -f /etc/apt/apt.conf.d/docker-clean; echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates

COPY llvm-snapshot.gpg.key /etc/apt/trusted.gpg.d/apt.llvm.org.asc
COPY llvm.list /etc/apt/sources.list.d/
COPY llvm.pref /etc/apt/preferences.d/

# Bake the appropriate clang version into the container
ARG CLANG_VERSION=22
ARG PAHOLE_VERSION=6fd0dacc9418b103af4245ab300b9c135bcdb383
ENV CLANG=clang-${CLANG_VERSION}
ENV LLC=llc-${CLANG_VERSION}
ENV LLVM_OBJCOPY=llvm-objcopy-${CLANG_VERSION}
ENV LLVM_READELF=llvm-readelf-${CLANG_VERSION}
ENV LLVM_STRIP=llvm-strip-${CLANG_VERSION}
ENV LLVM_DWARFDUMP=llvm-dwarfdump-${CLANG_VERSION}


# Update and install dependencies.
#
# Kernels 5.15 and earlier build libbpf as part of bpf_preload_umd, which
# depends on libelf and zlib, requiring their ARM64 versions to be installed.
# arm64 dependencies can be removed when 5.15 is no longer maintained.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    dpkg --add-architecture arm64 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        libelf-dev:arm64 \
        zlib1g-dev:arm64 \
        curl \
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
        libcap-dev \
        ${CLANG} \
        llvm-${CLANG_VERSION} \
        lld \
        kmod \
        rsync \
        libc6-dev-i386 \
        cmake \
        libdw-dev \
        git \
        xxd

RUN cd /tmp && \
    git clone https://git.kernel.org/pub/scm/devel/pahole/pahole.git && \
    cd pahole && \
    git checkout ${PAHOLE_VERSION} && \
    git submodule update --init --recursive && \
    mkdir build && \
    cd build && \
    cmake -D__LIB=lib -DBUILD_SHARED_LIBS=OFF .. && \
    make install && \
    cd / && \
    rm -rf /tmp/pahole
