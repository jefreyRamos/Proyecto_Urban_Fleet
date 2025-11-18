defmodule UrbanFleet.CLI do
  # Interfaz de línea de comandos para UrbanFleet
  alias UrbanFleet.{UserManager, Server}
  # Accesos simplificados al UserManager y Server
  defp um_call(msg), do: GenServer.call({:global, UserManager}, msg)
  defp sv_call(msg), do: GenServer.call({:global, Server}, msg)

  def start do
    IO.puts("Bienvenido a UrbanFleet:")
    loop(%{connected: false, user: nil})
  end

  # es un bucle REPL simple el cual procesa comandos
  defp loop(state) do
    input = IO.gets("> ") |> String.trim()
    new_state = process(input, state)
    loop(new_state)
  end

  # registrar usuario
  defp process("register " <> rest, state) do
    case String.split(rest, " ") do
      [user, role, pass] ->
        case um_call({:register, user, role, pass}) do
          {:ok, _} -> IO.puts("✔ Usuario registrado.")
          {:error, :already_exists} -> IO.puts(" El usuario ya existe.")
        end

      _ ->
        IO.puts("Uso: register usuario rol contraseña")
    end

    state
  end

  # estado del viaje
  defp process("trip_status " <> id, state) do
    id = String.trim(id)

    case sv_call({:trip_status, id}) do
      {:ok, st} -> IO.puts("Estado del viaje: #{inspect(st)}")
      {:error, msg} -> IO.puts(" #{msg}")
    end

    state
  end

  # connect username pass
  defp process("connect " <> rest, state) do
    case String.split(rest, " ") do
      [user, pass] ->
        case um_call({:login, user, pass}) do
          {:ok, u} ->
            IO.puts(" Sesión iniciada: #{u.username} (#{u.role})")
            %{state | connected: true, user: u}

          {:error, :no_user} ->
            IO.puts(" Usuario no encontrado. Registrando automáticamente como cliente...")

            case um_call({:register, user, "cliente", pass}) do
              {:ok, u} ->
                IO.puts(" Usuario creado y conectado.")
                %{state | connected: true, user: u}

              _ ->
                IO.puts(" No se pudo crear el usuario.")
                state
            end

          {:error, :wrong_pass} ->
            IO.puts(" Contraseña incorrecta.")
            state
        end

      _ ->
        IO.puts("Uso: connect usuario contraseña")
        state
    end
  end

  # isconnect
  defp process("disconnect", %{user: nil} = state) do
    IO.puts("No hay sesión activa.")
    state
  end

  defp process("disconnect", state) do
    IO.puts("Sesión cerrada: #{state.user.username}")
    %{state | connected: false, user: nil}
  end

  # CLIENTE: request_trip
  defp process("request_trip " <> args, %{connected: true, user: %{role: "cliente"} = u} = state) do
    case parse_trip_args(args) do
      {:ok, origen, destino} ->
        case sv_call({:request_trip, u.username, origen, destino}) do
          {:ok, id} -> IO.puts(" Viaje solicitado con ID: #{id}")
          {:error, msg} -> IO.puts(" Error: #{msg}")
        end

      {:error, msg} ->
        IO.puts(" #{msg}")
    end

    state
  end

  defp process("request_trip " <> _args, state) do
    IO.puts("Solo clientes pueden solicitar viajes.")
    state
  end

  # CONDUCTOR: accept_trip
  defp process("accept_trip " <> id, %{connected: true, user: %{role: "conductor"} = u} = state) do
    id = String.trim(id)

    case sv_call({:accept_trip, id, u.username}) do
      {:ok, _pid} -> IO.puts(" Viaje aceptado.")
      {:error, msg} -> IO.puts(" Error: #{msg}")
    end

    state
  end

  defp process("accept_trip " <> _id, state) do
    IO.puts("Solo conductores pueden aceptar viajes.")
    state
  end

  # list_trips
  defp process("list_trips", state) do
    trips = sv_call(:list_trips)
    IO.puts(" Viajes pendientes: #{inspect(trips)}")
    state
  end

  # ranking
  defp process("ranking", state) do
    sv_call(:mostrar_ranking)
    state
  end

  # resultados
  defp process("resultados", state) do
    sv_call(:mostrar_resultados)
    state
  end

  # help
  defp process("help", state) do
    IO.puts("""
    Comandos disponibles:
    register usuario rol contraseña
    connect usuario contraseña
    disconnect
    request_trip origen=XX destino=YY
    list_trips
    accept_trip tripID
    ranking
    resultados
    help
    """)

    state
  end

  # comando desconocido
  defp process(cmd, state) do
    IO.puts("Comando no reconocido: #{cmd}")
    state
  end

  # parse_trip_args
  defp parse_trip_args(args) do
    parts =
      args
      |> String.split(" ")
      |> Enum.map(&String.trim/1)

    origen =
      parts
      |> Enum.find_value(fn
        "origen=" <> v -> v
        _ -> nil
      end)

    destino =
      parts
      |> Enum.find_value(fn
        "destino=" <> v -> v
        _ -> nil
      end)

    cond do
      origen == nil -> {:error, "Falta origen=XXX"}
      destino == nil -> {:error, "Falta destino=YYY"}
      true -> {:ok, origen, destino}
    end
  end
end
