#!/bin/bssh
# systemctl start docker
# docker pull orientdb
# bash model/start.sh create --name jx3app-model -p 5735:2424 -p 5736:2480
set -e
shopt -s expand_aliases
alias create-force="create_force"
alias docker-exec="docker_exec"
alias clean-force="clean_force"

SCRIPT=$(realpath -s $0)
model_full_path=$(dirname $SCRIPT)
model_dir=$(dirname $0)
mkdir -p "$model_dir/backup" "$model_dir/databases" "$model_dir/config"

create_user_image() {
  CONTAINER_ID="orientdb_user_$(id -u)"
  docker run --name "$CONTAINER_ID" -it -d "$@" orientdb /bin/sh
  docker exec "$CONTAINER_ID" addgroup -g $(id -g) user
  docker exec "$CONTAINER_ID" adduser -D -u $(id -u) user -G user
  # docker exec "$CONTAINER_ID" addgroup user tty
  # docker exec "$CONTAINER_ID" chown -R user:user /orientdb
  # docker exec "$CONTAINER_ID" mkdir -p /orientdb/backup /orientdb/databases /orientdb/config
  # docker exec "$CONTAINER_ID" chown -R user:user /orientdb/backup /orientdb/databases /orientdb/config
  docker commit --change "USER user" --change "ENV ORIENTDB_PID /orientdb/log/orientdb.pid" \
    --change "CMD server.sh" "$CONTAINER_ID" "orientdb:user_$(id -u)"
  VOLUMES_ID=$(docker inspect --format="{{range .Mounts}}{{println .Name}}{{end}}" "$CONTAINER_ID" | xargs)
  docker rm -f "$CONTAINER_ID" > /dev/null
  docker volume rm $VOLUMES_ID > /dev/null
}

clean_user_image() {
  CONTAINER_ID="orientdb_user_$(id -u)"
  docker rmi -f "orientdb:user_$(id -u)"
  VOLUMES_ID=$(docker inspect --format="{{range .Mounts}}{{println .Name}}{{end}}" "$CONTAINER_ID" | xargs)
  docker rm -f "$CONTAINER_ID"
  docker volume rm $VOLUMES_ID
}

create_force() {
  # workaround for backup and databases owner
  touch "$model_dir/backup/.keep" "$model_dir/databases/.keep"
  # https://stackoverflow.com/questions/39496564/docker-volume-custom-mount-point
  docker create -u "$(id -u):$(id -g)" "$@" \
    --mount type=volume,dst=/orientdb/backup,volume-driver=local,volume-opt=type=none,volume-opt=o=bind,volume-opt=device="$model_full_path/backup" \
    --mount type=volume,dst=/orientdb/databases,volume-driver=local,volume-opt=type=none,volume-opt=o=bind,volume-opt=device="$model_full_path/databases" \
    --mount type=volume,dst=/orientdb/config,volume-driver=local,volume-opt=type=none,volume-opt=o=bind,volume-opt=device="$model_full_path/config" \
    "orientdb:user_$(id -u)" > "$model_dir/container.id.tmp"
  mv "$model_dir/container.id.tmp" "$model_dir/container.id"
  chown "$(id -u):$(id -g)" model/config
  CONTAINER_ID=$(cat "$model_dir/container.id")
  # PID=$(docker inspect --format "{{.State.Pid}}" "$CONTAINER_ID")
  # sed -i '|"Cmd":\["/bin/sh"\]|{s|"Cmd":\["/bin/sh"\]|"Cmd":["server.sh"]|g}; !{q1}' /var/lib/docker/containers/$CONTAINER_ID/config.v2.json
  docker inspect --format="{{range .Mounts}}{{println .Name}}{{end}}" "$CONTAINER_ID" > "$model_dir/volumes.id"
  echo $CONTAINER_ID
}

create() {
  if [[ -f "$model_dir/container.id" ]]; then
    CONTAINER_ID=$(cat "$model_dir/container.id")
    CID=$(docker ps -a -q -f id=${CONTAINER_ID})
    if [ "$CID" ]; then
      echo "$CID already exists"
    else
      echo "'$CONTAINER_ID' seems dead, recreating..."
      create-force "$@"
    fi
  else
    create-force "$@"
  fi
}

start() {
  docker-exec start "$@"
}

stop() {
  docker-exec stop "$@"
}

logs() {
  docker-exec logs "$@"
}

bash() {
  docker-exec exec -it {} /bin/sh "$@"
}

sudo_bash() {
  docker-exec exec -it -u root:root {} /bin/sh "$@"
}

console() {
  docker-exec exec -it {} /orientdb/bin/console.sh
}

docker_exec() {
  if [[ -f "$model_dir/container.id" ]]; then
    CONTAINER_ID=$(cat "$model_dir/container.id")
    if [[ "\t$@\t" =~ "{}" ]]; then
      docker "${@//\{\}/$CONTAINER_ID/}"
    else
      docker "$@" $CONTAINER_ID
    fi
  else
    echo "container not exists, run $0 create to create one"
  fi
}

clean() {
  if [[ -f "$model_dir/container.id.tmp" ]] && [[ ! -f "$model_dir/container.id" ]]; then
    mv "$model_dir/container.id.tmp" "$model_dir/container.id"
  fi
  if [[ -f "$model_dir/container.id" ]]; then
    CONTAINER_ID=$(cat "$model_dir/container.id")
    docker inspect --format="{{range .Mounts}}{{println .Name}}{{end}}" "$CONTAINER_ID" > "$model_dir/volumes.id"
    echo "remove container"
    docker rm -f "$CONTAINER_ID"
    echo "remove volumes"
    cat "$model_dir/volumes.id" | xargs docker volume rm
    rm "$model_dir/volumes.id"
    rm "$model_dir/container.id"
  fi
}

clean_force() {
  clean "$@"
  rm -rf "$model_dir/backup" "$model_dir/databases" "$model_dir/config"
}

cmd=$1
cmd=${cmd//-/_}
shift
$cmd "$@"