defmodule Classroom.ActiveWhiteboard do
  use DynamicSupervisor

  def start_link(_args) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def start({owner}) do
    DynamicSupervisor.start_child(__MODULE__, {Classroom.Whiteboard, {owner}})
  end

  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

end
