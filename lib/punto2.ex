defmodule Terreno do
  defstruct [:simbolo, :nombre, :transitable, :costo]

  def parse(linea) do
    case String.split(linea, ",") |> Enum.map(&String.trim/1) do
      [simbolo, nombre, transitable, costo] when simbolo != "" and nombre != "" ->
        case {transitable, Integer.parse(costo)} do
          {permiso, {valor, ""}} when permiso in ["si", "no"] and valor >= 0 ->
            {:ok,
             %__MODULE__{
               simbolo: simbolo,
               nombre: nombre,
               transitable: permiso == "si",
               costo: valor
             }}

          _ ->
            {:error, "transitable debe ser si/no y costo un entero no negativo"}
        end

      _ ->
        {:error, "se requieren simbolo,nombre,transitable,costo"}
    end
  end
end

defmodule Ruta do
  defstruct posiciones: [], costo: 0
  def movimientos(%__MODULE__{posiciones: posiciones}), do: length(posiciones) - 1

  def recorrido(%__MODULE__{posiciones: posiciones}) do
    Enum.map_join(posiciones, " -> ", &Archivos.coordenada/1)
  end
end

defmodule Punto2 do
  def ejecutar(base) do
    Archivos.proteger(fn ->
      salida = Path.join(base, "salidas/punto2")
      File.mkdir_p!(salida)
      Archivos.escribir(Path.join(salida, "rutas_isla.csv"), ["ruta;movimientos;costo;recorrido"])
      Archivos.escribir(Path.join(salida, "resumen_isla.txt"), [])
      Archivos.escribir(Path.join(salida, "validacion_isla.txt"), [])

      case cargar_terrenos(Path.join(base, "terrenos.csv")) do
        {:error, errores} ->
          reportar_invalido(salida, errores)

        {:ok, terrenos, roles} ->
          filas =
            Archivos.lineas(Path.join(base, "isla.txt"))
            |> Stream.map(fn {texto, _} -> String.split(texto) end)
            |> Enum.to_list()

          case validar(filas, terrenos, roles) do
            {:error, errores} ->
              reportar_invalido(salida, errores)

            {:ok, inicio, bote} ->
              Archivos.escribir(Path.join(salida, "validacion_isla.txt"), ["Mapa válido."])
              mapa = construir_mapa(filas, terrenos)
              rutas = buscar(mapa, inicio, bote)
              escribir_resultados(salida, filas, rutas)
          end
      end
    end)
  end

  defp reportar_invalido(salida, errores) do
    Archivos.escribir(Path.join(salida, "validacion_isla.txt"), errores, true)

    Archivos.escribir(
      Path.join(salida, "resumen_isla.txt"),
      ["No se realizó la búsqueda: hay errores de validación."],
      true
    )
  end

  defp cargar_terrenos(ruta) do
    {terrenos, errores} =
      Archivos.lineas(ruta)
      |> Stream.map(fn {texto, numero} -> {Terreno.parse(texto), numero, texto} end)
      |> Enum.reduce({%{}, []}, fn
        {{:ok, terreno}, numero, _}, {mapa, errores} ->
          if Map.has_key?(mapa, terreno.simbolo) do
            {mapa,
             errores ++ ["Línea #{numero} de terrenos.csv: símbolo repetido #{terreno.simbolo}"]}
          else
            {Map.put(mapa, terreno.simbolo, terreno), errores}
          end

        {{:error, motivo}, numero, texto}, {mapa, errores} ->
          {mapa, errores ++ ["Línea #{numero}: #{texto} -> #{motivo}"]}
      end)

    # Los símbolos se obtienen del CSV, mediante los nombres de estos tres roles.
    {roles, errores} =
      Enum.reduce(["inicio", "bote", "agua"], {%{}, errores}, fn nombre, {roles, errores} ->
        encontrados = terrenos |> Map.values() |> Enum.filter(&(&1.nombre == nombre))

        case encontrados do
          [terreno] ->
            permiso = nombre != "agua"

            if terreno.transitable == permiso do
              {Map.put(roles, nombre, terreno.simbolo), errores}
            else
              {roles,
               errores ++
                 [
                   "El terreno #{nombre} debe tener transitable=#{if permiso, do: "si", else: "no"}."
                 ]}
            end

          _ ->
            {roles,
             errores ++ ["terrenos.csv debe definir exactamente un terreno llamado #{nombre}."]}
        end
      end)

    if errores == [], do: {:ok, terrenos, roles}, else: {:error, errores}
  end

  # VALIDACIÓN: todas sus funciones auxiliares recorren listas con recursión propia.
  # No se utilizan Enum ni Stream en esta etapa.
  def validar([], _terrenos, _roles), do: {:error, ["El mapa está vacío."]}

  def validar([primera | _] = filas, terrenos, roles) do
    ancho = contar(primera)
    alto = contar(filas)

    {errores, inicios, botes} =
      validar_filas(filas, 0, alto, ancho, terrenos, roles, {[], [], []})

    errores =
      errores ++
        validar_cantidad(inicios, "iniciales", roles["inicio"]) ++
        validar_cantidad(botes, "de bote", roles["bote"])

    case {errores, inicios, botes} do
      {[], [inicio], [bote]} -> {:ok, inicio, bote}
      _ -> {:error, errores}
    end
  end

  defp contar([]), do: 0
  defp contar([_ | resto]), do: 1 + contar(resto)

  defp validar_filas([], _, _, _, _, _, acumulado), do: acumulado

  defp validar_filas([fila | resto], f, alto, ancho, terrenos, roles, {errores, inicios, botes}) do
    largo = contar(fila)

    errores =
      if largo == ancho,
        do: errores,
        else: errores ++ ["Fila #{f}: tiene #{largo} posiciones; se esperaban #{ancho}"]

    acumulado =
      validar_celdas(fila, f, 0, alto, ancho, largo, terrenos, roles, {errores, inicios, botes})

    validar_filas(resto, f + 1, alto, ancho, terrenos, roles, acumulado)
  end

  defp validar_celdas([], _, _, _, _, _, _, _, acumulado), do: acumulado

  defp validar_celdas(
         [simbolo | resto],
         f,
         c,
         alto,
         ancho,
         largo,
         terrenos,
         roles,
         {errores, inicios, botes}
       ) do
    pos = {f, c}

    errores =
      if Map.has_key?(terrenos, simbolo),
        do: errores,
        else: errores ++ ["Posición #{Archivos.coordenada(pos)}: símbolo desconocido #{simbolo}"]

    borde = f == 0 or f == alto - 1 or c == 0 or c == ancho - 1 or c == largo - 1

    errores =
      if borde and simbolo != roles["agua"],
        do:
          errores ++
            [
              "Posición #{Archivos.coordenada(pos)}: el borde debe ser agua (#{roles["agua"]}) y contiene #{simbolo}"
            ],
        else: errores

    inicios = if simbolo == roles["inicio"], do: inicios ++ [pos], else: inicios
    botes = if simbolo == roles["bote"], do: botes ++ [pos], else: botes

    validar_celdas(
      resto,
      f,
      c + 1,
      alto,
      ancho,
      largo,
      terrenos,
      roles,
      {errores, inicios, botes}
    )
  end

  defp validar_cantidad([_], _, _), do: []

  defp validar_cantidad(posiciones, nombre, simbolo) do
    [
      "Hay #{contar(posiciones)} posiciones #{nombre} #{simbolo}: #{unir_posiciones(posiciones)}; se requiere exactamente una."
    ]
  end

  defp unir_posiciones([]), do: "ninguna"
  defp unir_posiciones([pos]), do: Archivos.coordenada(pos)

  defp unir_posiciones([pos | resto]),
    do: Archivos.coordenada(pos) <> " y " <> unir_posiciones(resto)

  def construir_mapa(filas, terrenos) do
    filas
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {fila, f}, mapa ->
      fila
      |> Enum.with_index()
      |> Enum.reduce(mapa, fn {simbolo, c}, acc ->
        Map.put(acc, {f, c}, Map.fetch!(terrenos, simbolo))
      end)
    end)
  end

  def buscar(mapa, inicio, bote), do: explorar(mapa, inicio, bote, MapSet.new(), [], 0)

  defp explorar(mapa, pos, bote, visitados, camino, costo) do
    if MapSet.member?(visitados, pos) do
      []
    else
      avanzar(Map.get(mapa, pos), mapa, pos, bote, visitados, camino, costo)
    end
  end

  # Pattern matching sobre Terreno para descartar obstáculos.
  defp avanzar(nil, _, _, _, _, _, _), do: []
  defp avanzar(%Terreno{transitable: false}, _, _, _, _, _, _), do: []

  defp avanzar(
         %Terreno{transitable: true, costo: entrada},
         mapa,
         {f, c} = pos,
         bote,
         visitados,
         camino,
         costo
       ) do
    costo = costo + if(camino == [], do: 0, else: entrada)
    camino = [pos | camino]

    if pos == bote do
      [%Ruta{posiciones: Enum.reverse(camino), costo: costo}]
    else
      vecinos = [{f - 1, c}, {f + 1, c}, {f, c - 1}, {f, c + 1}]
      explorar_vecinos(vecinos, mapa, bote, MapSet.put(visitados, pos), camino, costo)
    end
  end

  defp explorar_vecinos([], _, _, _, _, _), do: []

  defp explorar_vecinos([pos | resto], mapa, bote, visitados, camino, costo) do
    explorar(mapa, pos, bote, visitados, camino, costo) ++
      explorar_vecinos(resto, mapa, bote, visitados, camino, costo)
  end

  defp escribir_resultados(salida, filas, rutas) do
    File.open!(Path.join(salida, "rutas_isla.csv"), [:write, :utf8], fn archivo ->
      IO.puts(archivo, "ruta;movimientos;costo;recorrido")

      rutas
      |> Enum.with_index(1)
      |> Enum.each(fn {ruta, numero} ->
        IO.puts(
          archivo,
          "#{numero};#{Ruta.movimientos(ruta)};#{ruta.costo};#{Ruta.recorrido(ruta)}"
        )

        Util.imprimir_mensaje("Ruta #{numero}: #{Ruta.recorrido(ruta)}")
        Util.imprimir_mensaje("Movimientos: #{Ruta.movimientos(ruta)}. Costo: #{ruta.costo}")
      end)
    end)

    File.open!(Path.join(salida, "resumen_isla.txt"), [:write, :utf8], fn archivo ->
      Archivos.emitir(archivo, "Número total de rutas: #{length(rutas)}")

      if rutas == [] do
        Archivos.emitir(archivo, "No existen rutas entre la posición inicial y el bote.")
      else
        minimo = rutas |> Enum.map(&Ruta.movimientos/1) |> Enum.min()
        Archivos.emitir(archivo, "Rutas más cortas: #{minimo} movimientos")

        rutas
        |> Enum.with_index(1)
        |> Enum.each(fn {ruta, numero} ->
          if Ruta.movimientos(ruta) == minimo,
            do: Archivos.emitir(archivo, "Ruta #{numero}: #{Ruta.recorrido(ruta)}")
        end)

        {mejor, numero} =
          rutas |> Enum.with_index(1) |> Enum.min_by(fn {ruta, _} -> ruta.costo end)

        Archivos.emitir(
          archivo,
          "Ruta de menor costo: #{numero}, costo #{mejor.costo} (#{Ruta.movimientos(mejor)} movimientos)"
        )

        Archivos.emitir(archivo, Ruta.recorrido(mejor))
        Archivos.emitir(archivo, "Mapa con la ruta de menor costo marcada con *:")
        marcadas = MapSet.new(mejor.posiciones)

        filas
        |> Enum.with_index()
        |> Enum.each(fn {fila, f} ->
          linea =
            fila
            |> Enum.with_index()
            |> Enum.map_join(" ", fn {simbolo, c} ->
              if MapSet.member?(marcadas, {f, c}), do: "*", else: simbolo
            end)

          Archivos.emitir(archivo, linea)
        end)
      end
    end)
  end
end
