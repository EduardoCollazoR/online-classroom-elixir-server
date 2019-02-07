defmodule Classroom.Connection do
  use Classroom.Handler.Protocol
  require Logger

  @type msg_type :: atom()
  @type params :: term()
  @type state :: term()

  @callback handle_info(msg_type(), params(), state()) ::
    {:noreply, state()} |
    {:event, msg_type(), params(), state()} |
    {:stop, state()}

    @callback handle_cast(msg_type(), params(), state()) ::
    {:noreply, state()} |
    {:event, msg_type(), params(), state()} |
    {:stop, state()}

  '''
  TODO

  -need protocol
  -ensure all functions are called correctly (from other modules or from client)
  '''

  @impl true
  def handle_info(:update_exist_peer_conn, exist_peer_conn, state = %{identity: :user, at: {owner, class_name}}) do
    {:event, :update_exist_peer_conn, %{result: exist_peer_conn}, state}
  end

  @impl true
  def handle_info(:got_media, stream_owner, state = %{identity: :user}) do
    {:event, :got_media, stream_owner, state}
  end

  @impl true
  def handle_info(:candidate, [stream_owner, candidate, sender_name], state = %{identity: :user}) do
    {:event, :candidate, {stream_owner: stream_owner, from: sender_name, candidate: candidate}, state}
  end

  @impl true
  def handle_info(msg_type, params, state) do
    Logger.info("Server sending message to invalid client, msg_type: #{msg_type}")
    {:noreply, state} # use stop in production
  end

  @impl true
  def handle_cast("got_media", _, state = %{at: {owner, class_name}}) do
    :ok = Classroom.Class.handle_got_media(owner, class_name)
    {:noreply, state}
  end

  @impl true
  def handle_cast(
      "candidate",
      %{"candidate" => candidate, "to" => to, "stream_owner" => stream_owner},
      state = %{at: {owner, class_name}}) do
    :ok = Classroom.Class.handle_candidate(owner, class_name, stream_owner, candidate, to)
    {:noreply, state}
  end

  @impl true
  def handle_cast(msg_type, params, state) do
    Logger.info("Server received invalid cast message, msg_type: #{msg_type}")
    {:noreply, state} # use stop in production
  end

end
