import Config

config :logger, :console,
  format: "[$level][node:$node] $message\n", metadata: [:node]

config :libcluster, topologies: [
  postgres: [
    strategy: Cluster.Strategy.Postgres,
    config: [
      hostname: "db",
      username: "postgres",
      password: "postgres",
      database: "postgres",
      port: 5432,
      parameters: [],
      channel_name: "cluster"
    ]
  ]
]
