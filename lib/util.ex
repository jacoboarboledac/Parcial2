defmodule Util do
  @moduledoc """
  Módulo de utilidades para manejo de entrada/salida.

  Este módulo puede ser reutilizado en otros programas para leer
  diferentes tipos de datos y manejar errores de entrada de manera
  consistente.
  """

  def leer(mensaje, :string) do
    IO.gets(mensaje)
    |> String.trim()
  end

  def leer(mensaje, :integer) do
    leer_con_parser(mensaje, &Integer.parse/1, 0)
  end

  def leer(mensaje, :float) do
    leer_con_parser(mensaje, &Float.parse/1, 0.0)
  end

  defp leer_con_parser(mensaje, funcion, valor_defecto) do
    valor =
      IO.gets(mensaje)
      |> String.trim()
      |> funcion.()

    case valor do
      {numero, ""} ->
        numero

      _ ->
        imprimir_error(
          "Error. Se utilizará #{valor_defecto} como valor predeterminado."
        )

        valor_defecto
    end
  end

  def imprimir_error(mensaje) do
    IO.puts(:standard_error, mensaje)
  end

  def imprimir_mensaje(mensaje) do
    IO.puts(mensaje)
  end
end
