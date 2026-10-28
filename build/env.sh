# This file should be sourced into another script.

if [ "$TARGETPLATFORM" = "linux/amd64" ]; then
	ARCH=x86_64
	CROSS_COMPILE="x86_64-linux-gnu-"
elif [ "$TARGETPLATFORM" = "linux/arm64" ]; then
	ARCH=arm64
	CROSS_COMPILE="aarch64-linux-gnu-"
else
	echo "Unsupported target platform"; exit 1;
fi

if command -v ccache > /dev/null; then
	CROSS_COMPILE="ccache $CROSS_COMPILE"
	export CLANG="ccache ${CLANG:-clang}"
fi

# Out-of-tree BPF test modules. Moved from bpf_testmod to test_kmods in v6.14.
for TESTMOD_DIR in tools/testing/selftests/bpf/test_kmods tools/testing/selftests/bpf/bpf_testmod; do
	[ -d "$TESTMOD_DIR" ] && break
	TESTMOD_DIR=""
done

# 5.10 predates bpf_testmod; drop the exception when 5.10 is EOL.
if [ -z "$TESTMOD_DIR" ] && [ "${KERNEL_VERSION%.*}" != "5.10" ]; then
	echo "Can't find BPF test modules directory"; exit 1;
fi

export ARCH CROSS_COMPILE TESTMOD_DIR
