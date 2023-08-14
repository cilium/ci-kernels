FROM debian:bullseye

LABEL org.opencontainers.image.source https://github.com/cilium/ci-kernels

COPY bullseye-backports.list /etc/apt/sources.list.d

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
	gcc g++ make git libssl-dev bison flex libelf-dev libssl-dev libc-dev libc6-dev-i386 libcap-dev bc \
	tar xz-utils curl ca-certificates python3-pip python3-setuptools python3-docutils rsync \
	cmake libdw-dev \
	&& rm -rf /var/lib/apt/lists/*

# The LLVM repos need ca-certificates to be present.
COPY llvm-snapshot.gpg /usr/share/keyrings
COPY llvm.list /etc/apt/sources.list.d

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
	clang-14 llvm-14 lld-14 \
	&& rm -rf /var/lib/apt/lists/*

RUN pip3 install https://github.com/amluto/virtme/archive/refs/heads/master.zip

ENV PAHOLE_TAG=v1.23
COPY pahole.sh /pahole.sh
RUN /pahole.sh ${PAHOLE_TAG} && rm /pahole.sh

VOLUME /work

CMD ["/work/make.sh"]
