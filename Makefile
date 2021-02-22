VERSION=0.0.2
DEBPKG=nextbox_$(VERSION)-1_all.deb

IMAGE_NAME=dev-docker

all: src/app/nextbox $(DEBPKG) 
	# done

install-deb:
	scp $(DEBPKG) nextuser@192.168.10.50:/tmp
	ssh root@192.168.10.50 -- dpkg -i /tmp/$(DEBPKG)

update-daemon:
	ssh root@192.168.10.50 -- systemctl stop nextbox-daemon
	ssh root@192.168.10.50 -- rm -rf /usr/lib/python3/dist-packages/nextbox_daemon/__pycache__
	scp -r src/nextbox_daemon/*.py root@192.168.10.50:/usr/lib/python3/dist-packages/nextbox_daemon/
	ssh root@192.168.10.50 -- systemctl start nextbox-daemon

update-app: src/app/nextbox/node_modules
	make -C src/app/nextbox build-js
	ssh root@192.168.10.50 -- rm -rf /srv/nextcloud/custom_apps/nextbox
	rsync -r --info=progress --exclude='node_modules/*' --exclude='vendor/*' src/app/nextbox \
		root@192.168.10.50:/srv/nextcloud/custom_apps
	ssh root@192.168.10.50 -- chown www-data.www-data -R /srv/nextcloud/custom_apps/nextbox

src/app/nextbox/node_modules:
	cd src/app/nextbox && \
		npm install

start-dev-docker: dev-image
	-docker stop $(IMAGE_NAME)
	#-docker rm $(IMAGE_NAME)
	touch $@
	docker run --rm --name $(IMAGE_NAME) -d -it \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v $(shell pwd):/build \
	  -p 8080:80 \
		$(IMAGE_NAME):stable
	
enter-dev-docker: start-dev-docker
	docker exec -it $(IMAGE_NAME) bash

dev-image:
	docker build --label $(IMAGE_NAME) --tag $(IMAGE_NAME):stable --network host .
	touch $@


src/app/nextbox: 
	mkdir -p src/app
	cd src && \
		git clone https://github.com/Nitrokey/nextbox-app.git	app
	#git clone git@github.com:Nitrokey/nextbox-app.git nextbox

$(DEBPKG): src/app/nextbox src/nextbox_daemon src/debian/control src/debian/rules src/debian/dirs src/debian/install
	# -us -uc for non signed build
	cd src && \
		fakeroot dpkg-buildpackage -b -us -uc 

#src:
#	dpkg-buildpackage -S



#deb: debian
#	dpkg-buildpackage -rfakeroot -uc -us
#
#deb_dist/nextbox-daemon-$(VERSION):
#	python3 setup.py --command-packages=stdeb.command sdist_dsc --extra-cfg-file stdeb.cfg

clean:
	rm -f dev-image start-dev-docker
	rm -rf src/app
	rm -f nextbox_$(VERSION)-1_all.deb
	rm -f nextbox_$(VERSION)-1_arm64.buildinfo
	rm -f nextbox_$(VERSION)-1_arm64.changes

