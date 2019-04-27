defmodule Classroom.ActiveGroupWhiteboard do
  use DynamicSupervisor

  def start_link(_args) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def start({owner, class_name, target}) do
    DynamicSupervisor.start_child(__MODULE__, {Classroom.GroupWhiteboard, {owner, class_name, target}})
  end

  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

end
