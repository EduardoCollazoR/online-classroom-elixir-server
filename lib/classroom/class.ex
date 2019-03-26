defmodule Classroom.Class do
  use GenServer

  require Logger

  # API

  def start_link({owner, class_name}) do
    # , debug: [:trace])
    GenServer.start_link(__MODULE__, [{owner, class_name}], name: via_tuple(owner, class_name))
  end

  def join(owner, class_name) do
    GenServer.call(via_tuple(owner, class_name), {:join, self()})
  end

  def leave(owner, class_name) do
    GenServer.call(via_tuple(owner, class_name), {:leave, self()})
  end

  def get_session_user(owner, class_name) do
    GenServer.call(via_tuple(owner, class_name), :get_session_user)
  end

  def handle_class_direct_message(owner, class_name, message) do
    GenServer.call(via_tuple(owner, class_name), {:handle_class_direct_message, message, self()})
  end

  def handle_request_offer(owner, class_name, to) do
    GenServer.call(
      via_tuple(owner, class_name),
      {:handle_request_offer, to, self()}
    )
  end

  def handle_offer(owner, class_name, stream_owner, offer, to) do
    GenServer.call(
      via_tuple(owner, class_name),
      {:handle_offer, stream_owner, offer, to, self()}
    )
  end

  def handle_answer(owner, class_name, stream_owner, answer, to) do
    GenServer.call(
      via_tuple(owner, class_name),
      {:handle_answer, stream_owner, answer, to, self()}
    )
  end

  def handle_got_media(owner, class_name) do
    GenServer.call(
      via_tuple(owner, class_name),
      {:handle_got_media, self()}
    )
  end

  def handle_candidate(owner, class_name, stream_owner, candidate, to) do
    GenServer.call(via_tuple(owner, class_name), {:handle_candidate, stream_owner, candidate, to, self()})
  end

  def handle_action(owner, class_name, action) do
    GenServer.call(via_tuple(owner, class_name), {:handle_action, action, self()})
  end

  defp via_tuple(owner, class_name) do
    # {:via, module_name, term}
    {:via, Classroom.ActiveClasses.Registry, {owner, class_name}}
  end

  # Server

  def init(_args) do
    # %{ pid => %{pc: true/false}}
    {:ok, %{}}
  end

  def handle_info({:DOWN, _, :process, pid, _}, state) do
    leave_class(pid, state)
    {:noreply, Map.delete(state, pid)}
  end

  def handle_call({:leave, pid}, _from, state) do
    leave_class(pid, state)
    %{ref: ref} = state |> Map.fetch!(pid)
    Process.demonitor(ref)
    {:reply, :ok, Map.delete(state, pid)}
  end

  def handle_call({:join, pid}, _from, state) do
    case Map.has_key?(state, pid) do
      true ->
        {:reply, [:reject, :already_joined], state}

      false ->
        ref = Process.monitor(pid)
        {:ok, self_name} = Classroom.ActiveUsers.find_user_by_pid(pid)
        new_state = Map.put(state, pid, %{pc: false, self_name: self_name, ref: ref})

        send(pid, [:signaling, [:update_exist_peer_conn, get_exist_peer_conn(new_state)]])

        update_class_state_to_clients(new_state)

        # broadcast_to_pc_ready(new_state, pid)

        {:reply, :ok, new_state}
    end
  end

  def handle_call(:get_session_user, _from, state) do
    {:reply,
     state
     |> Map.keys()
     |> Enum.map(fn pid -> Classroom.ActiveUsers.find_user_by_pid(pid) end)
     |> Enum.map(fn {_, user} -> user end), state}
  end

  defp get_exist_peer_conn(state) do
    exist_peer_conn(state)
    |> Enum.map(fn pid ->
        case Classroom.ActiveUsers.find_user_by_pid(pid) do
          {:ok, u} -> u
        end
      end)
  end

  # Signaling

  def handle_call({:handle_got_media, sender_pid}, _from, state) do
    {:ok, stream_owner} = Classroom.ActiveUsers.find_user_by_pid(sender_pid)
    new_state = update_pc_in_state(sender_pid, state)

    new_state
    |> Map.keys()
    |> Enum.filter(fn pid -> pid != sender_pid end) # broadcast to all besides sender
    |> Enum.map(fn pid -> send(
        pid,
        [:signaling, [
          :got_media,
          stream_owner #owner
        ]]
      ) end)

    {:reply, :ok, new_state}
  end

  def handle_call({:handle_class_direct_message, message, sender_pid}, _from, state) do
    if message["type"] in ["offer", "answer", "candidate", "request_offer"] do
      {:ok, target} = Classroom.ActiveUsers.find_pid_by_user(message["to"])
      {:ok, sender_name} = Classroom.ActiveUsers.find_user_by_pid(sender_pid)

      send(target, %{
        type: :broadcast_message,
        message: Map.put(message, "from", sender_name),
        DEBUG: :handle_class_direct_message
      })

      {:reply, :ok, state}
    end
  end

  def handle_call({:handle_request_offer, to, sender_pid}, _from, state) do
    {:ok, target} = Classroom.ActiveUsers.find_pid_by_user(to)
    {:ok, sender_name} = Classroom.ActiveUsers.find_user_by_pid(sender_pid)

    send(target, [
      :signaling, [
        :request_offer,
        sender_name
    ]])

    {:reply, :ok, state}
  end

  def handle_call({:handle_offer, stream_owner, offer, to, sender_pid}, _from, state) do
    {:ok, target} = Classroom.ActiveUsers.find_pid_by_user(to)
    {:ok, sender_name} = Classroom.ActiveUsers.find_user_by_pid(sender_pid)

    send(target, [
      :signaling, [
        :offer,
        stream_owner,
        offer,
        sender_name
    ]])

    {:reply, :ok, state}
  end

  def handle_call({:handle_answer, stream_owner, answer, to, sender_pid}, _from, state) do
    {:ok, target} = Classroom.ActiveUsers.find_pid_by_user(to)
    {:ok, sender_name} = Classroom.ActiveUsers.find_user_by_pid(sender_pid)

    send(target, [
      :signaling, [
        :answer,
        stream_owner,
        answer,
        sender_name
    ]])

    {:reply, :ok, state}
  end

  def handle_call({:handle_candidate, stream_owner, candidate, to, sender_pid}, _from, state) do
    {:ok, target} = Classroom.ActiveUsers.find_pid_by_user(to)
    {:ok, sender_name} = Classroom.ActiveUsers.find_user_by_pid(sender_pid)

    send(target, [
      :signaling, [
        :candidate,
        stream_owner,
        candidate,
        sender_name
      ]])

    {:reply, :ok, state}
  end

  def handle_call({:handle_action, action, sender_pid}, _from, state) do
    {:ok, sender_name} = Classroom.ActiveUsers.find_user_by_pid(sender_pid)

    broadcast_except_sender(state, sender_pid, [
      :signaling, [
        :action,
        action,
        sender_name
    ]])

    {:reply, :ok, state}
  end

  defp leave_class(pid, state) do
    # send hangup to each remote peer connection
    %{self_name: sender_name} = state |> Map.fetch!(pid)
    Logger.info("#{sender_name} leaving class...")
    broadcast_except_sender(state, pid, [
      :signaling, [
        :action,
        "hangup",
        sender_name
    ]])

    # notifly other clients when user exit
    update_class_state_to_clients(Map.delete(state, pid))
  end

  defp update_class_state_to_clients(state) do
    state |> Map.keys() |> Enum.map(fn pid -> send(pid, :get_session_user) end)
  end

  defp broadcast_except_sender(state, sender_pid, json) do
    state
    |> Map.keys()
    |> Enum.filter(fn pid -> pid != sender_pid end)
    |> Enum.map(fn pid -> send(pid, json) end)
  end

  defp broadcast_to_pc_ready(state, joiner_pid) do
    {:ok, joiner} = Classroom.ActiveUsers.find_user_by_pid(joiner_pid)

    exist_peer_conn(state)
    |> Enum.map(fn u ->
      case Classroom.ActiveUsers.find_pid_by_user(u) do
        {:ok, pid} ->
          send(pid, %{
            type: :broadcast_message,
            message: %{
              type: :join,
              stream_owner: u,
              joiner: joiner
            },
            DEBUG: :broadcast_to_pc_ready
          })

        _ ->
          Logger.debug(Classroom.ActiveUsers.find_pid_by_user(u))
      end
    end)
  end

  defp update_pc_in_state(pid, state) do
    state |> update_in([pid, :pc], &(!&1))
  end

  defp exist_peer_conn(state) do
    state
    |> Enum.map(fn {k, v} ->
      if v.pc do
        k
      end
    end)
    |> Enum.filter(&(!is_nil(&1)))
  end
end
