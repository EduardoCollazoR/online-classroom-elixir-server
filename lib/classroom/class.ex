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

  def get_exist_peer_conn(owner, class_name) do
    GenServer.call(via_tuple(owner, class_name), :get_exist_peer_conn)
  end

  def handle_class_direct_message(owner, class_name, message) do
    GenServer.call(via_tuple(owner, class_name), {:handle_class_direct_message, message, self()})
  end

  def handle_got_media(owner, class_name, message) do
    GenServer.call(
      via_tuple(owner, class_name),
      {:handle_got_media, message, self()}
    )
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
    update_class_state_to_clients(state)
    {:noreply, Map.delete(state, pid)}
  end

  def handle_call({:join, pid}, _from, state) do
    case Map.has_key?(state, pid) do
      true ->
        {:reply, [:reject, :already_joined], state}

      false ->
        Process.monitor(pid)
        new_state = Map.put(state, pid, %{pc: false})

        send(pid, :signaling, :get_exist_peer_conn)

        update_class_state_to_clients(new_state)

        # broadcast_to_pc_ready(new_state, pid)

        {:reply, :ok, new_state}
    end
  end

  def handle_call({:leave, pid}, _from, state) do
    update_class_state_to_clients(Map.delete(state, pid))
    {:reply, :ok, Map.delete(state, pid)}
  end

  def handle_call(:get_session_user, _from, state) do
    {:reply,
     state
     |> Map.keys()
     |> Enum.map(fn pid -> Classroom.ActiveUsers.find_user_by_pid(pid) end)
     |> Enum.map(fn {_, user} -> user end), state}
  end

  def handle_call(:get_exist_peer_conn, _from, state) do
    {:reply,
     exist_peer_conn(state)
     |> Enum.map(fn pid ->
       case Classroom.ActiveUsers.find_user_by_pid(pid) do
         {:ok, u} -> u
       end
     end), state}
  end

  def handle_call({:handle_class_direct_message, message, sender_pid}, _from, state) do
    if message["type"] in ["offer", "answer", "candidate", "request_offer"] do
      {:ok, to} = Classroom.ActiveUsers.find_pid_by_user(message["to"])
      {:ok, sender_name} = Classroom.ActiveUsers.find_user_by_pid(sender_pid)

      send(to, %{
        type: :broadcast_message,
        message: Map.put(message, "from", sender_name),
        DEBUG: :handle_class_direct_message
      })

      {:reply, :ok, state}
    end
  end

  def handle_call({:handle_got_media, sender_pid}, _from, state) do
    {:ok, stream_owner} = Classroom.ActiveUsers.find_user_by_pid(sender_pid)

    update_pc_in_state(sender_pid, state)
    |> Map.keys()
    |> Enum.filter(fn pid -> pid != sender_pid end) # broadcast to all besides sender
    |> Enum.map(fn pid -> send(
        pid,
        :signaling,
        :noti_got_media,
        stream_owner #owner
      ) end)

    {:reply, :ok, new_state}
  end

  # def handle_call({:handle_class_broadcast_message, message, sender_pid}, _from, state) do
  #   new_state =
  #     if message["type"] == "got user media" do
  #       new_s = switch_pc_state(sender_pid, state)
  #       new_s
  #     else
  #       state
  #     end

  #   # TODO change to following to case statement i.e. message["type"] in ["offer", "bye"]
  #   if message["type"] in ["got user media", "bye"] do
  #     {:ok, stream_owner} = Classroom.ActiveUsers.find_user_by_pid(sender_pid)

  #     broadcast_except_sender(
  #       new_state,
  #       %{
  #         type: :broadcast_message,
  #         message: Map.put(message, :stream_owner, stream_owner)
  #       },
  #       sender_pid
  #     )

  #     {:reply, :ok, new_state}
  #   end
  # end

  # def handle_call({:upload, pid}, _from, state) do //copied from leave
  #   update_class_state_to_clients(Map.delete(state, pid))
  #   {:reply, :ok, Map.delete(state, pid)}
  # end

  defp update_class_state_to_clients(state) do
    state |> Map.keys() |> Enum.map(fn pid -> send(pid, :get_session_user) end)
  end

  # defp broadcast_except_sender(state, json, sender_pid) do
  #   state
  #   |> Map.keys()
  #   |> Enum.filter(fn pid -> pid != sender_pid end)
  #   |> Enum.map(fn pid -> send(pid, json) end)
  # end

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
