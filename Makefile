VERSION=0.0.2
DEBPKG=nextbox_$(VERSION)-1_all.deb

IMAGE_NAME=dev-docker
DEV_DEVICE=192.168.10.50
DEV_USER=nextuser
DEV_ROOT_USER=root

all:
	# do nothing by default

#all: src/app/nextbox/js/nextbox.js $(DEBPKG) 
#	# done

install-deb:
	scp $(DEBPKG) $(DEV_USER)@$(DEV_DEVICE):/tmp
	ssh $(DEV_ROOT_USER)@$(DEV_DEVICE) -- dpkg -i /tmp/$(DEBPKG)

update-daemon:
	ssh $(DEV_ROOT_USER)@$(DEV_DEVICE) -- systemctl stop nextbox-daemon
	ssh $(DEV_ROOT_USER)@$(DEV_DEVICE) -- rm -rf /usr/lib/python3/dist-packages/nextbox_daemon/__pycache__
	ssh $(DEV_ROOT_USER)@$(DEV_DEVICE) -- rm -rf /usr/lib/python3/dist-packages/nextbox_daemon/api/__pycache__
	rsync -r --info=progress --exclude='__pycache__/*' --exclude='api/__pycache__/*' src/nextbox_daemon \
		$(DEV_ROOT_USER)@$(DEV_DEVICE):/usr/lib/python3/dist-packages/
	ssh $(DEV_ROOT_USER)@$(DEV_DEVICE) -- systemctl start nextbox-daemon

update-app: src/app/nextbox/js/nextbox.js
	make -C src/app/nextbox build-js
	ssh $(DEV_ROOT_USER)@$(DEV_DEVICE) -- rm -rf /srv/nextcloud/custom_apps/nextbox/js
	rsync -r --info=progress --exclude='node_modules/*' --exclude='vendor/*' src/app/nextbox/js \
		$(DEV_ROOT_USER)@$(DEV_DEVICE):/srv/nextcloud/custom_apps/nextbox
	rsync -r --info=progress --exclude='node_modules/*' --exclude='vendor/*' src/app/nextbox/lib/Controller \
		$(DEV_ROOT_USER)@$(DEV_DEVICE):/srv/nextcloud/custom_apps/nextbox/lib
	#ssh root@192.168.10.50 -- chown root.root -R /srv/nextcloud/custom_apps/nextbox

watch-update-app:
	make -C src
	while true; do \
		inotifywait -e MODIFY --fromfile watch-files-app; \
		make update-app; \
	done 
 
watch-update-daemon:
	while true; do \
		inotifywait -e MODIFY `find src/nextbox_daemon/ -name "*.py"`; \
		make update-daemon; \
  done


###
### debian docker
###

start-dev-docker: dev-image
	-docker stop $(IMAGE_NAME)
	-docker rm $(IMAGE_NAME)
	sleep 1
	docker run --rm --name $(IMAGE_NAME) -d -it \
		-v $(HOME)/.gnupg:/root/.gnupg \
		-v $(shell pwd):/build \
		-v $(HOME)/.dput.cf:/root/.dput.cf \
		-p 8080:80 \
		$(IMAGE_NAME):stable
	
enter-dev-docker: start-dev-docker
	docker exec -it $(IMAGE_NAME) bash

dev-image: Dockerfile
	docker build --label $(IMAGE_NAME) --tag $(IMAGE_NAME):stable --network host .
	touch $@

###
### debian build package
###

src/app/nextbox/js/nextbox-main.js:
	make -C src

$(DEBPKG): src/app/nextbox/js/nextbox-main.js src/nextbox_daemon src/debian/control src/debian/rules src/debian/dirs src/debian/install src/debian/source/options
	# -us -uc for non signed build
	cd src && \
		dpkg-buildpackage -S && \
		fakeroot dpkg-buildpackage -b 
	#debsign -k CC74B7120BFAA36FF42868724C1449F1C9804176 nextbox_$(VERSION)-1_source.changes

deb-clean:
	rm -f nextbox_$(VERSION)-*_all.*
	rm -f nextbox_$(VERSION)-*_arm64.*
	rm -f nextbox_$(VERSION)-*_amd64.*
	rm -f nextbox_$(VERSION)-*_source.*
	rm -f nextbox_$(VERSION)-*.dsc
	rm -f nextbox_$(VERSION)-*.tar.gz

deb: start-dev-docker
	docker exec -it $(IMAGE_NAME) make $(DEBPKG)

.PHONY: deb

