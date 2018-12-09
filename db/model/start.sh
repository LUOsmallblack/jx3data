#!/bin/sh
# systemctl start docker
# docker pull orientdb
# sh model/start.sh create --name jx3app-model -p 2424:5735 -p 2400:5736
set -e

SCRIPT=$(realpath -s $0)
model_full_path=$(dirname $SCRIPT)
model_dir=$(dirname $0)
mkdir -p "$model_dir/backup" "$model_dir/databases" "$model_dir/config"

create_force() {
  # https://stackoverflow.com/questions/39496564/docker-volume-custom-mount-point
  docker run -d "$@" --user "$(id -u):$(id -g)" \
    --mount type=volume,dst=/orientdb/backup,volume-driver=local,volume-opt=type=none,volume-opt=o=bind,volume-opt=device="$model_full_path/backup" \
    --mount type=volume,dst=/orientdb/databases,volume-driver=local,volume-opt=type=none,volume-opt=o=bind,volume-opt=device="$model_full_path/databases" \
    --mount type=volume,dst=/orientdb/config,volume-driver=local,volume-opt=type=none,volume-opt=o=bind,volume-opt=device="$model_full_path/config" \
    orientdb > "$model_dir/container.id.tmp" && mv "$model_dir/container.id.tmp" "$model_dir/container.id"
  CONTAINER_ID=$(cat "$model_dir/container.id")
  docker inspect --format="{{range .Mounts}}{{println .Name}}{{end}}" "$CONTAINER_ID" > "$model_dir/volumes.id"
  docker stop "$CONTAINER_ID"
}

create() {
  if [[ -f "$model_dir/container.id" ]]; then
    CONTAINER_ID=$(cat "$model_dir/container.id")
    CID=$(docker ps -a -q -f id=${CONTAINER_ID})
    if [ "$CID" ]; then
      echo "$CID already exists"
    else
      echo "'$CONTAINER_ID' seems dead, recreating..."
      create_force "$@"
    fi
  else
    create_force "$@"
  fi
}

start() {
  docker_exec start "$@"
}

stop() {
  docker_exec stop "$@"
}

docker_exec() {
  if [[ -f "$model_dir/container.id" ]]; then
    CONTAINER_ID=$(cat "$model_dir/container.id")
    docker "$@" $CONTAINER_ID
  else
    echo "container not exists, run $0 create to create one"
  fi
}

clean() {
  if [[ -f "$model_dir/container.id" ]]; then
    CONTAINER_ID=$(cat "$model_dir/container.id")
    docker inspect --format="{{range .Mounts}}{{println .Name}}{{end}}" "$CONTAINER_ID" > "$model_dir/volumes.id"
    echo "remove container"
    docker rm "$CONTAINER_ID"
    echo "remove volumes"
    cat "$model_dir/volumes.id" | xargs docker volume rm && rm "$model_dir/volumes.id"
    rm "$model_dir/container.id"
  fi
}

cmd=$1
shift
$cmd "$@"