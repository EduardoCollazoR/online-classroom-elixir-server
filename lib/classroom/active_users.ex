defmodule Classroom.ActiveUsers do
  use GenServer

  def start_link(_args) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__, debug: [:trace])
  end

  def login(username) do
    GenServer.call(__MODULE__, {:login, self(), username})
  end

  def logout() do
    GenServer.call(__MODULE__, {:logout, self()})
  end

  # {:ok, name} | :error
  def find_user_by_pid(pid) do
    GenServer.call(__MODULE__, {:find_user_by_pid, pid})
  end

  @impl true
  def init(_args) do
    {:ok, []}
  end

  @impl true
  def handle_call({:login, pid, username}, _from, users) do
    case already_logged_in?(users, username) do
      true ->
        {:reply, :error, users}

      false ->
        {:reply, :ok, add_user(users, username, pid)}
    end
  end

  @impl true
  def handle_call({:logout, pid}, _from, users) do
    {:reply, :ok, remove_user(users, pid)}
  end

  @impl true
  def handle_call({:find_user_by_pid, pid}, _from, users) do
    IO.puts(:reach)

    case users |> Enum.find(fn {_key, val, _} -> val == pid end) do
      nil -> {:reply, :error, users}
      {name, _, _} -> {:reply, {:ok, name}, users}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, users) do
    {:noreply, remove_user(users, pid)}
  end

  defp already_logged_in?([], _username), do: false
  defp already_logged_in?([{username, _pid, _} | _], username), do: true

  defp already_logged_in?([{_other, _pid, _} | rest], username),
    do: already_logged_in?(rest, username)

  defp remove_user([], _pid) do
    []
  end

  defp remove_user([{_, pid, ref} | rest], pid) do
    Process.demonitor(ref, [:flush])
    rest
  end

  defp remove_user([tuple | rest], pid) do
    [tuple | remove_user(rest, pid)]
  end

  defp add_user(users, username, pid) do
    ref = Process.monitor(pid)
    [{username, pid, ref} | users]
  end
end
