defmodule Classroom.GroupWhiteboard do
  use GenServer
  require Logger

  # API

  def start_link({owner, class_name, group}) do
    # , debug: [:trace])
    GenServer.start_link(__MODULE__, [{owner, class_name, group}], name: via_tuple(owner, class_name, group))
  end

  def connect(owner, class_name, group) do
    GenServer.call(via_tuple(owner, class_name, group), {:connect, self()})
  end

  def disconnect(owner, class_name, group) do
    GenServer.call(via_tuple(owner, class_name, group), {:disconnect, self()})
  end

  # def get_session_user(owner, class_name, group) do
  #   GenServer.call(via_tuple(owner), :get_session_user)
  # end

  def draw(owner, class_name, group, lines) do
    GenServer.cast(via_tuple(owner, class_name, group), {:draw, self(), lines}) # FIX: cannot receive below
  end

  defp via_tuple(owner, class_name, group) do
    # {:via, module_name, term}
    {:via, Classroom.ActiveGroupWhiteboard.Registry, {:group_whiteboard, owner, class_name, group}}
  end

  # Server

  @impl true
  def init(args) do
    # WIP: convert this: %{pid => %{}}
    # to %{clients: [], lines: []}
    [{owner, class_name, group}] = args
    owner_pid = :sys.get_state(:registry)[{owner, class_name}]
    Process.monitor(owner_pid)
    {:ok, %{owner: owner, class_name: class_name, group: group, owner_pid: owner_pid, clients: [], lines: []}}
  end

  @impl true
  def handle_info({:DOWN, _, :process, pid, _}, state) do
    case pid == state.owner_pid do
      true ->
        Classroom.ActiveGroupWhiteboard.Registry.unregister_name({:group_whiteboard, state.owner, state.class_name, state.group})
        {:noreply, Map.delete(state, pid)}

      false ->
        new_state = Map.update!(state, :clients, fn clients -> List.delete(clients, pid) end)
        # send_updated_state_to_all(new_state)
        {:noreply, new_state}
    end
  end

  # disconnect
  @impl true
  def handle_call({:disconnect, pid}, _from, state) do
    case pid == state.owner_pid do
      true ->
        Classroom.ActiveGroupWhiteboard.Registry.unregister_name({:group_whiteboard, state.owner})
        {:reply, :ok, Map.delete(state, pid)}

      false ->
        new_state = Map.update!(state, :clients, fn clients -> List.delete(clients, pid) end)
        # send_updated_state_to_all(new_state)
        {:reply, :ok, new_state}
    end
  end

  # connect
  @impl true
  def handle_call({:connect, pid}, _from, state) do
    case Enum.member?(state.clients, pid) do
      true ->
        {:reply, [:reject, :already_connected], state}

      false ->
        Process.monitor(pid)

        new_state =
          case pid == state.owner_pid do
            true ->
              state

            false ->
              Map.update!(state, :clients, fn clients -> [pid | clients] end)
          end
        # send_updated_state_to_all(new_state)

        {:reply, new_state.lines, new_state}
    end
  end

  # @impl true
  # def handle_call(:get_session_user, _from, state) do
  #   {:reply,
  #    state
  #    |> Map.keys()
  #    |> Enum.filter(fn pid -> pid != state.owner end)
  #    |> Enum.map(fn pid ->
  #         {_, user} = Classroom.ActiveUsers.find_user_by_pid(pid)
  #         user
  #     end),
  #   state}
  # end

  # @impl true
  # # draw function for owner
  # def handle_cast({:draw, owner_pid, lines}, state = %{owner_pid: owner_pid}) do
  #   send_draw(state.owner, owner_pid, state.clients, lines)

  #   {:noreply, Map.update!(state, :lines, fn old_lines -> [lines | old_lines] end)}
  # end

  @impl true
  def handle_cast({:draw, non_owner_pid, lines}, state) do
    send_draw(non_owner_pid, lines, state)

    {:noreply, Map.update!(state, :lines, fn old_lines -> [lines | old_lines] end)}
  end

  # functions

  # @spec send_draw(String.t(), pid(), [term()], [map()]) :: :ok
  defp send_draw(from, lines, %{clients: clients, group: group}) do
    Enum.each(clients, fn to_pid ->
      if to_pid != from do
        # Logger.info("sending draw of {whiteboard: #{whiteboard}} from: #{inspect from},to: #{inspect to_pid}")
        send(to_pid, [:group_whiteboard_server, [:draw_event, [group, lines]]])
      end
    end)
    :ok
  end

  # defp send_updated_state_to_all(_state) do
  #   # state |> Map.keys() |> Enum.map(fn pid -> send(pid, :get_session_user) end)
  # end

end

