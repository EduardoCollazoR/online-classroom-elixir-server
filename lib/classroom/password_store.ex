defmodule Classroom.PasswordStore do
  use GenServer

  def start_link(args) do
    users = Keyword.get(args, :users, %{})
    GenServer.start_link(__MODULE__, users, name: __MODULE__, debug: [:trace]) # debug: [:trace]
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

  def init(users) do
    {:ok, users}
  end

  def handle_call({:check_password, username, password}, _from, users) do
    case Map.fetch(users, username) do
      {:ok, ^password} ->
        {:reply, true, users}

      {:ok, _wrong_password} ->
        {:reply, false, users}

      :error ->
        {:reply, false, users}
    end
  end

  def handle_call({:register, username, password}, _from, users) do # TODO hash password
    case Map.has_key?(users, username) do
      false -> {:reply, :ok, Map.put(users, username, password)}
      true -> {:reply, :error, users}
    end
  end

  def handle_call({:find_user, username}, _from, users) do
    case users |> Map.has_key?(username) do
      true -> {:reply, :ok}
      false -> {:reply, :error}
    end
  end

  def handle_call({:unregister, username}, _from, users) do
    {:reply, :ok, Map.delete(users, username)}
  end

end
