defmodule Urbanfleet.Persistence do
  @moduledoc """
  Utilidades para leer y escribir archivos de texto de manera segura.
  """

  def read_lines(path) do
    if File.exists?(path), do: File.read!(path) |> String.split("\n", trim: true), else: []
  end

  def append_line(path, line) do
    File.write!(path, line <> "\n", [:append])
  end

  def write_lines(path, lines) when is_list(lines) do
    tmp = path <> ".tmp"
    File.write!(tmp, Enum.join(lines, "\n") <> "\n")
    File.rename!(tmp, path)
  end
end
