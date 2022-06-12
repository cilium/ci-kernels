FROM debian:bullseye

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
	gcc g++ make git libssl-dev bison flex libelf-dev libssl-dev libc-dev libc6-dev-i386 libcap-dev bc \
	tar xz-utils curl ca-certificates python3-pip python3-setuptools python3-docutils dwarves rsync \
	&& rm -rf /var/lib/apt/lists/*

# The LLVM repos need ca-certificates to be present.
COPY llvm-snapshot.gpg /usr/share/keyrings
COPY llvm.list /etc/apt/sources.list.d

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
	clang-14 llvm-14 \
	&& rm -rf /var/lib/apt/lists/*

RUN pip3 install https://github.com/amluto/virtme/archive/refs/heads/master.zip

VOLUME /work

CMD ["/work/make.sh"]
