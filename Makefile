VERSION := 4.18.13

BUILD_DIR := $(CURDIR)/build
SRC_DIR := $(BUILD_DIR)/linux-$(VERSION)

all:
	mkdir -p "$(BUILD_DIR)"
	test -e "$(BUILD_DIR)/linux.tar.xz" || curl https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-$(VERSION).tar.xz -o "$(BUILD_DIR)/linux.tar.xz"
	test -d "$(SRC_DIR)" || tar --xz -xf "$(BUILD_DIR)/linux.tar.xz" -C "$(BUILD_DIR)"
	$(MAKE) -C "$(SRC_DIR)" ARCH=um allnoconfig KCONFIG_ALLCONFIG="$(CURDIR)/config"
	$(MAKE) -C "$(SRC_DIR)" ARCH=um clean
	$(MAKE) -C "$(SRC_DIR)" ARCH=um
	mv "$(SRC_DIR)/linux" "$(CURDIR)/linux-$(VERSION)"
