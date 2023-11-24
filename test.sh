elixir --no-halt --name node1 integration_test.exs &
pid1=$!

elixir --no-halt --name node2 integration_test.exs &
pid2=$!

sleep 2

kill -9 $pid1
kill -9 $pid2

sleep 1
