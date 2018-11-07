defmodule Classroom do
  use Application

  def start(_type, _args) do
    IO.puts("my otp application is starting")

    routes = [
      {
        :_,
        [
          {"/", Classroom.User, nil}
        ]
      }
    ]

    router = :cowboy_router.compile(routes)

    :cowboy.start_clear(
      :http,
      [port: 4000],
      %{
        env: %{
          dispatch: router
        }
      }
    )

    children = [
      {Classroom.PasswordStore, users: %{"dev" => "dev", "dev2" => "dev2"}},
      Classroom.ActiveUsers,
      #      Classroom.Whiteboard,
      {Classroom.ClassStore, classes: []},
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
