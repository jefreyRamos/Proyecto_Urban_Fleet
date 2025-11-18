defmodule UrbanFleet.TripSupervisor do
  # Supervisor dinámico para viajes
  use DynamicSupervisor

  # REGISTRO GLOBAL
  def start_link(_opts) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: {:global, __MODULE__})
  end

  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc "Crea un nuevo viaje supervisado."
  def start_trip(info) do
    spec = {UrbanFleet.Trip, info}
    DynamicSupervisor.start_child({:global, __MODULE__}, spec)
  end
end
