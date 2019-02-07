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

  '''
  TODO

  -need protocol
  -ensure all functions are called correctly (from other modules or from client)
  '''

  @impl true
  # TODO change _
  def handle_info(:get_exist_peer_conn, state = %{identity: :user, at: {owner, class_name}}) do
    {:reply, %{result: Classroom.Class.get_exist_peer_conn(owner, class_name)}, state}
  end

  @impl true #Cannot check
  def handle_info({:broadcast_message, message}, state = %{identity: :user}) do
    {:event, message, state}
  end

  impl true
  def handle_info(:noti_got_media, stream_owner, state = %{identity: :user}) do
    {:event, :noti_got_media, stream_owner, state}
  end

  @impl true
  def handle_info(msg_type, state) do
    Logger.debug("Server sending message to invalid client, msg_type: #{msg_type}")
    {:noreply, state}
  end

  @impl true
  def handle_cast("class_direct_message", message, state = %{at: {owner, class_name}}) do
    :ok = Classroom.Class.handle_class_direct_message(owner, class_name, message)
    {:noreply, state}
  end

  @impl true
  def handle_cast("got_media", _, state = %{at: {owner, class_name}}) do
    :ok = Classroom.Class.handle_got_media(owner, class_name)
    {:noreply, state}
  end

end
