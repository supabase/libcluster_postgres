Mix.install([:postgrex, :libcluster, {:libcluster_postgres, path: "./"}])
require Logger

config = [
  hostname: "localhost",
  username: "postgres",
  password: "postgres",
  database: "postgres",
  port: 5432,
  parameters: [],
  channel_name: "cluster"
]

topologies = [postgres: [strategy: Cluster.Strategy.Postgres, config: config]]

Supervisor.start_link([{Cluster.Supervisor, [topologies]}], strategy: :one_for_one)

defmodule Loop do
  def start do
    :timer.sleep(500)
    Logger.info("Connected to node #{inspect(node())}: #{inspect(Node.list())}", %{node: node()})
    start()
  end
end

Loop.start()
