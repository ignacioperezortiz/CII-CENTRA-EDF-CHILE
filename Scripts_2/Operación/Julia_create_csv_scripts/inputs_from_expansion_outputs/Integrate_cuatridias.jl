using CSV
using DataFrames
using Dates
using Statistics
using Random
using Printf

# Asegúrate de que global_vars.jl esté en el mismo directorio o en el path de búsqueda de Julia
include("../global_vars.jl")

Cuatridays = ["04","08","12"]

Days = collect(0:364)

Temp1 = collect(0:121)
Temp2 = collect(122:243)
Temp3 = collect(244:364)

input_path = CURRENT_STUDY_CASE * CURRENT_INPUTS_FOLDER

# df_variable_capacity_factors = CSV.read(input_path * "variable_capacity_factors.csv", DataFrame)
all_filtered_dfs = Dict{String, Dict{String, Dict{String, DataFrame}}}() # Diccionario para guardar todos los DataFrames filtrados
all_dict_Peso = Dict{String, Dict{String, Int64}}() # Diccionario para guardar todos los all_dict_Peso

for cuatri in Cuatridays
    println(cuatri)
    # filtrar df para que en la columna timepoint solo tenga los días 4
    df_variable_capacity_factors = CSV.read(input_path * "variable_capacity_factors.csv", DataFrame)
    df_variable_capacity_factors.timepoint = string.(df_variable_capacity_factors.timepoint)
    df_variable_capacity_factors = filter(row -> length(row.timepoint) >= 6 && row.timepoint[5:6] == cuatri, df_variable_capacity_factors)

    # Crear un nuevo DataFrame para almacenar el resultado expandido
    df_expandido = DataFrame()

    # Obtener los nombres de las columnas excluyendo 'gen_max_capacity_factor'
    cols_sin_gen_max = names(df_variable_capacity_factors)[names(df_variable_capacity_factors) .!= "gen_max_capacity_factor"]

    # Iterar sobre las filas del DataFrame filtrado y copiarlas tres veces
    for i in 1:nrow(df_variable_capacity_factors)
        row = df_variable_capacity_factors[i, :]
        # Añadir la fila original
        push!(df_expandido, row)

        # Calcular el valor de la siguiente fila para la proyección lineal
        if i < nrow(df_variable_capacity_factors)
            next_row = df_variable_capacity_factors[i+1, :]
            val_actual = row.gen_max_capacity_factor
            val_siguiente = next_row.gen_max_capacity_factor
            delta = (val_siguiente - val_actual) / 4     # Dividimos entre 4 porque queremos 3 puntos intermedios
        else
            delta = 0 #si es el último elemento, el delta es 0
            val_actual = row.gen_max_capacity_factor
        end
        
        # Añadir las tres filas copiadas con la proyección lineal
        for j in 1:3
            new_row = Dict{String, Any}()
            for col in cols_sin_gen_max
                new_row[col] = row[col]
            end
            new_row["gen_max_capacity_factor"] = val_actual + j * delta
            push!(df_expandido, new_row)
        end
    end

    # Función para extraer un subconjunto de filas basado en un patrón repetitivo
    function extract_rows(df::DataFrame, start_offset::Int, num_rows::Int, repetition_interval::Int)
        extracted_df = DataFrame()
        total_rows = nrow(df)
        start_index = start_offset + 1     # Julia es 1-indexed
        while start_index <= total_rows
            end_index = min(start_index + num_rows - 1, total_rows) # Asegura no exceder el número de filas
            for i in start_index:end_index
                push!(extracted_df, df[i, :])
            end
            start_index += repetition_interval
        end
        return extracted_df
    end

    # Generar los 4 DataFrames con los rangos de filas especificados
    df1 = extract_rows(df_expandido, 0, 24, 96)         # Filas 1-24, 97-120, 193-216, etc.
    df2 = extract_rows(df_expandido, 24, 24, 96)         # Filas 25-48, 121-144, 217-240, etc.
    df3 = extract_rows(df_expandido, 48, 24, 96)         # Filas 49-72, 145-168, 241-264, etc.
    df4 = extract_rows(df_expandido, 72, 24, 96)         # Filas 73-96, 169-192, 265-288, etc.


    # Función para filtrar un DataFrame por los primeros 4 caracteres de la columna "timepoint"
    function filter_by_timepoint_prefix(df::DataFrame, prefixes::Vector{String})
        filtered_dfs = Dict{String, DataFrame}()
        for prefix in prefixes
            filtered_df = filter(row -> startswith(row.timepoint, prefix), df)
            filtered_dfs[prefix] = filtered_df
        end
        return filtered_dfs
    end

    # Obtener los prefijos únicos de los primeros 4 caracteres de la columna "timepoint" en cada DataFrame
    prefixes1 = unique(map(x -> x[1:4], df1.timepoint))
    prefixes2 = unique(map(x -> x[1:4], df2.timepoint))
    prefixes3 = unique(map(x -> x[1:4], df3.timepoint))
    prefixes4 = unique(map(x -> x[1:4], df4.timepoint))

    # Filtrar los DataFrames por los prefijos únicos
    filtered_dfs1 = filter_by_timepoint_prefix(df1, prefixes1)
    filtered_dfs2 = filter_by_timepoint_prefix(df2, prefixes2)
    filtered_dfs3 = filter_by_timepoint_prefix(df3, prefixes3)
    filtered_dfs4 = filter_by_timepoint_prefix(df4, prefixes4)

    # Mostrar los DataFrames filtrados
    # println("\nDataFrames filtrados para df1:")
    for (prefix, df) in filtered_dfs1
        # println("Prefijo: ", prefix)
        # println(df)
    end

    # println("\nDataFrames filtrados para df2:")
    for (prefix, df) in filtered_dfs2
        # println("Prefijo: ", prefix)
        # println(df)
    end

    # println("\nDataFrames filtrados para df3:")
    for (prefix, df) in filtered_dfs3
        # println("Prefijo: ", prefix)
        # println(df)
    end

    # println("\nDataFrames filtrados para df4:")
    for (prefix, df) in filtered_dfs4
        # println("Prefijo: ", prefix)
        # println(df)
    end

    # Guardar los DataFrames filtrados en el diccionario global
    all_filtered_dfs[cuatri] = Dict(
        "df1" => filtered_dfs1,
        "df2" => filtered_dfs2,
        "df3" => filtered_dfs3,
        "df4" => filtered_dfs4,
    )

    # Sobreescribir el archivo original con el DataFrame expandido
    #CSV.write(input_path * "variable_capacity_factors.csv", df_expandido) # Comentado para no sobreescribir
    # println("Archivos 'df1', 'df2', 'df3', y 'df4' y sus versiones filtradas generados exitosamente.")

    df_timeseries = CSV.read(input_path * "timeseries.csv", DataFrame)


    # Procesamiento de timeseries.csv para cada prefijo de filtered_dfs4
    # println("\nProcesamiento de timeseries.csv para cada prefijo de df4:")
    dict_Peso = Dict{String, Int64}() # Inicializar el diccionario aquí
    for (prefijo_df4, df_filtrado_df4) in filtered_dfs4 # Iterar sobre los prefijos y dataframes filtrados de df4
        println("Prefijo de df4: ", prefijo_df4) # Indicar el prefijo actual
        # Filtrar df_timeseries por ts_period coincidente con el prefijo de df4
        df_timeseries_filtrado = filter(row -> string(row.ts_period) == prefijo_df4, df_timeseries)
        df_timeseries_filtrado.TIMESERIES = string.(df_timeseries_filtrado.TIMESERIES)
        # Filtrar las filas de la columna TIMESERIES donde los caracteres 5 y 6 son cuatri
        df_timeseries_filtrado = filter(row -> length(row.TIMESERIES) >= 6 && row.TIMESERIES[5:6] == cuatri, df_timeseries_filtrado)

        if nrow(df_timeseries_filtrado) > 0
            # Acceder a la primera fila
            primera_fila = df_timeseries_filtrado[1, :]

            # Calcular el número de días
            numero_de_dias = primera_fila.ts_duration_of_tp * primera_fila.ts_scale_to_period

            # Calcular la duración del período en años
            prefijos_ordenados = sort(collect(keys(filtered_dfs4))) # Ordenar los prefijos para calcular la duración
            duracion_periodo_en_anios = 0
            indice_prefijo_actual = findfirst(x -> x == prefijo_df4, prefijos_ordenados) # Encontrar el índice del prefijo actual

            if indice_prefijo_actual !== nothing # Verificar que se encontró el prefijo
                if indice_prefijo_actual < length(prefijos_ordenados)
                    anio_actual = parse(Int, prefijo_df4)
                    anio_siguiente = parse(Int, prefijos_ordenados[indice_prefijo_actual + 1])
                    duracion_periodo_en_anios = anio_siguiente - anio_actual
                else
                    # Para el último período, la duración puede ser igual al período anterior o necesitar otra lógica.
                    # Aquí se asume que es igual al anterior para simplificar.   Deberías revisar si esta asunción es correcta.
                    if indice_prefijo_actual > 1
                        anio_anterior = parse(Int, prefijos_ordenados[indice_prefijo_actual - 1])
                        anio_actual = parse(Int, prefijo_df4)
                        duracion_periodo_en_anios = anio_actual - anio_anterior
                    else
                        duracion_periodo_en_anios = 1 #Si solo hay un periodo, se asume duración 1.
                    end
                end
            end
            # División y redondeo
            resultado_final = round(Int, numero_de_dias / duracion_periodo_en_anios)
            resultado_redondeado = round(Int, resultado_final / 4) * 4
            # println("Resultado final redondeado: ", resultado_redondeado)
            dict_Peso[prefijo_df4] = resultado_redondeado # Asignar al diccionario
        else
            # println("No hay filas que cumplan con los criterios para este prefijo.")
        end
    end
    # println("\nDiccionario all_dict_Peso:")
    # println(all_dict_Peso)
    all_dict_Peso[cuatri] = dict_Peso # Guardar el diccionario all_dict_Peso
end

println("\nTodos los DataFrames filtrados:")
# println(all_filtered_dfs)

println("\nTodos los diccionarios all_dict_Peso:")
# println(all_dict_Peso)

# ahora abrimos el csv variable_capacity_factors_sin_cuatridias y trabajamos sobre el para generar aprox30 perfiles identicos para cada mes.
# script para expandir variable capacity factors

# nueva sección de script: Selección de días entre los meses de cada tetramestre para luego asignar los perfiles a las carpetas.

function dias_por_mes_año(año::Int)
    dias_mes = Dict{String, Int}()
    for mes in 1:12
        primer_dia_mes = Date(año, mes, 1)
        ultimo_dia_mes = Date(año, mes == 12 ? 1 : mes + 1, 1) - Day(1)
        num_dias = dayofyear(ultimo_dia_mes) - dayofyear(primer_dia_mes) + 1
        nombre_mes = monthname(primer_dia_mes)
        dias_mes[nombre_mes] = num_dias
    end
    return dias_mes
end

# años_a_procesar = [2024, 2026, 2029]
años_a_procesar = sort(parse.(Int, collect(keys(all_dict_Peso["04"])))) # Modificación aquí

resultados = Dict{Int, Dict{String, Int}}()

for año in años_a_procesar
    resultados[año] = dias_por_mes_año(año)
end

println("Número de días por mes para los años especificados:")
for año in sort(collect(keys(resultados))) # Ordenar los años antes de imprimirlos
    println("\n$año:")
    for (mes, cantidad_dias) in resultados[año]
        println("  $mes: $cantidad_dias días")
    end
end

function seleccionar_dias_cuatrimestre(resultados::Dict{Int, Dict{String, Int}}, all_dict_Peso::Dict{String, Dict{String, Int}})
    anios_a_procesar = sort(collect(keys(resultados)))
    cuatrimestres = ["04", "08", "12"]
    resultados_finales = Dict{Int, Dict{String, Vector{Date}}}()

    for año in anios_a_procesar
        resultados_finales[año] = Dict{String, Vector{Date}}()
        dias_por_mes = resultados[año]
        println(año)
        for cuatri in cuatrimestres
            println(cuatri)
            resultados_finales[año][cuatri] = Vector{Date}()
            dias_cuatri = all_dict_Peso[cuatri][string(año)]
            dias_seleccionados = 0
            conjuntos_seleccionados = Set{Int}() # Para controlar los días ya seleccionados

            # Definir el rango de días para el cuatrimestre
            inicio_cuatri, fin_cuatri = 0, 0
            if cuatri == "04"
                inicio_cuatri = 1
                fin_cuatri = dias_por_mes["January"]+dias_por_mes["February"]+dias_por_mes["March"]+dias_por_mes["April"]
            elseif cuatri == "08"
                inicio_cuatri = dias_por_mes["January"]+dias_por_mes["February"]+dias_por_mes["March"]+dias_por_mes["April"] + 1
                fin_cuatri = dias_por_mes["January"]+dias_por_mes["February"]+dias_por_mes["March"]+dias_por_mes["April"]+dias_por_mes["May"] + dias_por_mes["June"] + dias_por_mes["July"] + dias_por_mes["August"]
            elseif cuatri == "12"
                inicio_cuatri = dias_por_mes["January"]+dias_por_mes["February"]+dias_por_mes["March"]+dias_por_mes["April"]+dias_por_mes["May"] + dias_por_mes["June"] + dias_por_mes["July"] + dias_por_mes["August"]+1
                fin_cuatri = dias_por_mes["January"]+dias_por_mes["February"]+dias_por_mes["March"]+dias_por_mes["April"]+dias_por_mes["May"] + dias_por_mes["June"] + dias_por_mes["July"] + dias_por_mes["August"]+dias_por_mes["September"] + dias_por_mes["October"] + dias_por_mes["November"] + dias_por_mes["December"]
            end
            
            # Convertir a Date
            fecha_inicio_cuatri = Date(año, 1, 1) + Day(inicio_cuatri - 1)
            fecha_fin_cuatri = Date(año, 1, 1) + Day(fin_cuatri - 1)

            while dias_seleccionados < dias_cuatri
                println(dias_seleccionados)
                # Generar un día de inicio aleatorio dentro del cuatrimestre
                dia_inicio_rango = rand(inicio_cuatri:(fin_cuatri - 3))
                fecha_inicio_seleccion = Date(año, 1, 1) + Day(dia_inicio_rango - 1)
                
                # Verificar que los 4 días no se crucen con otros seleccionados
                dias_a_verificar = collect(dia_inicio_rango:(dia_inicio_rango + 3))
                
                
                cruza = false
                for dia in dias_a_verificar
                    if dia in conjuntos_seleccionados
                        cruza = true
                        break
                    end
                end
                
                if !cruza
                    # Si no hay cruce, agregar los días seleccionados al conjunto y al resultado
                    for dia in dias_a_verificar
                        push!(conjuntos_seleccionados, dia)
                    end
                    push!(resultados_finales[año][cuatri], fecha_inicio_seleccion)
                    dias_seleccionados += 4
                end
                if dias_seleccionados >= dias_cuatri # Agregar esta condición para salir del bucle
                    break
                end
            end
        end
    end
    return resultados_finales
end


# Suponiendo que ya tienes los diccionarios 'resultados' y 'all_dict_Peso'
resultados_finales = seleccionar_dias_cuatrimestre(resultados, all_dict_Peso)

# Imprimir el resultado
for (año, cuatris) in resultados_finales
    println("\nPara el año $año:")
    for (cuatri, fechas_inicio) in cuatris
        println("  Cuatrimestre $cuatri:")
        for fecha in fechas_inicio
            println("    Día de inicio: $fecha")
        end
    end
end


println(CURRENT_STUDY_CASE)

# Suponiendo que ya tienes los diccionarios 'resultados' y 'all_dict_Peso'
resultados_finales = seleccionar_dias_cuatrimestre(resultados, all_dict_Peso)

# Imprimir el resultado
for (año, cuatris) in resultados_finales
    println("\nPara el año $año:")
    for (cuatri, fechas_inicio) in cuatris
        println("  Cuatrimestre $cuatri:")
        for fecha in fechas_inicio
            println("    Día de inicio: $fecha")
        end
    end
end

# Nuevo código para procesar los archivos CSV según los días seleccionados
for año in sort(collect(keys(resultados_finales)))
    año_str = string(año)     # Convertir el año a String para usarlo en la ruta
    carpeta_año = joinpath(CURRENT_STUDY_CASE, "inputs_$año_str")    # Construir la ruta de la carpeta del año
    if año_str == "2029" || año_str == "2030" || año_str == "2031" || año_str == "2033" || año_str == "2040" || año_str == "2050"
        for cuatri in Cuatridays
            for (indice_fecha_inicio, fecha_inicio_original) in enumerate(resultados_finales[año][cuatri])
                # Convertir la fecha de inicio a un número de día del año (1-365)
                dia_inicio_original = dayofyear(fecha_inicio_original)
                
                # Iterar sobre los 4 días del set
                for offset in 0:3
                    dia_actual = dia_inicio_original + offset
                    fecha_actual = Date(año, 1, 1) + Day(dia_actual - 1)
                    dia_actual_str = string(dia_actual-1)
                    
                    # Construir la ruta del archivo CSV
                    archivo_csv = joinpath(carpeta_año, "$dia_actual_str", "inputs_dispatch", "variable_capacity_factors.csv")

                    # Verificar si el archivo existe antes de intentar leerlo
                    if isfile(archivo_csv)
                        df_csv = CSV.read(archivo_csv, DataFrame)
                        df_csv.timepoint = string.(df_csv.timepoint) # Convertir la columna timepoint a String

                        # Calcular las fechas para los días a verificar
                        dias_a_verificar = [fecha_inicio_original + Day(i) for i in offset:3]
                        dias_a_verificar_str = [Dates.format(fecha, "YYYYmmdd") for fecha in dias_a_verificar]
                        
                        # Iterar sobre los dataframes df1 a df4, ajustando el rango de días a verificar
                        for df_index in (offset + 1):4
                            # Obtener el DataFrame correspondiente de all_filtered_dfs
                            df_para_asignar = all_filtered_dfs[cuatri]["df$(df_index)"][año_str]
                            
                            # Filtrar las filas del DataFrame df_csv para el día actual
                            println(dias_a_verificar_str[df_index - offset])
                            filas_para_actualizar = filter(row -> startswith(row.timepoint, dias_a_verificar_str[df_index - offset]), df_csv)
                            
                            if nrow(filas_para_actualizar) > 0 && nrow(df_para_asignar) > 0
                                # Asignar los valores de gen_max_capacity_factor
                                for j in 1:nrow(filas_para_actualizar)
                                    if j <= nrow(df_para_asignar)
                                        df_csv[findfirst(df_csv.timepoint .== filas_para_actualizar[j, :timepoint]), :gen_max_capacity_factor] = df_para_asignar[j, :gen_max_capacity_factor]
                                    end
                                end
                                println("Valores de gen_max_capacity_factor actualizados para el año $año, cuatrimestre $cuatri, día $(offset+1) del cuatridia que inicia con $dia_inicio_original en $archivo_csv para df$(df_index). Se actualizaron $(nrow(filas_para_actualizar)) filas.")
                            else
                                println("Advertencia: No se encontraron filas para actualizar o el DataFrame para asignar está vacío para el año $año, cuatrimestre $cuatri, día $(offset+1) del cuatridia que inicia con $dia_inicio_original en $archivo_csv para df$(df_index).")
                            end
                        end
                        # Sobrescribir el archivo CSV con los valores actualizados
                        CSV.write(archivo_csv, df_csv)
                        println("Archivo $archivo_csv sobrescrito con los valores de gen_max_capacity_factor actualizados.")
                    else
                        println("Advertencia: El archivo $archivo_csv no existe.")
                    end
                end
            end
        end
    end
end

# Guardar resultados_finales en CSV
for año in sort(collect(keys(resultados_finales)))
    año_str = string(año)
    df_resultados = DataFrame(Año = Int64[], Cuatrimestre = String[], Fecha_Inicio = Date[])
    
    for cuatri in Cuatridays
        for fecha_inicio in resultados_finales[año][cuatri]
            push!(df_resultados, (año, cuatri, fecha_inicio))
        end
    end
    
    # Crear el nombre del archivo CSV
    nombre_archivo_csv = joinpath(CURRENT_STUDY_CASE, "dias_seleccionados_$año.csv")
    
    # Guardar el DataFrame en un archivo CSV
    CSV.write(nombre_archivo_csv, df_resultados)
    println("Archivo CSV guardado: $nombre_archivo_csv")
end
