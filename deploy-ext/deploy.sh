#!/bin/bash

echo "deployment docker-v.1.0.4 - app:$APPNAME"

echo "prepare deploy destination - app:$APPNAME"
mkdir -p $APPPATH/$APPNAME/src
mkdir -p $APPPATH/$APPNAME/vols
mkdir -p $APPPATH/$APPNAME/img
# stop latest container
cd $APPPATH/$APPNAME/img/

echo "pull last commit - app:$APPNAME"
cd $APPPATH/$APPNAME/src
git reset --hard
git pull

echo "set environment - app:$APPNAME"
cd $APPPATH/$APPNAME/src/deploy-ext
docker-compose stop && docker-compose rm -f
echo $ENV_DEPLOY | base64 --decode > .envorig
envsubst < .envorig > .env
set -a
source .env
envsubst '${APPNAME},${SSL_MODE},${NGINX_PORT}, ${SSL_CMN}' < app-tpl.conf > app.conf

if [[ $MODE_ENV = 'production' ]]
then
  echo "set ssl mode - app:$APPNAME"
  grep 'SSLKEY=' .env > sslcert/temp1.key && sed -r 's/^SSLKEY=//' sslcert/temp1.key > sslcert/temp2.key && base64 --decode sslcert/temp2.key > sslcert/server.key && rm -rf sslcert/temp*
  grep 'SSLCERT=' .env > sslcert/temp1.key && sed -r 's/^SSLCERT=//' sslcert/temp1.key > sslcert/temp2.key && base64 --decode sslcert/temp2.key > sslcert/ssl-bundle.crt && rm -rf sslcert/temp*
  cat <<EOT >> app.conf
    server {
        listen 80 default_server;
        server_name _;
        return 301 https://\$host\$request_uri;
    }
EOT
else
  echo "set only http mode - app:$APPNAME"
fi

envsubst < docker-compose-tpl.yml > docker-compose.yml

echo "cleanup - app:$APPNAME"
docker pull $IMAGEAPP
docker pull $IMAGESERVER
cp -rf docker-compose.yml $APPPATH/$APPNAME/img/docker-compose.yml
cp -rf docker-compose.yml $APPPATH/$APPNAME/img/docker-compose.yml.$COMMIT


echo "build container - app:$APPNAME"
docker-compose -f docker-compose.yml up -d --build
docker info
docker container ls -a
docker-compose ps

echo "update volumes - app:$APPNAME"
cp -rf $APPPATH/$APPNAME/src/* $APPPATH/$APPNAME/vols/
rm -rf $APPPATH/$APPNAME/vols/deploy-ext
cd $APPPATH/$APPNAME/vols/
# custom rw folder for uploads file
chmod -R 0777 application/views/cache
chmod -R 0777 uploads
chmod -R 0777 uploads/landing_page_manager
chmod -R 0777 uploads/images
docker run -v deploy-ext_$APPNAME-volcodes:/data --name $APPNAME-volcodes busybox true
docker cp . $APPNAME-volcodes:/data
docker rm $APPNAME-volcodes

echo "finish - app:$APPNAME"
