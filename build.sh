#!/bin/bash
abort()
{
    echo >&2 '
***************
*** ABORTED ***
***************
'
    echo "An error occurred. Exiting..." >&2
    exit 1
}

trap 'abort' 0
set -e

CARINA_OPTS=""
[[ -n $CARINA_USERNAME ]] && CARINA_OPTS="$CARINA_OPTS --username=$CARINA_USERNAME"
[[ -n $CARINA_APIKEY ]]  && CARINA_OPTS="$CARINA_OPTS --api-key=$CARINA_APIKEY"
[[ -z $CARINA_CLUSTER ]] && CARINA_CLUSTER="mytestcluster"

if [[ $CARINA == 'y' ]]; then
  `carina $CARINA_OPTS env $CARINA_CLUSTER`
  [[ -f ~/.dvm/dvm.sh ]] && source ~/.dvm/dvm.sh && dvm use
fi

#DOCKER_OPTS="-D"
DOCKER_IMG="testimage"
DEVELOPMENT="${DEVELOPMENT:-y}"
[[ -z $DATABASE_NAME ]] && DATABASE_NAME="cake"
[[ -z $DATABASE_USERNAME ]] && DATABASE_USERNAME="root"
[[ -z $DATABASE_PASSWORD ]] && DATABASE_PASSWORD="root"

[[ -z ${DOCKER_DNS} ]] && DOCKER_DNS=" --dns 8.8.8.8 "


if [[ -n $BUILD && $BUILD == "y" ]]; then
  pushd mysql
    echo docker $DOCKER_OPTS build --force-rm --pull --rm -t mysql-test .
    docker $DOCKER_OPTS build --force-rm --pull --rm -t mysql-test .
  popd
  pushd src
    git pull
  popd
  rsync -av src/ html/

  echo docker $DOCKER_OPTS build --force-rm --pull --rm -t $DOCKER_IMG .
  docker $DOCKER_OPTS build --force-rm --pull --rm -t $DOCKER_IMG .
fi

if [[ -n $(docker ps -a|grep "$DOCKER_IMG"|awk '{print $1}') ]]; then
  docker ps -a|grep "$DOCKER_IMG"|awk '{print $1}'|xargs docker rm -f
fi

cat > docker-compose.yml << EOF
mysql:
  image: mysql-test
  environment:
  - MYSQL_DATABASE=$DATABASE_NAME
  - MYSQL_USER=$DATABASE_USERNAME
  - MYSQL_ROOT_PASSWORD=$DATABASE_PASSWORD
test:
  image: $DOCKER_IMG
  ports:
    - "8188:80"
  links:
    - mysql
  environment:
  - MYSQL_DATABASE=$DATABASE_NAME
  - MYSQL_USER=$DATABASE_USERNAME
  - MYSQL_ROOT_PASSWORD=$DATABASE_PASSWORD

EOF
if [[ $CARINA == 'n' ]]; then
  echo "  volumes:" >> docker-compose.yml
  echo "  - ./src:/var/www/html:rw" >> docker-compose.yml
fi

[[ -f "app.default.php" ]] && cp app.default.php src/config/app.php.template
docker-compose run --service-ports -d test

trap : 0

echo >&2 '
************
*** DONE ***
*******
'
