defmodule Classroom.ActiveClasses.Registry do
  use GenServer

  #API

  def start_link do
    GenServer.start_link(__MODULE__, nil, name: :registry)
  end

  def whereis_name(class_name) do
    GenServer.call(:registry, {:whereis_name, class_name})
  end

  def register_name(class_name, pid) do
    GenServer.call(:registry, {:register_name, class_name, pid})
  end

  def unregister_name(class_name) do
    GenServer.cast(:registry, {:unregister_name, class_name})
  end

  def send_name(class_name, message) do
    case whereis_name(class_name) do
      :undefined ->
        {:badarg, {class_name, message}}

      pid ->
        Kernel.send(pid, message)
        pid
    end
  end

  # Server

  def init(_) do
    {:ok, Map.new}
  end

  def handle_call({:whereis_name, class_name}, _from, state) do
    {:reply, Map.get(state, class_name, :undefined), state}
  end

  def handle_call({:register_name, class_name, pid}, _from, state) do
    case Map.get(state, class_name) do
      nil ->
        Process.monitor(pid)
        {:reply, :yes, Map.put(state, class_name, pid)}

      _ ->
        {:reply, :no, state}
    end
  end

  def handle_info({:DOWN, _, :process, pid, _}, state) do
   # When a monitored process dies, we will receive a `:DOWN` message
   # that we can use to remove the dead pid from our registry
   {:noreply, remove_pid(state, pid)}
  end

  def remove_pid(state, pid_to_remove) do
    # And here we just filter out the dead pid
    remove = fn {_key, pid} -> pid  != pid_to_remove end
    Enum.filter(state, remove) |> Enum.into(%{})
  end

  def handle_cast({:unregister_name, class_name}, state) do # check whereis before unregister in user
    {:noreply, Map.delete(state, class_name)}
  end

end
