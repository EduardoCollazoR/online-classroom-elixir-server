defmodule ClassroomTest do
  use ExUnit.Case
  doctest Classroom

  test "greets the world" do
    assert Classroom.hello() == :world
  end
end
