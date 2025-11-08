defmodule Urbanfleet.TripSupervisor do
  use DynamicSupervisor

  def start_link(_opts) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc "Crea un nuevo viaje supervisado."
  def start_trip(info) do
    spec = {Urbanfleet.Trip, info}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end
end

