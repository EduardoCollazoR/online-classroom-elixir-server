defmodule Classroom.Whiteboard do
  use GenServer
  import Logger

  def start_link(_args) do
    GenServer.start_link(__MODULE__, self(), name: __MODULE__)
  end

  def connect(whiteboard) do
    GenServer.call(whiteboard, {:connect, self()})
  end

  def disconnect(whiteboard) do
    GenServer.call(whiteboard, {:disconnect, self()})
  end

  def draw(whiteboard, line) do
    GenServer.cast(whiteboard, {:draw, self(), line})
  end

  def init(owner) do
    {:ok, %{clients: [], lines: [], owner: owner}}
  end

  def handle_call({:connect, pid}, _from, state) do
    {:reply, state.lines, Map.update!(state, :clients, fn clients -> [pid | clients] end)}
  end

  def handle_call({:disconnect, pid}, _from, state) do
    {:reply, :ok, Map.update!(state, :clients, fn clients -> List.delete(clients, pid) end)}
  end

  def handle_cast({:draw, owner_pid, line}, state = %{owner: owner_pid}) do
    Enum.each(state.clients, fn client -> send(client, {:update, line}) end)
    {:noreply, Map.update!(state, :lines, fn lines -> [line | lines] end)}
  end

  def handle_cast({:draw, _, _}, state) do
    {:noreply, state}
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
