defmodule Example do
  use Application
  def start(_type, _args) do
    topologies = Application.get_env(:libcluster, :topologies)
    children = [{Cluster.Supervisor, [topologies]}, NodeCheck]
    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
