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

export ARCH CROSS_COMPILE
