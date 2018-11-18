defmodule Classroom.Class do
  use GenServer

  # API

  def start_link({owner, class_name}) do
    GenServer.start_link(__MODULE__, [{owner, class_name}], name: via_tuple(owner, class_name))
  end

  def join(owner, class_name) do
    GenServer.call(via_tuple(owner, class_name), {:join, self()})
  end

  def leave(owner, class_name) do
    GenServer.call(via_tuple(owner, class_name), {:leave, self()})
  end

  def get_state(owner, class_name) do
    GenServer.call(via_tuple(owner, class_name), :get_state)
  end

  defp via_tuple(owner, class_name) do
    # {:via, module_name, term}
    {:via, Classroom.ActiveClasses.Registry, {owner, class_name}}
  end

  # Server

  def init(_args) do
    {:ok, %{}}
  end

  def handle_call({:join, pid}, _from, state) do
    case Map.has_key?(state, pid) do
      true -> {:reply, :error, state}
      false -> {:reply, :ok, Map.put(state, pid, %{})}
    end
  end

  def handle_call({:leave, pid}, _from, state) do
    {:reply, :ok, Map.delete(state, pid)}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end
end
