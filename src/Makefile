
all: app/nextbox/js/nextbox-main.js 

dev: 
	cd app/nextbox && \
		make build-js

install: app/nextbox/js/nextbox-main.js
	mkdir -p debian/nextbox/srv/nextcloud/custom_apps
	cp -r app/nextbox debian/nextbox/srv/nextcloud/custom_apps
	rm -rf debian/nextbox/srv/nextcloud/custom_apps/nextbox/node_modules
	rm -rf debian/nextbox/srv/nextcloud/custom_apps/nextbox/vendor
	rm -rf debian/nextbox/srv/nextcloud/custom_apps/nextbox/build

app/nextbox/js/nextbox-main.js: app/nextbox/node_modules app/nextbox/src/
	cd app/nextbox && \
		make build-js-production

app/nextbox/node_modules: app/nextbox
	cd app/nextbox && \
		npm install

app/nextbox: 
	git clone https://github.com/Nitrokey/nextbox-app.git	app


clean:
	make -C app/nextbox clean clean-dev


