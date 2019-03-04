defmodule Classroom.Signaling do
  use Classroom.Signaling.Protocol
  require Logger

  @impl true
  def handle_info(:update_exist_peer_conn, exist_peer_conn, state = %{identity: :user, at: {owner, class_name}}) do
    {:event, :get_exist_peer_conn, %{result: exist_peer_conn}, state}
  end

  @impl true
  def handle_info(:got_media, stream_owner, state = %{identity: :user}) do
    {:event, :got_media, stream_owner, state}
  end

  @impl true
  def handle_info(:request_offer, sender_name, state = %{identity: :user}) do
    {:event, :request_offer, sender_name, state}
  end

  @impl true
  def handle_info(:offer, [stream_owner, offer, sender_name], state = %{identity: :user}) do
    {:event, :offer, %{stream_owner: stream_owner, from: sender_name, offer: offer}, state}
  end

  @impl true
  def handle_info(:answer, [stream_owner, answer, sender_name], state = %{identity: :user}) do
    {:event, :answer, %{stream_owner: stream_owner, from: sender_name, answer: answer}, state}
  end

  @impl true
  def handle_info(:candidate, [stream_owner, candidate, sender_name], state = %{identity: :user}) do
    {:event, :candidate, %{stream_owner: stream_owner, from: sender_name, candidate: candidate}, state}
  end

  @impl true
  def handle_info(msg_type, _params, state) do
    Logger.info("Signaling server sending message to invalid client, msg_type: #{msg_type}")
    {:noreply, state} # use stop in production
  end

  @impl true
  def handle_cast("got_media", _, state = %{at: {owner, class_name}}) do
    :ok = Classroom.Class.handle_got_media(owner, class_name)
    {:noreply, state}
  end

  @impl true
  def handle_cast("request_offer", to, state = %{at: {owner, class_name}}) do
    :ok = Classroom.Class.handle_request_offer(owner, class_name, to)
    {:noreply, state}
  end

  @impl true
  def handle_cast(
      "offer",
      %{"stream_owner" => stream_owner, "offer" => offer, "to" => to},
      state = %{at: {owner, class_name}}) do
    :ok = Classroom.Class.handle_offer(owner, class_name, stream_owner, offer, to)
    {:noreply, state}
  end

  @impl true
  def handle_cast(
      "answer",
      %{"stream_owner" => stream_owner, "answer" => answer, "to" => to},
      state = %{at: {owner, class_name}}) do
    :ok = Classroom.Class.handle_answer(owner, class_name, stream_owner, answer, to)
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
  def handle_cast(msg_type, _params, state) do
    Logger.info("Signaling server received invalid cast message, msg_type: #{msg_type}")
    {:noreply, state} # use stop in production
  end

  @impl true
  def handle_call(msg_type, _params, state) do
    Logger.info("Signaling server received invalid call message, msg_type: #{msg_type}")
    # {:noreply, state} # use stop in production
    {:reply, %{type: :unexpected}, state}
  end

end
