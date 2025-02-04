# script para crear archivo csv varaible_capacity_factors.csv en base a ??
using CSV
using DataFrames
using Dates
using Statistics
using Random
using Printf
using Statistics  # Para la función quantile()

# sección 1, generación de perfiles de dias de bajo viento, y alto viento.

Input_url = "G:/Mi unidad/Trabajo_Centra/Catedra_AlmacenamientoLD/Switch/SEN/Fuentes/BD-Pelp-2023-2027/Base de Datos PELP 2023-2027 Informe Preliminar_v2/Rumbo a la CN en 2050/Input/Rumbo  a la Carbono Neutralidad_power/power.csv"
df = CSV.read(Input_url, DataFrame)
columnas_filtradas = [col for col in names(df) if col == "time" || occursin("_Eolica_", col)]
df_filtrado = df[:, columnas_filtradas]

# Crear un diccionario para almacenar los DataFrames
dataframes_grupos = Dict{String, DataFrame}()

Temporadas = ["Verano1","Invierno","Verano2"]
# Filtrar los grupos por filas
dataframes_grupos["Verano1"] = df_filtrado[1:96, :]      # Filas 1 a 96
dataframes_grupos["Invierno"] = df_filtrado[97:192, :]   # Filas 97 a 192
dataframes_grupos["Verano2"] = df_filtrado[193:288, :]   # Filas 193 a 288

# Mostrar el contenido del diccionario
for (nombre, df_grupo) in dataframes_grupos
    # println("Grupo: $nombre")
    # println(df_grupo)
end

column_names = names(df_filtrado)

# leer csv gen_info, de acá sacar la barra de cada generador, o mejor, agregarlos por barra.
df2 = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Inputs_LDES_Preliminar4/inputs/gen_info.csv", DataFrame)
df2_filtrado = filter(row -> occursin("Eolica_", string(row.GENERATION_PROJECT)), df2)

Barras = unique(df2_filtrado.gen_load_zone)

Profiles_Viento_Dict_Bajo_Verano1 = Dict{String, Vector{Float64}}()
Profiles_Viento_Dict_Alto_Verano1 = Dict{String, Vector{Float64}}()
Profiles_Viento_Dict_Bajo_Invierno = Dict{String, Vector{Float64}}()
Profiles_Viento_Dict_Alto_Invierno = Dict{String, Vector{Float64}}()
Profiles_Viento_Dict_Bajo_Verano2 = Dict{String, Vector{Float64}}()
Profiles_Viento_Dict_Alto_Verano2 = Dict{String, Vector{Float64}}()

Promedios_Viento_Dict_Bajo_Verano1 = Dict{String, Float64}()
Promedios_Viento_Dict_Alto_Verano1 = Dict{String, Float64}()
Promedios_Viento_Dict_Bajo_Invierno = Dict{String, Float64}()
Promedios_Viento_Dict_Alto_Invierno = Dict{String, Float64}()
Promedios_Viento_Dict_Bajo_Verano2 = Dict{String, Float64}()
Promedios_Viento_Dict_Alto_Verano2 = Dict{String, Float64}()

dias = [1:24, 25:48, 49:72, 73:96]

for i in Temporadas
    for column in column_names[2:end]
        # acá necesito encontrar cual es el día que en promedio tiene el menor viento de cada periodo de cuatro días para cada proyecto, al igual que el día con mayor viento.
        GENERATION_PROJECT = column[9:end]
        perfil_temporada = dataframes_grupos[i][!, column]
        # println(perfil_temporada)
        # println(GENERATION_PROJECT)

        # Calcular el promedio de cada dia
        promedios = [mean(perfil_temporada[g]) for g in dias]

        # Encontrar el dia con el menor promedio
        indice_menor_promedio = argmin(promedios)
        indice_mayor_promedio = argmax(promedios)
        
        # perfil diario de bajo o alto viento
        perfil_dia_bajo = perfil_temporada[dias[indice_menor_promedio]]
        perfil_dia_alto = perfil_temporada[dias[indice_mayor_promedio]]

        # println(indice_menor_promedio)
        # println(perfil_dia_bajo)

        # guardarlos en diccionarios
        if i == "Verano1"
            # perfiles
            Profiles_Viento_Dict_Bajo_Verano1[GENERATION_PROJECT] = perfil_dia_bajo
            Profiles_Viento_Dict_Alto_Verano1[GENERATION_PROJECT] = perfil_dia_alto
            # promedios
            Promedios_Viento_Dict_Bajo_Verano1[GENERATION_PROJECT] = promedios[indice_menor_promedio]
            Promedios_Viento_Dict_Alto_Verano1[GENERATION_PROJECT] = promedios[indice_mayor_promedio]
        elseif i == "Invierno"
            Profiles_Viento_Dict_Bajo_Invierno[GENERATION_PROJECT] = perfil_dia_bajo
            Profiles_Viento_Dict_Alto_Invierno[GENERATION_PROJECT] = perfil_dia_alto
            # promedios
            Promedios_Viento_Dict_Bajo_Invierno[GENERATION_PROJECT] = promedios[indice_menor_promedio]
            Promedios_Viento_Dict_Alto_Invierno[GENERATION_PROJECT] = promedios[indice_mayor_promedio]
        else
            Profiles_Viento_Dict_Bajo_Verano2[GENERATION_PROJECT] = perfil_dia_bajo
            Profiles_Viento_Dict_Alto_Verano2[GENERATION_PROJECT] = perfil_dia_alto
            # promedios
            Promedios_Viento_Dict_Bajo_Verano2[GENERATION_PROJECT] = promedios[indice_menor_promedio]
            Promedios_Viento_Dict_Alto_Verano2[GENERATION_PROJECT] = promedios[indice_mayor_promedio]
        end
    end
end


# guardar esos resultados y comparar luego entre los distintos generadores de cada barra. quedarse con el perfil del eolico que sea el percentil 2 y el 98 para dias de viento minimo y maximo respectivamente.
gen_info_por_barra_dict = Dict{String, DataFrame}()
Generador_Viento_Bajo_Barra_Verano1 = Dict{String, String}()
Generador_Viento_Bajo_Barra_Invierno = Dict{String, String}()
Generador_Viento_Bajo_Barra_Verano2 = Dict{String, String}()
Generador_Viento_Alto_Barra_Verano1 = Dict{String, String}()
Generador_Viento_Alto_Barra_Invierno = Dict{String, String}()
Generador_Viento_Alto_Barra_Verano2 = Dict{String, String}()
Perfil_Viento_Bajo_Barra_Verano1 = Dict{String, Vector{Float64}}()
Perfil_Viento_Bajo_Barra_Invierno = Dict{String, Vector{Float64}}()
Perfil_Viento_Bajo_Barra_Verano2 = Dict{String, Vector{Float64}}()
Perfil_Viento_Alto_Barra_Verano1 = Dict{String, Vector{Float64}}()
Perfil_Viento_Alto_Barra_Invierno = Dict{String, Vector{Float64}}()
Perfil_Viento_Alto_Barra_Verano2 = Dict{String, Vector{Float64}}()

# Iterar por los valores únicos y filtrar el DataFrame para cada uno
for valor in Barras
    # Filtrar las filas del DataFrame donde 'gen_load_zone' es igual al valor único
    sub_df = filter(row -> row.gen_load_zone == valor, df2_filtrado)
    # Almacenar el sub-DataFrame en el diccionario
    gen_info_por_barra_dict[valor] = sub_df
end

# Iterar sobre cada barra
for valor in Barras
    # Obtener el sub-DataFrame filtrado para la barra actual
    df_geninfo = gen_info_por_barra_dict[valor]
    
    # Obtener los nombres de los GENERATION_PROJECT
    generation_projects = df_geninfo.GENERATION_PROJECT
    
    # Para cada temporada (Verano1, Invierno, Verano2)
    for temporada in Temporadas
        # Extraer los promedios de viento bajo y alto para cada proyecto en la temporada actual
        prom_bajo_temp = []
        prom_alto_temp = []

        for proyecto in generation_projects
            if proyecto == "Eolica_Horizonte"
                proyecto = "Eolica_Antofagasta_15"
            elseif proyecto == "Eolica_Lomas_de_Taltal" || proyecto == "Eolica_Nolana" || proyecto == "Eolica_Pampa_Yolanda"
                proyecto = "Eolica_Antofagasta_16"
            elseif proyecto == "Eolica_Pampa_Fidelia"
                proyecto = "Eolica_Antofagasta_9"
            elseif proyecto == "Eolica_Marmoleras"
                proyecto = "Eolica_Antofagasta_4"
            end
            # Agregar los promedios de viento bajo y alto de los generadores al arreglo
            if temporada == "Verano1"
                push!(prom_bajo_temp, Promedios_Viento_Dict_Bajo_Verano1[proyecto])
                push!(prom_alto_temp, Promedios_Viento_Dict_Alto_Verano1[proyecto])
            elseif temporada == "Invierno"
                push!(prom_bajo_temp, Promedios_Viento_Dict_Bajo_Invierno[proyecto])
                push!(prom_alto_temp, Promedios_Viento_Dict_Alto_Invierno[proyecto])
            else
                push!(prom_bajo_temp, Promedios_Viento_Dict_Bajo_Verano2[proyecto])
                push!(prom_alto_temp, Promedios_Viento_Dict_Alto_Verano2[proyecto])
            end
        end

        # Calcular los percentiles 2 y 98 para los promedios de viento bajo y alto
        percentil_2_bajo = quantile(prom_bajo_temp, 0.02)
        percentil_98_bajo = quantile(prom_bajo_temp, 0.98)
        
        percentil_2_alto = quantile(prom_alto_temp, 0.02)
        percentil_98_alto = quantile(prom_alto_temp, 0.98)
        
        # Encontrar los proyectos límite para viento bajo (por debajo del percentil 2)
        proyecto_bajo_2 = nothing
        max_viento_bajo_2 = -Inf  # Para encontrar el proyecto con mayor viento bajo el percentil 2
        
        # Encontrar los proyectos límite para viento alto (por encima del percentil 98)
        proyecto_alto_98 = nothing
        min_viento_alto_98 = Inf  # Para encontrar el proyecto con menor viento sobre el percentil 98
        
        for proyecto in generation_projects
            if proyecto == "Eolica_Horizonte"
                proyecto = "Eolica_Antofagasta_15"
            elseif proyecto == "Eolica_Lomas_de_Taltal" || proyecto == "Eolica_Nolana" || proyecto == "Eolica_Pampa_Yolanda"
                proyecto = "Eolica_Antofagasta_16"
            elseif proyecto == "Eolica_Pampa_Fidelia"
                proyecto = "Eolica_Antofagasta_9"
            elseif proyecto == "Eolica_Marmoleras"
                proyecto = "Eolica_Antofagasta_4"
            end
            # Encontrar el proyecto con mayor viento por debajo del percentil 2
            if temporada == "Verano1"
                if Promedios_Viento_Dict_Bajo_Verano1[proyecto] <= percentil_2_bajo
                    if Promedios_Viento_Dict_Bajo_Verano1[proyecto] > max_viento_bajo_2
                        max_viento_bajo_2 = Promedios_Viento_Dict_Bajo_Verano1[proyecto]
                        proyecto_bajo_2 = proyecto
                        Generador_Viento_Bajo_Barra_Verano1[valor] = proyecto_bajo_2
                    end
                end
            elseif temporada == "Invierno"
                if Promedios_Viento_Dict_Bajo_Invierno[proyecto] <= percentil_2_bajo
                    if Promedios_Viento_Dict_Bajo_Invierno[proyecto] > max_viento_bajo_2
                        max_viento_bajo_2 = Promedios_Viento_Dict_Bajo_Invierno[proyecto]
                        proyecto_bajo_2 = proyecto
                        Generador_Viento_Bajo_Barra_Invierno[valor] = proyecto_bajo_2
                    end
                end
            else
                if Promedios_Viento_Dict_Bajo_Verano2[proyecto] <= percentil_2_bajo
                    if Promedios_Viento_Dict_Bajo_Verano2[proyecto] > max_viento_bajo_2
                        max_viento_bajo_2 = Promedios_Viento_Dict_Bajo_Verano2[proyecto]
                        proyecto_bajo_2 = proyecto
                        Generador_Viento_Bajo_Barra_Verano2[valor] = proyecto_bajo_2
                    end
                end
            end
            # Encontrar el proyecto con menor viento por encima del percentil 98
            if temporada == "Verano1"
                if Promedios_Viento_Dict_Alto_Verano1[proyecto] >= percentil_98_alto
                    if Promedios_Viento_Dict_Alto_Verano1[proyecto] < min_viento_alto_98
                        min_viento_alto_98 = Promedios_Viento_Dict_Alto_Verano1[proyecto]
                        proyecto_alto_98 = proyecto
                        Generador_Viento_Alto_Barra_Verano1[valor] = proyecto_alto_98
                    end
                end
            elseif temporada == "Invierno"
                if Promedios_Viento_Dict_Alto_Invierno[proyecto] >= percentil_98_alto
                    if Promedios_Viento_Dict_Alto_Invierno[proyecto] < min_viento_alto_98
                        min_viento_alto_98 = Promedios_Viento_Dict_Alto_Invierno[proyecto]
                        proyecto_alto_98 = proyecto
                        Generador_Viento_Alto_Barra_Invierno[valor] = proyecto_alto_98 
                    end
                end
            else
                if Promedios_Viento_Dict_Alto_Verano2[proyecto] >= percentil_98_alto
                    if Promedios_Viento_Dict_Alto_Verano2[proyecto] < min_viento_alto_98
                        min_viento_alto_98 = Promedios_Viento_Dict_Alto_Verano2[proyecto]
                        proyecto_alto_98 = proyecto
                        Generador_Viento_Alto_Barra_Verano2[valor] = proyecto_alto_98
                    end
                end
            end
        end

        # Almacenar los resultados para los proyectos límites
        if proyecto_bajo_2 != nothing
            if temporada == "Verano1"
                perfil_bajo_2 = Profiles_Viento_Dict_Bajo_Verano1[proyecto_bajo_2]
                Perfil_Viento_Bajo_Barra_Verano1[valor] = perfil_bajo_2
            elseif temporada == "Invierno"
                perfil_bajo_2 = Profiles_Viento_Dict_Bajo_Invierno[proyecto_bajo_2]
                Perfil_Viento_Bajo_Barra_Invierno[valor] = perfil_bajo_2
            else
                perfil_bajo_2 = Profiles_Viento_Dict_Bajo_Verano2[proyecto_bajo_2]
                Perfil_Viento_Bajo_Barra_Verano2[valor] = perfil_bajo_2
            end
            # println("Proyecto con mayor viento por debajo del percentil 2: $proyecto_bajo_2 - $perfil_bajo_2")
        else
            # println("No se encontró proyecto bajo el percentil 2 para la temporada $temporada.")
        end
        
        if proyecto_alto_98 != nothing
            if temporada == "Verano1"
                perfil_alto_98 = Profiles_Viento_Dict_Alto_Verano1[proyecto_alto_98]
                Perfil_Viento_Alto_Barra_Verano1[valor] = perfil_alto_98
            elseif temporada == "Invierno"
                perfil_alto_98 = Profiles_Viento_Dict_Alto_Invierno[proyecto_alto_98]
                Perfil_Viento_Alto_Barra_Invierno[valor] = perfil_alto_98
            else
                perfil_alto_98 = Profiles_Viento_Dict_Alto_Verano2[proyecto_alto_98]
                Perfil_Viento_Alto_Barra_Verano2[valor] = perfil_alto_98
            end
            # println("Proyecto con menor viento por encima del percentil 98: $proyecto_alto_98 - $perfil_alto_98")
        else
            # println("No se encontró proyecto por encima del percentil 98 para la temporada $temporada.")
        end
    end
end
# luego quedaría generar un perfil con granularidad 4 horaria. es decir. se tiene que generar un día con viento full, luego dos dias seguidos sin viento y por ultimo un día con viento nuevamente.
# para ello hay que ir promediando cada cuatro horas los valores de los perfiles de poco viento y harto viento.
# luego, teniendo estos perfiles listos se debe generar el archivo variable_capacity_factor de manera en que los perfiles custom queden en la posición que deberían, es decir, como el cuarto dia de la temporada que representa
# añadir un ruido si se puede a los perfiles para que no sean totalmente iguales a alguno que ya exista.
# hacer lo mismo para el caso solar. debería ser rapido. cambiar eolico por FV?




# sección 4, creación de archivo variable_capacity_factors
function generar_csv(input_url::String, output_csv_path::String)
    # leer archivo de generadores
    df = CSV.read(input_url, DataFrame)
    rows = []

    # Comparar cada fila con todas las demás filas
    # Definir años y número de días representativos
    años = [2020, 2023, 2026, 2029, 2030, 2031, 2033, 2040, 2050]
    horas = 0:23
    column_names = names(df)

    # Recorrer los nombres de las columnas desde la segunda hasta el final
    for column in column_names[3:end]
        GENERATION_PROJECT = column
        for año in años
            for día in 1:12
                for hora in horas
                    if día>=10
                        if hora>=10
                            time = "2019"*"-$día-"*"01-"*string(hora)*":00"
                            timepoint = string(año)*"$día"*"23"*string(hora)
                        else
                            time = "2019"*"-$día-"*"01-"*"0"*string(hora)*":00"
                            timepoint = string(año)*"$día"*"23"*"0"*string(hora)
                        end
                    else
                        if hora>=10
                            time = "2019"*"-0$día-"*"01-"*string(hora)*":00"
                            timepoint = string(año)*"0$día"*"23"*string(hora)
                        else
                            time = "2019"*"-0$día-"*"01-"*"0"*string(hora)*":00"
                            timepoint = string(año)*"0$día"*"23"*"0"*string(hora)
                        end
                    end
                    # Buscar la demanda para el timepoint
                    gen_max_capacity_factor = df[df[!, :time] .== time, GENERATION_PROJECT]
                    if isempty(gen_max_capacity_factor)
                        error("No se encontró demanda para el time $time")
                    end
                    push!(rows, (GENERATION_PROJECT, timepoint, gen_max_capacity_factor[1]))
                end
            end
        end
    end
    output_df = DataFrame(rows, [:GENERATION_PROJECT, :timepoint, :gen_max_capacity_factor])
    CSV.write(output_csv_path, output_df)
end
Input_url = "G:/Mi unidad/Trabajo_Centra/Catedra_AlmacenamientoLD/Switch/SEN/Fuentes/BD-Pelp-2023-2027/Base de Datos PELP 2023-2027 Informe Preliminar_v2/Rumbo a la CN en 2050/Input/Rumbo  a la Carbono Neutralidad_power/power.csv"
Output_url = "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/variable_capacity_factors/variable_capacity_factors2.csv"
generar_csv(Input_url, Output_url);