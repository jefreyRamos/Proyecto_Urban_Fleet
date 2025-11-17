defmodule UrbanFleet.Trip do
  use GenServer
  alias UrbanFleet.{UserManager, Persistence}

  def start_link(info), do: GenServer.start_link(__MODULE__, info)

  def status(pid), do: GenServer.call(pid, :status)
  def finish(pid), do: GenServer.cast(pid, :finish)

  @impl true
  def init(info) do
    IO.puts("🚗 Iniciando viaje de #{info.cliente} hacia #{info.destino} con #{info.conductor}")

    state =
      info
      |> Map.put(:estado, :activo)
      |> Map.put(:inicio, DateTime.utc_now())

    dur = Map.get(info, :duracion_ms, 15000)
    Process.send_after(self(), :auto_finish, dur)

    {:ok, state}
  end

  @impl true
  def handle_call(:status, _from, st), do: {:reply, st, st}

  @impl true
  def handle_cast(:finish, st), do: {:noreply, finish_trip(st, :manual)}

  @impl true
  def handle_info(:auto_finish, st), do: {:noreply, finish_trip(st, :auto)}

  defp finish_trip(st, mode) do
    fin = DateTime.utc_now()
    secs = max(1, DateTime.diff(fin, st.inicio))

    UserManager.update_score(st.cliente, 10)
    UserManager.update_score(st.conductor, 15)

    Persistence.append_line("data/results.log",
      "#{DateTime.to_string(fin)};cliente=#{st.cliente};conductor=#{st.conductor};origen=#{st.origen};destino=#{st.destino};estado=Completado;modo=#{mode};duracion=#{secs}s"
    )

    IO.puts("✅ Viaje finalizado: #{st.cliente} → #{st.destino} (#{secs}s)")

    %{st | estado: :finalizado}
  end
end
