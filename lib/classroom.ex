defmodule Classroom do
  use Application

  require Logger

  def start(_type, _args) do
    port = 8500

    Classroom.Websocket.start(port, Classroom.Connection, nil)

    Logger.info("Listening on port #{port}")

    children = [
      {Classroom.UserStore, users: %{"dev" => "dev", "dev2" => "dev2"}},
      Classroom.ActiveUsers,
      Classroom.ActiveClasses.Registry,
      Classroom.ActiveClasses,
      Classroom.ActiveWhiteboard.Registry,
      Classroom.ActiveWhiteboard,
      Classroom.ActiveGroupWhiteboard.Registry,
      Classroom.ActiveGroupWhiteboard,
      Classroom.DrawerStore,
      {Classroom.ClassStore, classes: []},
      {Plug.Cowboy, scheme: :http, plug: Classroom.Upload, options: [port: 8600]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
