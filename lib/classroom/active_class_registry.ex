defmodule Classroom.ActiveClasses.Registry do
  use GenServer

  #API

  def start_link do
    IO.puts "testing from registry"
    GenServer.start_link(__MODULE__, nil, name: :registry)
  end

  def whereis_name(class_name) do
    GenServer.call(:registry, {:whereis_name, class_name})
  end

  def register_name(class_name, pid) do
    GenServer.call(:registry, {:register_name, class_name, pid})
  end

  def unregister_name(class_name) do
    GenServer.call(:registry, {:unregister_name, class_name})
  end

  def send_name(class_name, message) do
    case whereis_name(class_name) do
      nil ->
        {:error, {class_name, message}}

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
    {:reply, Map.get(state, class_name), state}
  end

  def handle_call({:register_name, class_name, pid}, _from, state) do
    case Map.get(state, class_name) do
      nil -> {:reply, :ok, Map.put(state, class_name, pid)}
      _ -> {:reply, :error, state}
    end
  end

  def handle_call({:unregister_name, class_name}, _from, state) do # check whereis before unregister in user
    {:reply, :ok, Map.delete(state, class_name)}
  end

end
