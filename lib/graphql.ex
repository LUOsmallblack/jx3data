defmodule Jx3App.GraphQL do
  defmodule Resolvers do
    import Ecto.Query
    alias Jx3App.Model

    def apply_prefix(l, prefix) when is_list(l) do
      Enum.map(l, &apply_prefix(&1, prefix))
    end
    def apply_prefix(%{__meta__: meta} = o, prefix) do
      %{o | __meta__: %{meta | prefix: prefix}}
    end

    def complexity(%{limit: limit}, child_complexity) do
      limit * child_complexity
    end

    def complexity(_, child_complexity) do
      1 + child_complexity
    end

    def dataloader(source, ord \\ :one, opts \\ [])
    def dataloader(source, ord, opts) when ord in [:one, :many] do
      dataloader(source, {ord, nil}, opts)
    end
    def dataloader(source, {ord, key}, opts) do
      fn %schema{__meta__: meta} = o, _, %{context: %{loader: loader}} = res ->
        key = key || res.definition.schema_node.identifier
        # https://hexdocs.pm/ecto/Ecto.Schema.Metadata.html
        prefix = Keyword.get(opts, :prefix, meta.prefix)
        {queryable, related_key, value} = case schema.__schema__(:association, key) do
          %{queryable: queryable, owner_key: owner_key, related_key: related_key} ->
            owner_key = owner_key || key <> "_id"
            %{^owner_key => value} = o
            {queryable, related_key, value}
        end
        batch_key = {ord, prefix && Ecto.Query.subquery(queryable, prefix: prefix) || queryable}
        loader |> Dataloader.load(source, batch_key, [{related_key, value}])
        |> Absinthe.Resolution.Helpers.on_load(fn loader ->
          result = Dataloader.get(loader, source, batch_key, [{related_key, value}]) |> apply_prefix(prefix)
          {:ok, result} end)
      end
    end

    def roles(_, args, _) do
      limit = args[:limit] || 200
      offset = args[:offset] || 0
      roles = from(r in Model.Role,
        limit: ^limit,
        offset: ^offset)
        |> Jx3App.Model.Dynamic.query(args)
        |> Model.Repo.all
      {:ok, roles}
    end

    def role(_, args, _) do
      role_id = args[:role_id]
      role = Model.Repo.get(Model.Role, role_id)
      {:ok, role}
    end

    def match_roles(%{role_id: role_id, match_type: match_type}, args, _) do
      limit = args[:limit] || 20
      offset = args[:offset] || 0
      match_roles = Model.Repo.all(
        from(m in Model.MatchRole,
          where: m.role_id == ^role_id,
          limit: ^limit,
          offset: ^offset),
        prefix: Model.Match.prefix(match_type))
      {:ok, match_roles}
    end

    def matches(_, args, _) do
      limit = args[:limit] || 20
      offset = args[:offset] || 0
      matches = Model.Repo.all(
        from(m in Model.Match,
          order_by: [fragment("? DESC NULLS LAST", m.start_time)],
          limit: ^limit,
          offset: ^offset),
        prefix: Model.Match.prefix("3c"))
      {:ok, matches}
    end
  end

  defmodule Role do
    use Absinthe.Schema.Notation
    import Absinthe.Resolution.Helpers, only: [dataloader: 1, dataloader: 2]

    object :person do
      field :person_id, :string
      field :name, :string
      field :roles, list_of(:role), resolve: dataloader(:db)
    end

    object :role do
      field :global_id, :string
      field :name, :string
      field :role_id, :integer
      field :zone, :string
      field :server, :string
      field :camp, :string
      field :force, :string
      field :body_type, :string
      field :person, :person, resolve: dataloader(:db)
      field :scores, list_of(:score), resolve: dataloader(:db, :performances)
    end

    object :score do
      field :match_type, :string
      field :role_id, :string
      field :score, :integer
      field :grade, :integer
      field :ranking, :integer
      field :total_count, :integer
      field :win_count, :integer
      field :mvp_count, :integer
      field :role, :role, resolve: dataloader(:db)
      field :matches, list_of(:match_role) do
        arg :limit, :integer, default_value: 200
        arg :offset, :integer, default_value: 0
        arg :where, :string
        complexity &Resolvers.complexity/2
        resolve &Resolvers.match_roles/3
      end
    end
  end

  defmodule Match do
    use Absinthe.Schema.Notation
    import Absinthe.Resolution.Helpers, only: [dataloader: 1, dataloader: 3]

    object :match do
      field :start_time, :integer
      field :duration, :integer
      field :pvp_type, :integer
      field :map, :integer
      field :grade, :integer
      field :team1_score, :integer
      field :team2_score, :integer
      field :team1_kungfu, list_of(:integer)
      field :team2_kungfu, list_of(:integer)
      field :winner, :integer
      field :role_ids, list_of(:string)
      field :roles, list_of(:match_role), resolve: dataloader(:db)
    end

    object :match_role do
      field :match_id, :string
      field :kungfu, :integer
      field :score, :integer
      field :score2, :integer
      field :ranking, :integer
      field :equip_score, :integer
      field :equip_addition_score, :integer
      field :max_hp, :integer
      field :metrics_version, :integer
      field :metrics, list_of(:float)
      field :equips, list_of(:integer)
      field :talents, list_of(:integer)
      field :attrs_version, :integer
      field :attrs, list_of(:float)
      field :match, :match, resolve: dataloader(:db)
      field :role, :role, resolve: dataloader(:db_public, :role, args: %{prefix: "public"})
    end
  end

  defmodule Schema do
    use Absinthe.Schema
    import_types Role
    import_types Match

    def context(ctx) do
      source = Dataloader.Ecto.new(Jx3App.Model.Repo, query: &Jx3App.Model.Dynamic.query/2)
      # TODO: https://github.com/absinthe-graphql/dataloader/issues/61
      source2 = Dataloader.Ecto.new(Jx3App.Model.Repo, query: &Jx3App.Model.Dynamic.query/2, repo_opts: [prefix: "public"])
      loader = Dataloader.new |> Dataloader.add_source(:db, source) |> Dataloader.add_source(:db_public, source2)
      Map.put(ctx, :loader, loader)
    end

    def plugins do
      [Absinthe.Middleware.Dataloader] ++ Absinthe.Plugin.defaults()
    end

    query do
      @desc "Get all roles"
      field :roles, list_of(:role) do
        arg :limit, :integer, default_value: 200
        arg :offset, :integer, default_value: 0
        arg :where, :string
        complexity &Resolvers.complexity/2
        resolve &Resolvers.roles/3
      end

      @desc "Get role use role_id"
      field :role, :role do
        arg :role_id, :string
        arg :where, :string
        complexity &Resolvers.complexity/2
        resolve &Resolvers.role/3
      end

      @desc "Get all matches"
      field :matches, list_of(:match) do
        arg :limit, :integer, default_value: 20
        arg :offset, :integer, default_value: 0
        arg :where, :string
        complexity &Resolvers.complexity/2
        resolve &Resolvers.matches/3
      end
    end
  end
end
