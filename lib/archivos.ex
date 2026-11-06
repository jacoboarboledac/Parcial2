defmodule Archivos do
  # Se numera ANTES de ignorar comentarios y líneas vacías.
  def lineas(ruta) do
    File.stream!(ruta)
    |> Stream.with_index(1)
    |> Stream.map(fn {texto, numero} -> {String.trim(texto), numero} end)
    |> Stream.reject(fn {texto, _} -> texto == "" or String.starts_with?(texto, "#") end)
  end

  def escribir(ruta, lineas, pantalla \\ false) do
    File.open!(ruta, [:write, :utf8], fn archivo ->
      Enum.each(lineas, &emitir(archivo, &1, pantalla))
    end)
  end

  def emitir(archivo, linea, pantalla \\ true) do
    IO.puts(archivo, linea)
    if pantalla, do: Util.imprimir_mensaje(linea)
  end

  def proteger(funcion) do
    funcion.()
  rescue
    error in [File.Error, IO.StreamError] ->
      Util.imprimir_error("No se pudo procesar un archivo: #{Exception.message(error)}")
      :error
  end

  def coordenada({fila, columna}), do: "{#{fila},#{columna}}"
end
