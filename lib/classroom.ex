defmodule Classroom do
  use Application

  require Logger

  def start(_type, _args) do
    port = 8500

    routes = [
      {
        :_,
        [
          {"/", Classroom.User, nil}
        ]
      }
    ]

    router = :cowboy_router.compile(routes)

    {:ok, _} =
      :cowboy.start_clear(
        :http,
        [port: port],
        %{
          env: %{
            dispatch: router
          }
        }
      )

    Application.ensure_all_started(:gun)

    Logger.info("Listening on port #{port}")

    children = [
      {Classroom.UserStore, users: %{"dev" => "dev", "dev2" => "dev2"}},
      Classroom.ActiveUsers,
      Classroom.ActiveClasses.Registry,
      Classroom.ActiveClasses,
      #      Classroom.Whiteboard,
      {Classroom.ClassStore, classes: []},
      {Plug.Cowboy, scheme: :http, plug: Classroom.Upload, options: [port: 8888]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
