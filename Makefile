VERSION=0.0.2
DEBPKG=nextbox_$(VERSION)-1_all.deb

IMAGE_NAME=dev-docker

all: src/app/nextbox $(DEBPKG) 
	# done

copy-dev:
	scp $(DEBPKG) nextuser@192.168.10.50:/tmp
	ssh root@192.168.10.50 -- dpkg -i /tmp/$(DEBPKG)

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
	wget https://github.com/Nitrokey/nextbox-app/releases/download/v0.3.0/nextbox-0.3.0.tar.gz
	mkdir -p src/app
	tar xvf nextbox-0.3.0.tar.gz -C src/app 

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
	rm -f nextbox_$(VERSION)-1_all.deb
	rm -f nextbox_$(VERSION)-1_arm64.buildinfo
	rm -f nextbox_$(VERSION)-1_arm64.changes

