# Jx3App

## Prepare DB
Postgresql should be installed in order to be served as storage backend.
```shell
# after install and start the postgresql
createdb jx3app
```
You should add
```elixir
config :jx3app, Jx3App.Model.Repo,
  database: "jx3app",
  hostname: "localhost",
  port: 5733
```
to your `config/secret.exs`

Don't forget including
```elixir
use Mix.Config
```
at the top of `config/secret.exs`

## Prepare JX3 account
Add to your `config/secret.exs`
```elixir
config :jx3app, Jx3App.API,
  username: "username",
  password: "password"
```

## Compilation
Elixir should be installed in order to compile and run the code.
```shell
# install dependencies
mix deps.get
# create databses in postgresql
mix ecto.create
# create schema in postgresql (or ecto.rollback to roll back)
mix ecto.migrate
# test
mix test
# release
MIX_ENV=prod mix release
# run
_build/prod/rel/jx3app/bin/jx3app start --role all --crawler-mode all
```

## Useful commands

1. postgresql
    ```shell
    pg_ctl -D data -o "--locale=en_US.UTF-8" initdb
    # change unix_socket_directories in db/data/postgresql.conf if necessary
    # start/stop/restart
    pg_ctl -D data -o "-p5733" -l postgres.log start
    # user mix ecto.create/ecto.drop instead
    # createdb/dropdb -p5733 jx3app
    pg_dump -a -Fc -t roles -t persons -hlocalhost -p5733 jx3app > roles.sql
    pg_restore -a -hlocalhost -p5733 -djx3app roles.sql # --disable-triggers
    # use "-h/tmp/postgresql" to specific pid folder, or use "-hlocalhost" when connect
    psql -p5733 jx3app # -s (step)

    # inside jx3app, create role with name as the user tp run apache-spark
    jx3app# CREATE ROLE "apache-spark" LOGIN;
    ```

2. redis
    ```shell
    redis-server cache/redis.conf
    redis-cli -p 5734
    # redis-cli -p 5734 flushdb
    redis-cli -p 5734 shutdown
    ```

3. apache-spark
    ```shell
    systemctl start apache-spark-master
    systemctl start apache-spark-slave@localhost:7077
    ```

4. orientdb
    ```shell
    docker pull orientdb
    model/start.sh create --name jx3app-model -p 5735:2424 -p 5736:2480
    # start/stop/clean/logs/console
    model/start.sh start
    ```
