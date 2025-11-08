defmodule Urbanfleet.Server do
  @moduledoc """
  Servidor central del sistema UrbanFleet.
  Gestiona los comandos de usuarios y los viajes activos.
  """

  use GenServer
  alias Urbanfleet.{UserManager, TripSupervisor, Persistence}

  # ==================
  #  API Pública
  # ==================

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Crea un viaje entre un cliente y un conductor.
  """
  def crear_viaje(cliente, conductor, origen, destino, duracion_ms \\ 5000) do
    GenServer.call(__MODULE__, {:crear_viaje, cliente, conductor, origen, destino, duracion_ms})
  end

  @doc """
  Muestra el historial de viajes desde results.log.
  """
  def mostrar_resultados do
    GenServer.call(__MODULE__, :mostrar_resultados)
  end

  @doc """
  Muestra el ranking de usuarios.
  """
  def mostrar_ranking do
    GenServer.call(__MODULE__, :mostrar_ranking)
  end

  # ==================
  #  Callbacks del GenServer
  # ==================

  @impl true
  def init(_arg) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:crear_viaje, cliente, conductor, origen, destino, duracion_ms}, _from, state) do
    # Validar existencia de usuarios
    with {:ok, _} <- validar_usuario(cliente),
         {:ok, _} <- validar_usuario(conductor) do

      info = %{
        cliente: cliente,
        conductor: conductor,
        origen: origen,
        destino: destino,
        duracion_ms: duracion_ms
      }

      case TripSupervisor.start_trip(info) do
        {:ok, pid} ->
          {:reply, {:ok, pid}, state}

        {:error, error} ->
          {:reply, {:error, error}, state}
      end
    else
      {:error, :no_user, u} ->
        {:reply, {:error, "Usuario no encontrado: #{u}"}, state}
    end
  end

  @impl true
  def handle_call(:mostrar_resultados, _from, state) do
    log_path = "data/results.log"

    case File.exists?(log_path) do
      true ->
        contenido =
          Persistence.read_lines(log_path)
          |> Enum.join("\n")

        IO.puts("📜 HISTORIAL DE VIAJES:\n" <> contenido)
        {:reply, :ok, state}

      false ->
        {:reply, {:error, "No hay resultados registrados aún."}, state}
    end
  end

  @impl true
  def handle_call(:mostrar_ranking, _from, state) do
    ranking = UserManager.ranking(10)

    IO.puts("\n🏆 RANKING GENERAL")
    IO.puts("----------------------")
    Enum.each(ranking, fn {usuario, puntos, rol} ->
      IO.puts("#{usuario} (#{rol}): #{puntos} pts")
    end)

    {:reply, :ok, state}
  end

  # ==================
  #  Funciones privadas
  # ==================

  defp validar_usuario(nombre) do
    case UserManager.get_score(nombre) do
      {:ok, _} -> {:ok, nombre}
      {:error, :no_user} -> {:error, :no_user, nombre}
    end
  end
end
