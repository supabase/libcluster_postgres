defmodule LibclusterPostgres.StrategyTest do
  use ExUnit.Case

  alias Postgrex.Notifications

  @config [
    hostname: "localhost",
    username: "postgres",
    password: "postgres",
    database: "postgres",
    port: 5432,
    parameters: [],
    channel_name: "cluster"
  ]

  test "sends psql notification with cluster information to a configured channel name" do
    verify_conn_notification = start_supervised!({Notifications, @config})
    Notifications.listen(verify_conn_notification, @config[:channel_name])

    topologies = [postgres: [strategy: LibclusterPostgres.Strategy, config: @config]]
    start_supervised!({Cluster.Supervisor, [topologies]})

    channel_name = @config[:channel_name]
    node = "#{node()}"

    assert_receive {:notification, _, _, ^channel_name, ^node}, 1000
  end
end
