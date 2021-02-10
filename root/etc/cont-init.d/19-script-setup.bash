#!/usr/bin/with-contenv bash

# create scripts directory if missing
if [ ! -d "/config/scripts" ]; then
	mkdir -p "/config/scripts"
else
	echo "Updating scripts..."
	rm -rf /config/scripts/*
fi

if [ -d "/config/scripts" ]; then
	cp /scripts/* /config/scripts/
fi

if [ ! -d "/config/list/deemix" ]; then
	mkdir -p "/config/list/deemix"
fi

# set permissions
chown -R abc:abc "/config"
chown -R abc:abc "/scripts"
chmod 0777 -R "/scripts"
chmod 0777 -R "/config"

echo "Complete..."

exit $?
