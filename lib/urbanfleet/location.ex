defmodule UrbanFleet.Location do
  alias UrbanFleet.Persistence
  @path "data/locations.dat"

  def valid?(name), do: name in Persistence.read_lines(@path)
end
