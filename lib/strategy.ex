defmodule LibclusterPostgres.Strategy do
  @moduledoc """
  A libcluster strategy that uses Postgres LISTEN/NOTIFY to determine the cluster topology.

  This strategy operates by having all nodes in the cluster listen for and send notifications to a shared Postgres channel.

  When a node comes online, it begins to broadcast its name in a "heartbeat" message to the channel. All other nodes that receive this message attempt to connect to it.

  This strategy does not check connectivity between nodes and does not disconnect them

  ## Options

  * `heartbeat_interval` - The interval at which to send heartbeat messages in milliseconds (optional; default: 5_000)
  * `channel_name` - The name of the channel to which nodes will listen and notify (optional; defaults to the result of `Node.get_cookie/0`)
  """
  use GenServer

  alias Cluster.Strategy
  alias Cluster.Logger

  @type config :: [
          hostname: String.t(),
          username: String.t(),
          password: String.t(),
          database: String.t(),
          port: non_neg_integer(),
          parameters: keyword(),
          ssl: boolean(),
          ssl_opts: keyword() | nil,
          socket_options: keyword() | nil,
          channel_name: String.t(),
          heartbeat_interval: non_neg_integer()
        ]

  @type meta :: %{
          opts: fun(),
          conn: Postgrex.conn() | nil,
          conn_notif: pid() | nil,
          heartbeat_ref: reference()
        }

  def start_link(args), do: GenServer.start_link(__MODULE__, args)

  @spec init([%{:config => config(), :meta => any(), optional(any()) => any()}, ...]) ::
          {:ok, %{:config => config(), :meta => meta(), optional(any()) => any()},
           {:continue, :connect}}
  def init([state]) do
    channel_name = Keyword.get(state.config, :channel_name, clean_cookie(Node.get_cookie()))

    opts = [
      hostname: Keyword.fetch!(state.config, :hostname),
      username: Keyword.fetch!(state.config, :username),
      password: Keyword.fetch!(state.config, :password),
      database: Keyword.fetch!(state.config, :database),
      port: Keyword.fetch!(state.config, :port),
      ssl: Keyword.get(state.config, :ssl),
      ssl_opts: Keyword.get(state.config, :ssl_opts),
      socket_options: Keyword.get(state.config, :socket_options, []),
      parameters: Keyword.get(state.config, :parameters, []),
      channel_name: channel_name,
      auto_reconnect: true,
      reconnect_backoff: :timer.seconds(5)
    ]

    config =
      state.config
      |> Keyword.put_new(:channel_name, channel_name)
      |> Keyword.put_new(:heartbeat_interval, :timer.seconds(5))
      |> Keyword.delete(:password)

    meta = %{
      opts: fn -> opts end,
      conn: nil,
      conn_notif: nil,
      heartbeat_ref: make_ref()
    }

    {:ok, %{state | config: config, meta: meta}, {:continue, :connect}}
  end

  def handle_continue(:connect, state) do
    opts = state.meta.opts.()

    with {:ok, conn} <- Postgrex.start_link(opts),
         {:ok, conn_notif} <- Postgrex.Notifications.start_link(opts),
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

  def handle_info(:heartbeat, state) do
    Process.cancel_timer(state.meta.heartbeat_ref)
    Postgrex.query(state.meta.conn, "NOTIFY #{state.config[:channel_name]}, '#{node()}'", [])
    ref = heartbeat(state.config[:heartbeat_interval])
    {:noreply, put_in(state.meta.heartbeat_ref, ref)}
  end

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

  def handle_info(msg, state) do
    Logger.error(state.topology, "Undefined message #{inspect(msg, pretty: true)}")
    {:noreply, state}
  end

  ### Internal functions
  @spec heartbeat(non_neg_integer()) :: reference()
  defp heartbeat(interval) when interval >= 0 do
    Process.send_after(self(), :heartbeat, interval)
  end

  # Replaces all non alphanumeric values into underescore
  defp clean_cookie(cookie) when is_atom(cookie), do: cookie |> Atom.to_string() |> clean_cookie()

  defp clean_cookie(str) when is_binary(str) do
    String.replace(str, ~r/\W/, "_")
  end
end
