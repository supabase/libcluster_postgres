defmodule NodeCheck do
  use GenServer
  require Logger
  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)
  def init(_) do
    Process.send_after(self(), :check, 1_000)
    {:ok, []}
  end

  def handle_info(:check, state) do
    Logger.info("Connected nodes: #{inspect(Node.list())}", %{node: node()})
    Process.send_after(self(), :check, 1_000)

    {:noreply, state}
  end
end
