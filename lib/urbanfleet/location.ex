defmodule Urbanfleet.Location do
  alias Urbanfleet.Persistence
  @path "data/locations.dat"

  def valid?(name), do: name in Persistence.read_lines(@path)
end
