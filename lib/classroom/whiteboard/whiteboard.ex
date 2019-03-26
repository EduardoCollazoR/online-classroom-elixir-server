defmodule Classroom.Whiteboard do
  use GenServer
  require Logger

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
    GenServer.cast(via_tuple(owner), {:draw, self(), lines}) # FIX: cannot receive below
  end

  defp via_tuple(owner) do
    # {:via, module_name, term}
    {:via, Classroom.ActiveWhiteboard.Registry, {:whiteboard, owner}}
  end

  # Server

  @impl true
  def init(args) do
    # WIP: convert this: %{pid => %{}}
    # to %{clients: [], lines: []}
    [{owner}] = args
    {:ok, owner_pid} = Classroom.ActiveUsers.find_pid_by_user(owner)
    Process.monitor(owner_pid)
    {:ok, %{owner: owner, owner_pid: owner_pid, clients: [], lines: []}}
  end

  @impl true
  def handle_info({:DOWN, _, :process, pid, _}, state) do
    case pid == state.owner_pid do
      true ->
        Classroom.ActiveWhiteboard.Registry.unregister_name({:whiteboard, state.owner})

      false ->
        send_updated_state_to_all(state)
    end
    {:noreply, Map.delete(state, pid)}
  end

  # connect
  @impl true
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
  @impl true
  def handle_call({:leave, pid}, _from, state) do
    new_state = Map.update!(state, :clients, fn clients -> List.delete(clients, pid) end)
    send_updated_state_to_all(new_state)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_session_user, _from, state) do
    {:reply,
     state
     |> Map.keys()
     |> Enum.map(fn pid -> Classroom.ActiveUsers.find_user_by_pid(pid) end)
     |> Enum.map(fn {_, user} -> user end), state}
  end

  @impl true
  # draw function for owner
  def handle_cast({:draw, owner_pid, lines}, state = %{owner_pid: owner_pid}) do
    send_draw(state.owner, owner_pid, state.clients, lines)

    {:noreply, Map.update!(state, :lines, fn old_lines -> [lines | old_lines] end)}
  end

  @spec send_draw(String.t(), pid(), [term()], [map()]) :: :ok
  defp send_draw(whiteboard, from, clients, lines) do
    Enum.each(clients, fn to_pid ->
      if to_pid != from do
        # Logger.info("sending draw of {whiteboard: #{whiteboard}} from: #{inspect from},to: #{inspect to_pid}")
        send(to_pid, [:whiteboard_server, [:draw_event, [whiteboard, lines]]])
      end
    end)
    :ok
  end

  @impl true
  def handle_cast({:draw, non_owner_pid, lines}, state) do
    Logger.info("received draw from non-owner for whiteboard: #{inspect non_owner_pid}")
    {:noreply, state}
  end

  # functions

  defp send_updated_state_to_all(_state) do
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
