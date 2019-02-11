defmodule Classroom.Upload do

  use Plug.Router

  # This module is a Plug, that also implements it's own plug pipeline, below:

  # Using Plug.Logger for logging request information
  plug Plug.Logger, log: :debug

  plug CORSPlug

  # plug :print_stuff, []

  def print_stuff(conn, _opts) do
    IO.inspect conn
    conn
  end

  # responsible for matching routes
  plug(:match)

  # Using Poison for JSON decoding
  # Note, order of plugs is important, by placing this _after_ the 'match' plug,
  # we will only parse the request AFTER there is a route match.
  # plug(Plug.Parsers, parsers: [:json], json_decoder: Poison)

  plug Plug.Parsers,
    parsers: [:urlencoded, :json, {:multipart, length: 50_000_000}],
    json_decoder: Poison
  # responsible for dispatching responses
  plug(:dispatch)

  # A simple route to test that the server is up
  # Note, all routes must return a connection as per the Plug spec.
  get "/ping" do
    send_resp(conn, 200, "pong!")
  end

  # Handle incoming events, if the payload is the right shape, process the
  # events, otherwise return an error.
  post "/events" do
    {status, body} =
      case conn.body_params do
        %{"events" => events} -> {200, process_events(events)}
        _ -> {422, missing_events()}
      end

    send_resp(conn, status, body)
  end

  post "/upload" do
    IO.puts "reach"
    {status, body} =
      case conn.body_params do
        %{"data" => data, "timestamp" => timestamp, "username" => u, "password" => p} ->
          case Classroom.UserStore.valid_password?(u, p) do
            true -> {200, process_upload(data, timestamp, u)}
            false -> {422, "Invalid username or password"}
          end

        _ ->
          {{422, "Invalid upload format"}}
      end
      send_resp(conn, status, body)
  end

  defp process_upload(data, timestamp, username) do
    IO.inspect {data.filename, timestamp}

    path = "#{Path.expand("~/tmp_upload")}/#{username}/"
    File.mkdir_p! path

    filepath = get_no_repeat_filepath(path, data.filename, 0)

    File.write!(filepath, File.read! data.path)
    Classroom.DrawerStore.notifly_change(username)
    "Upload success"
  end

  defp get_no_repeat_filepath(path, filename, i) do
    new_filename =
      if i > 0 do
        {dot_index, _} = :binary.match filename, "."
        first = String.slice(filename, 0..(dot_index-1))
        second = String.slice(filename, (dot_index+1)..-1)
        first <> " (#{i})." <> second
      else
        filename
      end
    case File.exists?("#{path}#{new_filename}") do # path <> filename
      true -> get_no_repeat_filepath(path, filename, i+1)
      false -> "#{path}#{new_filename}"
    end
  end

  defp process_events(events) when is_list(events) do
    # Do some processing on a list of events
    Poison.encode!(%{response: "Received Events!"})
  end

  defp process_events(_) do
    # If we can't process anything, let them know :)
    Poison.encode!(%{response: "Please Send Some Events!"})
  end

  defp missing_events do
    Poison.encode!(%{error: "Expected Payload: { 'events': [...] }"})
  end

   # A catchall route, 'match' will match no matter the request method,
  # so a response is always returned, even if there is no route to match.
  match _ do
    send_resp(conn, 404, "oops... Nothing here :(")
  end

end
