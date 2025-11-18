defmodule UrbanFleet.Persistence do
  @moduledoc "Funciones utilitarias para leer/escribir archivos (atómicas)."

  @spec ensure_dir(String.t()) :: :ok
  def ensure_dir(path) when is_binary(path) do
    dir = Path.dirname(path)
    File.mkdir_p!(dir)
    :ok
  end

  @spec write_lines(String.t(), [String.t()]) :: :ok | {:error, any()}
  def write_lines(path, lines) when is_binary(path) and is_list(lines) do
    try do
      ensure_dir(path)
      tmp = path <> ".tmp"
      File.write!(tmp, Enum.join(lines, "\n") <> "\n")
      File.rename!(tmp, path)
      :ok
    rescue
      e -> {:error, e}
    end
  end

  @spec append_line(String.t(), String.t()) :: :ok | {:error, any()}
  def append_line(path, line) when is_binary(path) and is_binary(line) do
    try do
      ensure_dir(path)
      File.write!(path, line <> "\n", [:append])
      :ok
    rescue
      e -> {:error, e}
    end
  end

  @spec read_lines(String.t()) :: [String.t()]
  def read_lines(path) when is_binary(path) do
    case File.read(path) do
      {:ok, content} -> String.split(content, "\n", trim: true)
      {:error, _} -> []
    end
  end
end
