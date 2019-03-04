defmodule Classroom.Whiteboard do
  use GenServer
  import Logger

  # API

  def start_link({owner}) do
    # , debug: [:trace])
    GenServer.start_link(__MODULE__, [{owner}], name: via_tuple(owner))
  end

  def connect(owner) do
    GenServer.call(via_tuple(owner), {:connect, self()})
  end

  def leave(owner) do
    GenServer.call(via_tuple(owner), {:leave, self()})
  end

  def get_session_user(owner) do
    GenServer.call(via_tuple(owner), :get_session_user)
  end

  def draw(owner, lines) do
    Logger.info(inspect via_tuple(owner))
    GenServer.cast(via_tuple(owner), {:draw, self(), lines}) # FIX: cannot receive below
  end

  defp via_tuple(owner) do
    # {:via, module_name, term}
    {:via, Classroom.ActiveWhiteboard.Registry, {owner}}
  end

  # Server

  def init(args) do
    # WIP: convert this: %{pid => %{}}
    # to %{clients: [], lines: []}
    [{owner}] = args
    {:ok, owner_pid} = Classroom.ActiveUsers.find_pid_by_user(owner)
    Process.monitor(owner_pid)
    {:ok, %{owner: owner, owner_pid: owner_pid, clients: [], lines: []}}
  end

  def handle_info({:DOWN, _, :process, pid, _}, state) do
    case pid == state.owner_pid do
      true ->
        Classroom.ActiveWhiteboard.Registry.unregister_name({state.owner})

      false ->
        send_updated_state_to_all(state)
    end
    {:noreply, Map.delete(state, pid)}
  end

  # connect
  def handle_call({:connect, pid}, _from, state) do
    case Enum.member?(state.clients, pid) do
      true ->
        {:reply, [:reject, :already_connected], state}

      false ->
        Process.monitor(pid)
        new_state = Map.update!(state, :clients, fn clients -> [pid | clients] end)

        send_updated_state_to_all(new_state)

        {:reply, new_state.lines, new_state}
    end
  end

  # disconnect
  def handle_call({:leave, pid}, _from, state) do
    new_state = Map.update!(state, :clients, fn clients -> List.delete(clients, pid) end)
    send_updated_state_to_all(new_state)
    {:reply, :ok, new_state}
  end

  def handle_call(:get_session_user, _from, state) do
    {:reply,
     state
     |> Map.keys()
     |> Enum.map(fn pid -> Classroom.ActiveUsers.find_user_by_pid(pid) end)
     |> Enum.map(fn {_, user} -> user end), state}
  end

  # def handle_cast(_, state) do
  #   Logger.info("reach here")
  #   {:noreply, state}
  # end

  # # draw function for owner
  # def handle_cast({:draw, owner_pid, lines}, state = %{owner: owner_pid}) do
  #   Logger.info("received draw")
  #   Enum.each(state.clients, fn client_pid ->
  #     Logger.info("sending whiteboard #{state.owner} to #{client_pid}")
  #     send(client_pid, [:whiteboard_server, [:draw_event, [state.owner, lines]]])
  #   end)
  #   {:noreply, Map.update!(state, :lines, fn old_lines -> [lines | old_lines] end)}
  # end

  # def handle_cast({:draw, _, _}, state) do
  #   Logger.info("received draw2")
  #   Logger.info(inspect state)
  #   {:noreply, state}
  # end

  # functions

  defp send_updated_state_to_all(state) do
    # state |> Map.keys() |> Enum.map(fn pid -> send(pid, :get_session_user) end)
  end

end

# def init(_args) do
#   {:ok, _} = :dets.open_file(__MODULE__, file: 'drawer.dets')
#   {:ok, nil}
# end

# def handle_call({:check_password, username, password}, _from, nil) do
#   case :dets.lookup(__MODULE__, username) do
#     [{_, ^password}] ->
#       {:reply, true, nil}

#     [{_, _wrong_password}] ->
#       {:reply, false, nil}

#     [] ->
#       {:reply, false, nil}
#   end
# end

# def handle_call({:register, username, password}, _from, nil) do
#   case :dets.lookup(__MODULE__, username) do
#     [] ->
#       :ok = :dets.insert(__MODULE__, {username, password})
#       {:reply, :ok, nil}

#     [_record] ->
#       {:reply, :error, nil}
#   end
# end
