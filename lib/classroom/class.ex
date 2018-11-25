defmodule Classroom.Class do
  use GenServer

  # API

  def start_link({owner, class_name}) do
    GenServer.start_link(__MODULE__, [{owner, class_name}], name: via_tuple(owner, class_name), debug: [:trace])
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

  defp via_tuple(owner, class_name) do
    # {:via, module_name, term}
    {:via, Classroom.ActiveClasses.Registry, {owner, class_name}}
  end

  # Server

  def init(_args) do
    {:ok, %{}} # %{ pid => %{}}
  end

  def handle_info({:DOWN, _, :process, pid, _}, state) do
   {:noreply, Map.delete(state, pid)}
  end

  def handle_call({:join, pid}, _from, state) do
    case Map.has_key?(state, pid) do
      true ->
        {:reply, :error, state}
      false ->
        Process.monitor(pid)
        broadcast(Map.put(state, pid, %{}), %{"type" => "get_session_user"})
        {:reply, :ok, Map.put(state, pid, %{})}
    end
  end

  def handle_call({:leave, pid}, _from, state) do
    {:reply, :ok, Map.delete(state, pid)}
  end

  def handle_call(:get_session_user, _from, state) do
    {:reply,
      state
        |> Map.keys
        |> Enum.map(fn pid -> Classroom.ActiveUsers.find_user_by_pid(pid) end)
        |> Enum.map(fn {_, user} -> user end),
      state
    }
  end

  defp broadcast(state, json) do
    state |> Map.keys |> Enum.map(fn pid -> send pid, json end)
  end
end
