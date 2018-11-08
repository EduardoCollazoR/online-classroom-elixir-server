defmodule Classroom.PasswordStore do
  use GenServer

  def start_link(_args) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__, debug: [:trace]) # debug: [:trace]
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
    {:ok, _} = :dets.open_file(__MODULE__, file: 'password.dets')
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

  def handle_call({:register, username, password}, _from, nil) do # TODO hash password
    case :dets.lookup(__MODULE__, username) do
      [] ->
        :ok = :dets.insert(__MODULE__, {username, password})
        {:reply, :ok, nil}

      [_record] ->
        {:reply, :error, nil}
    end
  end

  def handle_call({:find_user, username}, _from, nil) do
    case :dets.lookup(__MODULE__, username) do
      [_record] -> {:reply, :ok, nil}
      [] -> {:reply, :error, nil}
    end
  end

  def handle_call({:unregister, username}, _from, nil) do
    :dets.delete(__MODULE__, username)
    {:reply, nil, nil}
  end

end
