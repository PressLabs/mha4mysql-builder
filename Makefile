include VERSIONS

# We check for $CI_BUILD_DIR env variable to set the target accordingly if we
# are within a CI environment
ifdef CI_BUILD_DIR
	TARGET ?= $(CI_BUILD_DIR)/build
else
	TARGET ?= /target
endif

ifdef CI_COMMIT
	COMMIT ?= $(CI_COMMIT)
else
	COMMIT ?= '(none)'
endif

BUILD_DIST := $(shell lsb_release -sc)
ifdef CI_TAG
	BUILD_VERSION ?= ~ppa$(CI_TAG:v%=%)
else
ifdef CI_BRANCH
	BUILD_VERSION ?= ~ppa$(CI_BUILD_NUMBER)+$(CI_BRANCH)
else
	BUILD_VERSION ?= $(shell date +'~ppa%Y%m%d+%H%M%S')
endif
endif

BUILD_VERSION := $(BUILD_DIST)$(BUILD_VERSION)

all: binary

# This step should prepare the build environment. It should download required
# packages install eventual build dependencies. This target should NOT DEPEND
# on BUILD_VERSION variable as this would break CI builds.
prepare:
	@echo Adding Presslabs PPA
	@add-apt-repository -y ppa:presslabs/ppa
	@apt-get update || true

	@echo Preparing build for $(TARGET)
	@mkdir -p $(TARGET) || true

	@echo "Fetching mha4mysql-manager from $(MHA4MYSQL_MANAGER_URL)"
	@mkdir $(TARGET)/mha4mysql-manager-$(MHA4MYSQL_MANAGER_VERSION)
	@wget -q $(MHA4MYSQL_MANAGER_URL) -O $(TARGET)/mha4mysql-manager.tar.gz
	@tar -zxf $(TARGET)/mha4mysql-manager.tar.gz -C $(TARGET)/mha4mysql-manager-$(MHA4MYSQL_MANAGER_VERSION) --strip-components=1
	@rm $(TARGET)/mha4mysql-manager.tar.gz
	@rm -rf $(TARGET)/mha4mysql-manager-$(MHA4MYSQL_MANAGER_VERSION)/debian
	@tar -zcf $(TARGET)/mha4mysql-manager_$(MHA4MYSQL_MANAGER_VERSION).orig.tar.gz -C $(TARGET) mha4mysql-manager-$(MHA4MYSQL_MANAGER_VERSION)

	@echo "Fetching mha4mysql-node from $(MHA4MYSQL_NODE_URL)"
	@mkdir $(TARGET)/mha4mysql-node-$(MHA4MYSQL_NODE_VERSION)
	@wget -q $(MHA4MYSQL_NODE_URL) -O $(TARGET)/mha4mysql-node.tar.gz
	@tar -zxf $(TARGET)/mha4mysql-node.tar.gz -C $(TARGET)/mha4mysql-node-$(MHA4MYSQL_NODE_VERSION) --strip-components=1
	@rm $(TARGET)/mha4mysql-node.tar.gz
	@rm -rf $(TARGET)/mha4mysql-node-$(MHA4MYSQL_NODE_VERSION)/debian
	@tar -zcf $(TARGET)/mha4mysql-node_$(MHA4MYSQL_NODE_VERSION).orig.tar.gz -C $(TARGET) mha4mysql-node-$(MHA4MYSQL_NODE_VERSION)

	@echo "Preparing ./debian folder"
	@cp -r debian-manager $(TARGET)/mha4mysql-manager-$(MHA4MYSQL_MANAGER_VERSION)/debian
	@cp -r debian-node $(TARGET)/mha4mysql-node-$(MHA4MYSQL_NODE_VERSION)/debian
	ls -l $(TARGET)


source: prepare
	@echo Building mha4mysql-manager $(BUILD_VERSION) source
	cd $(TARGET)/mha4mysql-manager-$(MHA4MYSQL_MANAGER_VERSION) \
		&& dch -b -D $(BUILD_DIST) -v $(MHA4MYSQL_MANAGER_VERSION)-$(BUILD_VERSION) "Automated build of mha4mysql-manager $(MHA4MYSQL_MANAGER_VERSION) (mha4mysql-builder $(COMMIT))" \
		&& debuild -S -sa --lintian-opts --allow-root
	@echo Building mha4mysql-node $(BUILD_VERSION) source
	cd $(TARGET)/mha4mysql-node-$(MHA4MYSQL_NODE_VERSION) \
		&& dch -b -D $(BUILD_DIST) -v $(MHA4MYSQL_NODE_VERSION)-$(BUILD_VERSION) "Automated build of mha4mysql-node $(MHA4MYSQL_NODE_VERSION) (mha4mysql-builder $(COMMIT))" \
		&& debuild -S -sa --lintian-opts --allow-root

binary: prepare
	@echo Building mha4mysql-manager $(BUILD_VERSION) binaries
	cd $(TARGET)/mha4mysql-manager-$(MHA4MYSQL_MANAGER_VERSION) \
		&& dch -b -D $(BUILD_DIST) -v $(MHA4MYSQL_MANAGER_VERSION)-$(BUILD_VERSION) "Automated build of mha4mysql-manager $(MHA4MYSQL_MANAGER_VERSION) (mha4mysql-builder $(COMMIT))" \
        && mk-build-deps --install --remove --tool "apt-get --no-install-recommends --yes" \
		&& debuild -us -uc -b -sa --lintian-opts --allow-root

	@echo Building mha4mysql-node $(BUILD_VERSION) binaries
	cd $(TARGET)/mha4mysql-node-$(MHA4MYSQL_NODE_VERSION) \
		&& dch -b -D $(BUILD_DIST) -v $(MHA4MYSQL_NODE_VERSION)-$(BUILD_VERSION) "Automated build of mha4mysql-node $(MHA4MYSQL_NODE_VERSION) (mha4mysql-builder $(COMMIT))" \
        && mk-build-deps --install --remove --tool "apt-get --no-install-recommends --yes" \
		&& debuild -us -uc -b -sa --lintian-opts --allow-root

clean:
	rm -rf $(TARGET)/mha4mysql-*

.PHONY: all prepare build clean
