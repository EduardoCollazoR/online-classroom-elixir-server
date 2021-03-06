defmodule Classroom.ActiveClasses do
  use DynamicSupervisor

  def start_link(_args) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def start_class({owner, class_name}) do
    DynamicSupervisor.start_child(__MODULE__, {Classroom.Class, {owner, class_name}})
  end

  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

end
