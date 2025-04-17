# Libcluster Postgres Strategy

[![Hex version badge](https://img.shields.io/hexpm/v/libcluster_postgres.svg)](https://hex.pm/packages/libcluster_postgres)
[![License badge](https://img.shields.io/hexpm/l/libcluster_postgres.svg)](https://github.com/supabase/libcluster_postgres/blob/main/LICENSE)
[![Elixir CI](https://github.com/supabase/libcluster_postgres/actions/workflows/elixir.yaml/badge.svg)](https://github.com/supabase/libcluster_postgres/actions/workflows/elixir.yaml)
[![ElixirForum](https://img.shields.io/badge/Elixir_Forum-grey)](https://elixirforum.com/t/libcluster-postgres-clustering-strategy-for-libcluster/60053)

Postgres Strategy for [libcluster](https://hexdocs.pm/libcluster/) which is used by Supabase on the [realtime](https://github.com/supabase/realtime), [supavisor](https://github.com/supabase/supavisor) and [logflare](https://github.com/logflare/logflare) projects.

You can test it out by running `docker compose up`

![example.png](https://github.com/supabase/libcluster_postgres/blob/main/example.png?raw=true)

## Installation

The package can be installed
by adding `libcluster_postgres` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:libcluster_postgres, "~> 0.1"}
  ]
end
```

## How to use it

To use it, set your configuration file with the informations for your database:

```elixir
config :libcluster,
  topologies: [
    example: [
      strategy: LibclusterPostgres.Strategy,
      config: [
          hostname: "localhost",
          username: "postgres",
          password: "postgres",
          database: "postgres",
          port: 5432,
          # optional, connection parameters. Defaults to []
          parameters: [],
          # optional, defaults to false
          ssl: true,
          # optional, please refer to the Postgrex docs
          ssl_opts: nil,
          # optional, please refer to the Postgrex docs
          socket_options: nil,
          # optional, defaults to node cookie
          # must be a valid postgres identifier (alphanumeric and underscores only) with valid length
          channel_name: "cluster",
          # optional, heartbeat interval in ms. defaults to 5s
          heartbeat_interval: 10_000
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
### Why do we need a distributed Erlang Cluster?

At Supabase, we use clustering in all of our Elixir projects which include [Logflare](https://github.com/Logflare/logflare), [Supavisor](https://github.com/supabase/supavisor) and [Realtime](https://github.com/supabase/realtime). With multiple servers connected we can load shed, create globally distributed services and provide the best service to our customers so we’re closer to them geographically and to their instances, reducing overall latency.

![Example of Realtime architecture where a customer from CA will connect to the server closest to them and their Supabase instance](https://github.com/supabase/libcluster_postgres/blob/main/realtime_example.png?raw=true)

Example of Realtime architecture where a customer from CA will connect to the server closest to them and their Supabase instance
To achieve a connected cluster, we wanted to be as cloud-agnostic as possible. This makes our self-hosting options more accessible. We don’t want to introduce extra services to solve this single issue - Postgres is the logical way to achieve it.

The other piece of the puzzle was already built by the Erlang community being the defacto library to facilitate the creation of connected Elixir servers: [libcluster](https://github.com/bitwalker/libcluster).

### What is libcluster?

[libcluster](https://github.com/bitwalker/libcluster) is the go-to package for connecting multiple BEAM instances and setting up healing strategies. libcluster provides out-of-the-box strategies and it allows users to define their own strategies by implementing a simple behavior that defines cluster formation and healing according to the supporting service you want to use.

### How did we use Postgres?

Postgres provides an event system using two commands: [NOTIFY](https://www.postgresql.org/docs/current/sql-notify.html) and [LISTEN](https://www.postgresql.org/docs/current/sql-listen.html) so we can use them to propagate events within our Postgres instance.

To use this features, you can use psql itself or any other Postgres client. Start by listening on a specific channel, and then notify to receive a payload.

```markdown
postgres=# LISTEN channel;
LISTEN
postgres=# NOTIFY channel, 'payload';
NOTIFY
Asynchronous notification "channel" with payload "payload" received from server process with PID 326.
```

Now we can replicate the same behavior in Elixir and [Postgrex](https://hex.pm/packages/postgrex) within IEx (Elixir's interactive shell).

```elixir
Mix.install([{:postgrex, "~> 0.17.3"}])
config = [
  hostname: "localhost",
  username: "postgres",
  password: "postgres",
  database: "postgres",
  port: 5432
]
{:ok, db_notification_pid} = Postgrex.Notifications.start_link(config)
Postgrex.Notifications.listen!(db_notification_pid, "channel")
{:ok, db_conn_pid} = Postgrex.start_link(config)
Postgrex.query!(db_conn_pid, "NOTIFY channel, 'payload'", [])

receive do msg -> IO.inspect(msg) end
# Mailbox will have a message with the following content:
# {:notification, #PID<0.223.0>, #Reference<0.57446457.3896770561.212335>, "channel", "test"}
```

### Building the strategy

Using the libcluster `Strategy` behavior, inspired by [this GitHub repository](https://github.com/kevbuchanan/libcluster_postgres) and knowing how `NOTIFY/LISTEN` works, implementing a strategy becomes straightforward:

1. We send a `NOTIFY` to a channel with our `node()` address to a configured channel

```elixir
# lib/cluster/strategy/postgres.ex:52
def handle_continue(:connect, state) do
    with {:ok, conn} <- Postgrex.start_link(state.meta.opts.()),
         {:ok, conn_notif} <- Postgrex.Notifications.start_link(state.meta.opts.()),
         {_, _} <- Postgrex.Notifications.listen(conn_notif, state.config[:channel_name]) do
      Logger.info(state.topology, "Connected to Postgres database")

      meta = %{
        state.meta
        | conn: conn,
          conn_notif: conn_notif,
          heartbeat_ref: heartbeat(0)
      }

      {:noreply, put_in(state.meta, meta)}
    else
      reason ->
        Logger.error(state.topology, "Failed to connect to Postgres: #{inspect(reason)}")
        {:noreply, state}
    end
  end
```

2. We actively listen for new `{:notification, pid, reference, channel, payload}` messages and connect to the node received in the payload

```elixir
# lib/cluster/strategy/postgres.ex:80
def handle_info({:notification, _, _, _, node}, state) do
    node = String.to_atom(node)

    if node != node() do
      topology = state.topology
      Logger.debug(topology, "Trying to connect to node: #{node}")

      case Strategy.connect_nodes(topology, state.connect, state.list_nodes, [node]) do
        :ok -> Logger.debug(topology, "Connected to node: #{node}")
        {:error, _} -> Logger.error(topology, "Failed to connect to node: #{node}")
      end
    end

    {:noreply, state}
  end
```

3. Finally, we configure a heartbeat that is similar to the first message sent for cluster formation so libcluster is capable of heal if need be

```elixir
# lib/cluster/strategy/postgres.ex:73
def handle_info(:heartbeat, state) do
    Process.cancel_timer(state.meta.heartbeat_ref)
    Postgrex.query(state.meta.conn, "NOTIFY #{state.config[:channel_name]}, '#{node()}'", [])
    ref = heartbeat(state.config[:heartbeat_interval])
    {:noreply, put_in(state.meta.heartbeat_ref, ref)}
end
```

These three simple steps allow us to connect as many nodes as needed, regardless of the cloud provider, by utilising something that most projects already have: a Postgres connection.

## Acknowledgements

A special thank you to [@gotbones](https://twitter.com/gotbones) for creating libcluster and [@kevinbuch\_](https://twitter.com/kevinbuch_) for the original inspiration for this strategy.
