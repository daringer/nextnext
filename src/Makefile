
all: app/nextbox/js/nextbox.js



app/nextbox/js/nextbox.js: app/nextbox/node_modules
	cd app/nextbox && \
		make build-js

app/nextbox/node_modules: app/nextbox
	cd app/nextbox && \
		npm install

app/nextbox: 
	mkdir -p src
	cd src && \
		git clone https://github.com/Nitrokey/nextbox-app.git	app


clean:
	make -C app/nextbox clean clean-dev


