defmodule Classroom.Upload.Router do
  use Plug.Router

  plug :match
  plug :dispatch

  get "/" do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, """
    <!doctype html>
    <html>
    <head>
      <style>
        .upload-btn-wrapper {
          position: absolute;
          margin-left: auto;
          margin-right: auto;
          top: 50%;
          left: 50%;
          transform: translate(-50%, -50%);
          overflow: hidden;;
          display: inline-block;
        }
        .btn {
          border: 2px solid gray;
          color: gray;
          padding: 8px 20px;
          border-radius: 8px;
          font-size: 20px;
          font-weight: bold;;
        }
        .upload-btn-wrapper input[type=file]{
          font-size: 100px;
          position: absolute;
          left: 0;
          top: 0;
          opacity: 0;
        }
      </style>
    </head>
    <body>
      <form method="POST" action="/" enctype="multipart/form-data">
        <div class="upload-btn-wrapper">
          <button class="btn">Upload a file</button>
          <input type="file" name="file" onchange="this.form.submit()" required>
        </div>
      </form>
    </body>
    """)
  end

  post "/" do
    %{"file" => file} = conn.body_params
    IO.inspect file
    # content = File.read!(file.path)
    # send_resp(conn, 200, "post request params: #{inspect content}")
    redirect("/", conn)
  end

  match _ do
    # Plug.Conn.configure_session(conn, :renew)
    # Plug.Conn.fetch_session(conn)
    # Plug.Conn.get_session(conn, :username)
    redirect("/", conn)
  end

  defp redirect(location, conn) do # redirect_homt(conn) :: conn
    conn
    |> put_resp_header("location", location)
    |> send_resp(301, "")
  end
end
