defmodule Punto4 do
  # Referencia para comparar, NO para calcular las soluciones.
  # https://oeis.org/A000170 (el término n=0 se omite).
  @oeis %{
    1 => 1,
    2 => 0,
    3 => 0,
    4 => 2,
    5 => 10,
    6 => 4,
    7 => 40,
    8 => 92,
    9 => 352,
    10 => 724,
    11 => 2680,
    12 => 14200,
    13 => 73712,
    14 => 365_596,
    15 => 2_279_184,
    16 => 14_772_512,
    17 => 95_815_104,
    18 => 666_090_624,
    19 => 4_968_057_848,
    20 => 39_029_188_884
  }

  def ejecutar(base) do
    salida = Path.join(base, "salidas/punto4")
    Archivos.proteger(fn -> File.mkdir_p!(salida) end)
    Archivos.proteger(fn -> procesar_tamanos(base, salida) end)
    Archivos.proteger(fn -> verificar_archivo(base, salida) end)
    Archivos.proteger(fn -> primera_n20(salida) end)
    Archivos.proteger(fn -> escribir_secuencia(salida) end)
  end

  # Cada fila se elige cuando el consumidor solicita otra solución.
  # Las columnas y diagonales ocupadas permiten podar ramas inválidas.
  def soluciones(n) when is_integer(n) and n > 0 do
    buscar(0, n, [], MapSet.new(), MapSet.new(), MapSet.new())
  end

  defp buscar(n, n, reinas, _, _, _) do
    Stream.map([reinas], &Enum.reverse/1)
  end

  defp buscar(fila, n, reinas, columnas, diagonales1, diagonales2) do
    0..(n - 1)
    |> Stream.filter(fn columna ->
      not MapSet.member?(columnas, columna) and
        not MapSet.member?(diagonales1, fila - columna) and
        not MapSet.member?(diagonales2, fila + columna)
    end)
    |> Stream.flat_map(fn columna ->
      buscar(
        fila + 1,
        n,
        [columna | reinas],
        MapSet.put(columnas, columna),
        MapSet.put(diagonales1, fila - columna),
        MapSet.put(diagonales2, fila + columna)
      )
    end)
  end

  defp procesar_tamanos(base, salida) do
    File.open!(Path.join(salida, "errores_tamanos.txt"), [:write, :utf8], fn errores ->
      Archivos.lineas(Path.join(base, "tamanos.txt"))
      |> Stream.map(fn {texto, linea} -> {Integer.parse(texto), texto, linea} end)
      |> Enum.each(fn
        {{n, ""}, _, _} when n > 0 ->
          File.open!(Path.join(salida, "reinas_n#{n}.txt"), [:write, :utf8], fn archivo ->
            total =
              soluciones(n)
              |> Enum.reduce(0, fn tablero, cantidad ->
                escribir_tablero(archivo, tablero, cantidad + 1)
                cantidad + 1
              end)

            Archivos.emitir(archivo, "Número total de soluciones para N=#{n}: #{total}")
          end)

        {_, texto, linea} ->
          Archivos.emitir(errores, "Línea #{linea}: #{texto} -> debe ser un entero positivo")
      end)
    end)
  end

  defp escribir_tablero(archivo, tablero, numero) do
    n = length(tablero)
    Archivos.emitir(archivo, "Solución #{numero}:")

    tablero
    |> Enum.with_index()
    |> Enum.each(fn {columna_reina, _fila} ->
      linea =
        Enum.map_join(0..(n - 1), " ", fn columna ->
          if columna == columna_reina, do: "Q", else: "."
        end)

      Archivos.emitir(archivo, linea)
    end)

    posiciones =
      tablero
      |> Enum.with_index()
      |> Enum.map_join(" ", fn {c, f} ->
        Archivos.coordenada({f, c})
      end)

    Archivos.emitir(archivo, "Posiciones: #{posiciones}")
    Archivos.emitir(archivo, "")
  end

  defp primera_n20(salida) do
    File.open!(Path.join(salida, "primera_solucion_n20.txt"), [:write, :utf8], fn archivo ->
      # take(1) detiene la enumeración inmediatamente después de la primera solución.
      soluciones(20) |> Stream.take(1) |> Enum.each(&escribir_tablero(archivo, &1, 1))
    end)
  end

  # VALIDACIÓN: recorrido recursivo de valores y de TODOS los pares.
  # Este bloque y sus auxiliares no usan Enum ni Stream.
  def validar_propuesta(texto) do
    tokens = String.split(texto)
    n = contar(tokens)
    {reinas, errores} = convertir(tokens, 0, n)
    errores = errores ++ conflictos(reinas)
    if n == 0, do: ["tablero vacío" | errores], else: errores
  end

  defp contar([]), do: 0
  defp contar([_ | resto]), do: 1 + contar(resto)

  defp convertir([], _, _), do: {[], []}

  defp convertir([texto | resto], fila, n) do
    {reinas, errores} = convertir(resto, fila + 1, n)

    case Integer.parse(texto) do
      {columna, ""} ->
        actuales =
          if columna < 0 or columna >= n,
            do: ["fila #{fila}: la columna #{columna} está fuera de un tablero de #{n} × #{n}"],
            else: []

        {[{fila, columna} | reinas], actuales ++ errores}

      _ ->
        {reinas, ["fila #{fila}: #{texto} no es una columna entera" | errores]}
    end
  end

  defp conflictos([]), do: []
  defp conflictos([reina | resto]), do: comparar(reina, resto) ++ conflictos(resto)

  defp comparar(_, []), do: []

  defp comparar({f1, c1} = a, [{f2, c2} = b | resto]) do
    motivo =
      cond do
        c1 == c2 -> "misma columna"
        abs(f1 - f2) == abs(c1 - c2) -> "misma diagonal"
        true -> nil
      end

    actuales =
      if motivo,
        do: ["reinas #{Archivos.coordenada(a)} y #{Archivos.coordenada(b)} en la #{motivo}"],
        else: []

    actuales ++ comparar(a, resto)
  end

  defp unir_errores([]), do: ""
  defp unir_errores([error]), do: error
  defp unir_errores([error | resto]), do: error <> "; " <> unir_errores(resto)

  defp verificar_archivo(base, salida) do
    lineas =
      Archivos.lineas(Path.join(base, "propuestas.txt"))
      |> Stream.map(fn {texto, numero} ->
        resultado =
          case validar_propuesta(texto) do
            [] -> "válida"
            errores -> "inválida: " <> unir_errores(errores)
          end

        "Línea #{numero}: #{texto} -> #{resultado}"
      end)

    Archivos.escribir(Path.join(salida, "verificacion_reinas.txt"), lineas, true)
  end

  def secuencia do
    Stream.iterate(1, &(&1 + 1))
    |> Stream.map(fn n ->
      inicio = System.monotonic_time(:microsecond)
      cantidad = soluciones(n) |> Enum.count()
      tiempo_ms = (System.monotonic_time(:microsecond) - inicio) / 1000
      {n, cantidad, tiempo_ms}
    end)
  end

  def escribir_secuencia(salida, limite_ms \\ 10_000) do
    File.open!(Path.join(salida, "secuencia_reinas.csv"), [:write, :utf8], fn archivo ->
      File.open!(Path.join(salida, "comparacion_oeis.txt"), [:write, :utf8], fn comparacion ->
        File.open!(Path.join(salida, "limite_secuencia.txt"), [:write, :utf8], fn limite ->
          IO.puts(archivo, "n;soluciones;tiempo_ms")
          IO.puts(comparacion, "Referencia: https://oeis.org/A000170")

          secuencia()
          |> Stream.take_while(fn {n, cantidad, tiempo} ->
            if tiempo < limite_ms do
              true
            else
              Archivos.emitir(
                limite,
                "N=#{n}: #{cantidad} soluciones; #{tiempo} ms. Se calculó completo, pero no se incluye en secuencia_reinas.csv porque no tardó menos de #{limite_ms} ms."
              )

              false
            end
          end)
          |> Enum.each(fn {n, cantidad, tiempo} ->
            Archivos.emitir(archivo, "#{n};#{cantidad};#{tiempo}")
            esperado = Map.get(@oeis, n)

            resultado =
              cond do
                esperado == nil -> "sin referencia local para este N; consultar OEIS"
                esperado == cantidad -> "coincide con OEIS (#{esperado})"
                true -> "NO coincide; OEIS indica #{esperado}"
              end

            Archivos.emitir(comparacion, "N=#{n}: #{cantidad}; #{resultado}")
          end)
        end)
      end)
    end)
  end
end
