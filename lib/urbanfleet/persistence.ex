defmodule UrbanFleet.Persistence do
  def ensure_dir(path) do
    dir = Path.dirname(path)
    File.mkdir_p!(dir)
  end

  # lista → archivo
  def write_lines(lines, path) when is_list(lines) and is_binary(path) do
    ensure_dir(path)
    File.write!(path, Enum.join(lines, "\n"))
  end

  # cadena → archivo
  def write_lines(line, path) when is_binary(line) and is_binary(path) do
    ensure_dir(path)
    File.write!(path, line)
  end

  def append_line(path, line) do
    ensure_dir(path)
    File.write!(path, line <> "\n", [:append])
  end

  def read_lines(path) do
    case File.read(path) do
      {:ok, content} -> String.split(content, "\n", trim: true)
      {:error, _} -> []
    end
  end
end

