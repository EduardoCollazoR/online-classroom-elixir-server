defmodule Classroom.Upload do
  use Plug.Builder

  plug Plug.Logger, log: :debug

  plug :put_secret_key_base

  # plug Plug.Session, store: :cookie,
  #   key: "upload_session",
  #   encryption_salt: "upload page signing salt",
  #   signing_salt: "cookie store signing salt",
  #   key_length: 64,
  #   log: :debug

  plug Plug.Parsers, parsers: [:urlencoded, :multipart]

  # plug(
  #   Plug.Static,
  #   at: "/",
  #   from: "/static"
  # )

  plug Classroom.Upload.Router

  def put_secret_key_base(conn, _) do
    put_in conn.secret_key_base, "sernckbejkkjbakajcesljhflksjcnbasceskjcsecert"
  end

end
