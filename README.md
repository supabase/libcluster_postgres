# Libcluster Postgres Strategy

Postgres Strategy for [libcluster](https://hexdocs.pm/libcluster/) which is used by Supabase on the [realtime](https://github.com/supabase/realtime) and [supavisor](https://github.com/supabase/supavisor) projects.

It uses Postgres `LISTEN` and `NOTIFICATION` to send the information from a given node and connects them using libcluster.


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
          channel_name: "cluster"
      ],
    ]
  ]
```

To see it in use run the script `./test.sh` in this folder and you will see that both nodes connected as expected and are able to list one another.


## Installation

The package can be installed
by adding `libcluster_postgres` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:libcluster_postgres, "~> 0.1"}]
end
```
