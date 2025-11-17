defmodule UrbanFleet.CLI do
  alias UrbanFleet.{UserManager, Server}

  def start do
    IO.puts("Bienvenido a UrbanFleet:")
    loop(nil)
  end

  defp loop(current_user) do
    command = IO.gets("> ") |> String.trim()

    case process(command, current_user) do
      {:ok, new_user} -> loop(new_user)
      {:exit, msg} -> IO.puts(msg)
      _ -> loop(current_user)
    end
  end

  ## ---------------------------------------------------
  ## Procesamiento de comandos
  ## ---------------------------------------------------
  def process("connect " <> rest, _user) do
    case String.split(rest, " ") do
      [user, pass] ->
        case UserManager.login(user, pass) do
          {:ok, %{role: role}} ->
            IO.puts("✔ Sesión iniciada: #{user} (#{role})")
            {:ok, user}

          {:error, :wrong_pass} ->
            IO.puts("❌ Contraseña incorrecta")
            :error

          {:error, :no_user} ->
            IO.puts("❌ Usuario no existe")
            :error
        end

      _ ->
        IO.puts("Uso: connect usuario contraseña")
        :error
    end
  end

  def process("register " <> rest, user) do
    case String.split(rest, " ") do
      [username, role, pass] ->
        case UserManager.register(username, role, pass) do
          {:ok, _} ->
            IO.puts("✔ Usuario creado: #{username}")
            {:ok, user}

          {:error, :already_exists} ->
            IO.puts("❌ El usuario ya existe")
            {:ok, user}
        end

      _ ->
        IO.puts("Uso: register usuario rol contraseña")
        {:ok, user}
    end
  end

  ## ---------------------------------------------------
  ## Viajes
  ## ---------------------------------------------------
  def process("request_trip " <> rest, user) when is_binary(user) do
    with ["origen=" <> ori, "destino=" <> dest] <- String.split(rest, " "),
         {:ok, id} <- Server.request_trip(user, ori, dest) do
      IO.puts("🚗 Viaje solicitado (ID #{id}).")
      {:ok, user}
    else
      _ ->
        IO.puts("❌ Error en el formato. Uso: request_trip origen=X destino=Y")
        {:ok, user}
    end
  end

  def process("ranking", user) do
    IO.puts("\n🏆 RANKING\n------------------")

    UserManager.ranking()
    |> Enum.each(fn {u, pts, r} ->
      IO.puts("#{u} (#{r}): #{pts} pts")
    end)

    {:ok, user}
  end

  def process("mostrar_ranking", user) do
    Server.mostrar_ranking()
    {:ok, user}
  end

  def process("mostrar_resultados", user) do
    Server.mostrar_resultados()
    {:ok, user}
  end

  ## ---------------------------------------------------
  ## Comando desconocido
  ## ---------------------------------------------------
  def process(cmd, user) do
    IO.puts("Comando no reconocido: #{cmd}")
    {:ok, user}
  end
end
