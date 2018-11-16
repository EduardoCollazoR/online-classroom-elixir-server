defmodule ClassroomTest do
  use ExUnit.Case

  setup_all do
    {:ok, state: :state}
  end

  test "client login" do
    # hostname = 'localhost'
    hostname = 'overcoded.tk'
    port = 8500
    {:ok, conn}  = :gun.open(hostname, port)
    {:ok, :http} = :gun.await_up(conn)
    :gun.ws_upgrade(conn, "/websocket")
    assert_received {:gun_ws_upgrade, ^conn, :ok, _}

  end


end
