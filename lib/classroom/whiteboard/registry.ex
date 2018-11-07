defmodule Classroom.Whiteboard.Registry do
  @moduledoc """
  This is the documentation of Classroom.Whiteboard.Registry

  some text here
  ....
  """

  use GenServer

  def init(_args) do
    {:ok, []}
  end

  def handle_call(:list, _from, state) do
    {:reply, state, state}
  end

  def handle_cast({:register, pid}, state) do
    {:noreply, [pid | state]}
  end

  def handle_cast({:unregister, pid}, state) do
    {:noreply, List.delete(state, pid)}
  end
end
