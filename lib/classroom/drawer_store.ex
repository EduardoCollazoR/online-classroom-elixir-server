defmodule Classroom.DrawerStore do
  use GenServer

  def start_link(_args) do
    # debug: [:trace]
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def valid_password?(username, password) do
    GenServer.call(__MODULE__, {:check_password, username, password})
  end

  def register(username, password) do
    GenServer.call(__MODULE__, {:register, username, password})
  end

  def unregister() do
    GenServer.call(__MODULE__, {:unregister, self()})
  end

  def has_user?(username) do
    GenServer.call(__MODULE__, {:find_user, username})
  end

  def init(_args) do
    {:ok, _} = :dets.open_file(__MODULE__, file: 'drawer.dets')
    {:ok, nil}
  end

  def handle_call({:check_password, username, password}, _from, nil) do
    case :dets.lookup(__MODULE__, username) do
      [{_, ^password}] ->
        {:reply, true, nil}

      [{_, _wrong_password}] ->
        {:reply, false, nil}

      [] ->
        {:reply, false, nil}
    end
  end

  def handle_call({:register, username, password}, _from, nil) do
    case :dets.lookup(__MODULE__, username) do
      [] ->
        :ok = :dets.insert(__MODULE__, {username, password})
        {:reply, :ok, nil}

      [_record] ->
        {:reply, :error, nil}
    end
  end

end
