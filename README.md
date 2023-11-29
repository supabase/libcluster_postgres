# libcluster Postgres Strategy

[![Hex version badge](https://img.shields.io/hexpm/v/libcluster_postgres.svg)](https://hex.pm/packages/libcluster_postgres)
[![License badge](https://img.shields.io/hexpm/l/libcluster_postgres.svg)](https://github.com/supabase/libcluster_postgres/blob/main/LICENSE)
[![Elixir CI](https://github.com/supabase/libcluster_postgres/actions/workflows/elixir.yaml/badge.svg)](https://github.com/supabase/libcluster_postgres/actions/workflows/elixir.yaml)

Postgres Strategy for [libcluster](https://hexdocs.pm/libcluster/) which is used by Supabase on the [realtime](https://github.com/supabase/realtime), [supavisor](https://github.com/supabase/supavisor) and [logflare](https://github.com/logflare/logflare) projects.

You can test it out by running `docker compose up`

![example.png](example.png)

## Installation

The package can be installed
by adding `libcluster_postgres` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:libcluster_postgres, "~> 0.1"}]
end
```

## How it works

We connect to a Postgres instance using Postgrex. With the [Postgrex.Notifications](https://hexdocs.pm/postgrex/Postgrex.Notifications.html) module we will track for `LISTEN` events on the configured channel. We'll also use `NOTIFY` queries to send the node's information.

## How to use it

To use it, set your configuration file with the informations for your database:

```elixir
config :libcluster,
  topologies: [
    example: [
      strategy: Cluster.Strategy.Postgres,
      config: [
          hostname: "localhost",
          username: "postgres",
          password: "postgres",
          database: "postgres",
          port: 5432,
          parameters: [],
          # optional, defaults to node cookie
          channel_name: "cluster"
      ],
    ]
  ]
```

Then add it to your supervision tree:

```elixir
defmodule MyApp do
  use Application

  def start(_type, _args) do
    topologies = Application.get_env(:libcluster, :topologies)
    children = [
      # ...
      {Cluster.Supervisor, [topologies]}
      # ...
    ]
    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
```

## Acknowledgements

A special thank you to [@gotbones](https://twitter.com/gotbones) for creating libcluster and [@kevinbuch\_](https://twitter.com/kevinbuch_) for the original inspiration for this strategy.
