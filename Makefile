VERSION=0.0.2
DEBPKG=nextbox_$(VERSION)-1_all.deb


all: src/app/nextbox $(DEBPKG) 
	# done

copy-dev:
	scp $(DEBPKG) nextuser@192.168.10.50:/tmp
	ssh root@192.168.10.50 -- dpkg -i /tmp/$(DEBPKG)

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
	rm nextbox_$(VERSION)-1_all.deb
	rm nextbox_$(VERSION)-1_arm64.buildinfo
	rm nextbox_$(VERSION)-1_arm64.changes

