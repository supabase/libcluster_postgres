defmodule LibclusterPostgres.StrategyTest do
  use ExUnit.Case, async: false

  alias Postgrex.Notifications

  @config [
    hostname: "localhost",
    username: "postgres",
    password: "postgres",
    database: "postgres",
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

  describe "connect via cookie" do
    @cookie_config Keyword.put(@config, :channel_name, "my_random__123_long_cookie")
    @cookie :"my-random-#123-long-cookie"
    setup do
      cookie = Node.get_cookie()
      Node.set_cookie(Node.self(), @cookie)

      on_exit(fn ->
        Node.set_cookie(Node.self(), cookie)
      end)
    end

    test "cookie default connection" do
      verify_conn_notification = start_supervised!({Notifications, @cookie_config})
      Notifications.listen(verify_conn_notification, @cookie_config[:channel_name])

      config = Keyword.delete(@cookie_config, :channel_name)
      topologies = [postgres: [strategy: LibclusterPostgres.Strategy, config: config]]
      start_supervised!({Cluster.Supervisor, [topologies]})

      channel_name = @cookie_config[:channel_name]
      node = "#{node()}"
      assert_receive {:notification, _, _, ^channel_name, ^node}, 1000
    end
  end
end
