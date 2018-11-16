defmodule Classroom.ActiveClasses do
  use DynamicSupervisor

  def start_link do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def start_room(class_name) do
    DynamicSupervisor.start_child(__MODULE__, {Classroom.Class, class_name})
  end

  def init(:ok) do
    IO.puts("init super")
    DynamicSupervisor.init(strategy: :one_for_one)
  end

end
