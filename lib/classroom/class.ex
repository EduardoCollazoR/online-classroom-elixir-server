defmodule Classroom.Class do
  use GenServer
  import Logger

  # API

  def start_link(class_name) do
    GenServer.start_link(
      __MODULE__,
      [class_name],
      # name: {:global, "class:#{class_name}"}
      name: via_tuple(class_name)
    )
  end

  def add(class_name, msg) do
    GenServer.call(via_tuple(class_name), {:add, msg})
  end

  def get(class_name) do
    GenServer.call(via_tuple(class_name), :get)
  end

  defp via_tuple(class_name) do
    # {:via, module_name, term}
    {:via, Classroom.ActiveClasses.Registry, {:class_registry, class_name}}
  end

  # Server

  def init(_args) do
    {:ok, []}
  end

  def handle_call({:add, msg}, _from, state) do
    {:reply, :ok, [msg | state]}
  end

  def handle_call(:get, _from, state) do
    {:reply, state, state}
  end
end
