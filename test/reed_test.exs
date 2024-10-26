defmodule ReedTest do
  use ExUnit.Case
  doctest Reed

  test "greets the world" do
    assert Reed.hello() == :world
  end
end
