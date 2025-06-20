FROM --platform=$BUILDPLATFORM ghcr.io/cilium/ci-kernels-builder:1750404286 AS configure-vmlinux

ARG KERNEL_VERSION

# Download and cache kernel
COPY download.sh .

RUN --mount=type=cache,target=/tmp/kernel ./download.sh

WORKDIR /usr/src/linux

COPY ccache.conf /etc/ccache.conf

COPY configure-vmlinux.sh env.sh config config-arm64 config-x86_64 .

ARG KBUILD_BUILD_TIMESTAMP="Thu  6 Jul 01:00:00 UTC 2023"
ARG KBUILD_BUILD_HOST="ci-kernels-builder"
ARG TARGETPLATFORM

RUN ./configure-vmlinux.sh

FROM configure-vmlinux AS build-vmlinux

COPY build-vmlinux.sh .

RUN --mount=type=cache,target=/ccache \
    ccache -z; \
    ./build-vmlinux.sh && \
    ccache -s

# Install vmlinuz
RUN mkdir -p /tmp/output/boot && \
    find ./ -type f -name '*Image' -exec cp -v {} /tmp/output/boot/vmlinuz \;

# Install modules in /usr/lib/modules, with a symlink from /lib to
# /usr/lib. This avoids breaking overlay in merged usr scenarios.
RUN if [ -d tools/testing/selftests/bpf/bpf_testmod ]; then \
        make M=tools/testing/selftests/bpf/bpf_testmod INSTALL_MOD_PATH=/tmp/output/usr modules_install; \
        ln -s usr/lib /tmp/output/lib; \
    fi

# Starting with v6.14-rc1 the location of testmods has changed.
RUN if [ -d tools/testing/selftests/bpf/test_kmods ]; then \
        make M=tools/testing/selftests/bpf/test_kmods INSTALL_MOD_PATH=/tmp/output/usr modules modules_install; \
        ln -s usr/lib /tmp/output/lib; \
    fi

FROM build-vmlinux AS build-vmlinux-debug

# Package debug info
RUN mkdir -p /tmp/debug/boot

COPY copy-debug.sh filter-debug.awk .
RUN ./copy-debug.sh /tmp/debug

# Build selftests
FROM build-vmlinux AS build-selftests

ARG BUILDPLATFORM

RUN if [ "$BUILDPLATFORM" != "$TARGETPLATFORM" ]; then \
        echo "Can't cross compile selftests"; exit 1; \
    fi

COPY build-selftests.sh .
RUN --mount=type=cache,target=/ccache \
    ccache -z; \
    ./build-selftests.sh && \
    ccache -s

COPY copy-selftests.sh .
RUN mkdir /tmp/selftests && ./copy-selftests.sh /tmp/selftests

# Prepare the final kernel image
FROM scratch AS vmlinux

LABEL org.opencontainers.image.licenses=GPL-2.0-only

COPY --from=build-vmlinux /tmp/output /

# Debug
FROM vmlinux AS vmlinux-debug

LABEL org.opencontainers.image.licenses=GPL-2.0-only

COPY --from=build-vmlinux-debug /tmp/debug /

# Prepare the selftests image
FROM vmlinux AS selftests-bpf

LABEL org.opencontainers.image.licenses=GPL-2.0-only

COPY --from=build-selftests /tmp/selftests /usr/src/linux

# Debug
FROM vmlinux-debug AS selftests-bpf-debug

LABEL org.opencontainers.image.licenses=GPL-2.0-only

COPY --from=build-selftests /tmp/selftests /usr/src/linux
