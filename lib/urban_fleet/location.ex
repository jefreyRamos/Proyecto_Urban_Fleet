defmodule UrbanFleet.Location do
  @moduledoc """
  Valida ubicaciones cargadas desde data/locations.dat.
  """

  @file_path "data/locations.dat"

  def all do
    if File.exists?(@file_path) do
      File.read!(@file_path)
      |> String.split("\n", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.filter(&(&1 != ""))
    else
      []
    end
  end

  def valid?(loc) when is_binary(loc) do
    Enum.member?(all(), String.trim(loc))
  end
end
