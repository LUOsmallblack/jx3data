# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure your application as:
#
#     config :jx3replay, key: :value
#
# and access this configuration in your application as:
#
#     Application.get_env(:jx3replay, :key)
#
# You can also configure a 3rd-party app:
#
#     config :logger, level: :info
#

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
#     import_config "#{Mix.env}.exs"

config :logger,
  backends: [{LoggerFileBackend, :error_log}, :console]
config :logger, :console,
  level: :info
config :logger, :error_log,
  level: :error,
  path: "log/elixir.log"

config :jx3replay, Model.Repo,
  adapter: Ecto.Adapters.Postgres,
  loggers: [{Model.Repo.LogEntry, :log, []}]

config :jx3replay,
  ecto_repos: [Model.Repo]

config :jx3replay, Cache,
  redis: []

config :jx3replay, Jx3APP,
  username: "",
  password: ""

if File.exists?("#{Mix.env}.exs") do import_config "#{Mix.env}.exs" end
import_config "secret.exs"
