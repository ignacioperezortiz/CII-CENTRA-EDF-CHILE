# genera el csv de demanda, debe seleccionarse la loadzone.
using CSV
using DataFrames
using Dates
using Statistics
using Random


escenarios = ["Bajo"]
nombre_escenario = Dict(
    "Alto" => "transicion_acelerada",
    "Medio" => "rumbo_CN",
    "Bajo" => "recuperacion_lenta"
)

for h in escenarios
    escenario_pelp = nombre_escenario[h]
    # Diccionario de traducción de zonas
    catalogo_zonas = Dict(
        "Arica y Parinacota" => "L_Parinacota220",
        "Tarapaca" => "L_Lagunas220",
        "Tarapaca_2" => "L_NuevaPozoAlmonte220",
        "Antofagasta" => "L_Kimal220",
        "Antofagasta_2" => "L_LosChangos500",
        "Antofagasta_3" => "L_Parinas500",
        "Antofagasta_4" => "L_LosChangos220",
        "Antofagasta_5" => "L_Kimal500",
        "Antofagasta_5H2" => "L_Kimal500H2",
        "Antofagasta_7" => "L_NuevaZaldivar220",
        "Los Lagos" => "L_NuevaPuertoMontt500",
        "Los Lagos_2" => "L_NuevaAncud500",
        "Atacama" => "L_NuevaMaitencillo500",
        "Atacama_2" => "L_Cumbre500",
        "Atacama_3" => "L_NuevaCardones500",
        "Los Rios" => "L_Pichirropulli500",
        "Coquimbo" => "L_NuevaPandeAzucar500",
        "Bio Bio" => "L_Mulchen500",
        "Bio Bio_2" => "L_Concepcion500",
        "Bio Bio_3" => "L_NuevaCharrua500",
        "Bio Bio_3H2" => "L_NuevaCharrua500H2",
        "Libertador General Bernardo Ohiggins_2" => "L_Candelaria500",
        "Libertador General Bernardo Ohiggins" => "L_Rapel500",
        "Metropolitana de Santiago" => "L_AltoJahuel500",
        "Metropolitana de Santiago_2" => "L_Polpaico500",
        "Maule" => "L_Ancoa500",
        "Valparaiso" => "L_Quillota500",
        "Araucania" => "L_RioMalleco500",
        "Metropolitana de Santiago_2H2" => "L_Polpaico500H2"
    )
    Load_zones = collect(keys(catalogo_zonas))
    function generar_csv(load_zone::String, demanda_csv_path::String, output_csv_path::String)
        # Traducir el nombre de la zona
        zone_name = get(catalogo_zonas, load_zone, nothing)
        if zone_name === nothing
            error("Zona no encontrada en el catálogo")
        end

        # Leer el archivo de demanda
        demanda_df = CSV.read(demanda_csv_path, DataFrame)
        filter!(row -> row.scenario == "$escenario_pelp", demanda_df)    ### 

        # Definir años y número de días representativos
        años = [2024, 2026, 2029, 2030, 2031, 2033, 2040, 2050]
        horas = 0:23

        # Crear una lista para almacenar los datos
        rows = []
        mes = 0

        # Asegurarse de que la zona existe en las columnas
        if !(zone_name in names(demanda_df))
            for año in años
                for día in 1:12
                    mes = mes + 1
                    for hora in horas
                        if día>=10
                            if hora>=10
                                time = string(año)*"-$día-"*"01-"*string(hora)*":00"
                                timepoint = string(año)*"$día"*"23"*string(hora)
                            else
                                time = string(año)*"-$día-"*"01-"*"0"*string(hora)*":00"
                                timepoint = string(año)*"$día"*"23"*"0"*string(hora)
                            end
                        else
                            if hora>=10
                                time = string(año)*"-0$día-"*"01-"*string(hora)*":00"
                                timepoint = string(año)*"0$día"*"23"*string(hora)
                            else
                                time = string(año)*"-0$día-"*"01-"*"0"*string(hora)*":00"
                                timepoint = string(año)*"0$día"*"23"*"0"*string(hora)
                            end
                        end
                        # Buscar la demanda para el timepoint
                        demanda = 0
                        if isempty(demanda)
                            error("No se encontró demanda para el time $time")
                        end
                        push!(rows, (load_zone, timepoint, demanda[1]))
                    end
                end
            end
        else 
            for año in años
                for día in 1:12
                    mes = mes + 1
                    for hora in horas
                        if día>=10
                            if hora>=10
                                time = string(año)*"-$día-"*"01-"*string(hora)*":00"
                                timepoint = string(año)*"$día"*"23"*string(hora)
                            else
                                time = string(año)*"-$día-"*"01-"*"0"*string(hora)*":00"
                                timepoint = string(año)*"$día"*"23"*"0"*string(hora)
                            end
                        else
                            if hora>=10
                                time = string(año)*"-0$día-"*"01-"*string(hora)*":00"
                                timepoint = string(año)*"0$día"*"23"*string(hora)
                            else
                                time = string(año)*"-0$día-"*"01-"*"0"*string(hora)*":00"
                                timepoint = string(año)*"0$día"*"23"*"0"*string(hora)
                            end
                        end
                        # Buscar la demanda para el timepoint
                        demanda = demanda_df[demanda_df[!, :time] .== time, zone_name]
                        if isempty(demanda)
                            error("No se encontró demanda para el time $time")
                        end
                        push!(rows, (load_zone, timepoint, demanda[1]))
                    end
                end
            end
        end
        # Crear DataFrame y guardar como CSV
        output_df = DataFrame(rows, [:LOAD_ZONE, :TIMEPOINT, :zone_demand_mw])
        println(length(output_df.LOAD_ZONE))
        CSV.write(output_csv_path, output_df)
    end

    # definición de variables y llamar a función
    for i in Load_zones
        Load_zone = i
        demanda_filename = "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/demanda.csv"
        generar_csv(Load_zone, demanda_filename, "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Rumbo_CN/demand_csv_inputs_loadzone/$Load_zone.csv")
    end
end


## sección agregada 12-09-2024 
## añadir a csv la proyección de demanda de cada uno de los nodos tipo gx node.

# necesitamos los timepoints...
# Se definen los parametros base para la ejecucion del script

ts_duration_of_tp = 1
ts_num_tps = 24
last_period_duration = 10 #years
base_year_duration = 365.25
start_years = [2024, 2026, 2029, 2030, 2031, 2033, 2040, 2050]
months = 1:12

#Se crean las horas dependiendo de la duracion en horas de cada timepoint
if 24 % ts_duration_of_tp != 0
    println("El valor de ts_duration_of_tp debe ser un divisor de 24")
    return 0
end
hours = 0:ts_duration_of_tp:23
#El array de dias se debe poner a mano dependiendo de la combinacion de ts_duration_of_tp y ts_num_tps
days = [23]
#En caso que la cantidad de dias en el array sea mayor a la cantidad de dias calculados por ts_duration_of_tp y ts_num_tps, se detiene la ejecucion
if length(days) > (ts_duration_of_tp*ts_num_tps)/24
    println("La cantidad de días en el array dias debe ser consistente con ts_duration_of_tp*ts_num_tps")
    return 0
end

#Se genera un diccionario con los array base para la generacion de los archivos
base_arrays_dict = Dict(
    "base_year_duration" => base_year_duration,
    "start_years" => start_years,
    "last_period_duration" => last_period_duration,
    "months" => months,
    "ts_duration_of_tp" => ts_duration_of_tp,
    "ts_num_tps" => ts_num_tps,
    "days" => days,
    "hours" => hours,
)

# periods.csv
# Función para generar el DataFrame a partir de los años de inicio

function generate_periods(base_arrays_dict::Dict)
    #La funcion vcat permite generar un array al unir desde el segundo elemento con la ultima fecha que le suma last_period_duration a la ultima fecha del array
    periods = DataFrame(INVESTMENT_PERIOD = base_arrays_dict["start_years"], period_start = base_arrays_dict["start_years"], period_end = vcat(base_arrays_dict["start_years"][2:end], base_arrays_dict["start_years"][end] + base_arrays_dict["last_period_duration"]))
end

# Lista de años de inicio

# Generar el DataFrame
generate_periods(base_arrays_dict)

# timepoints.csv
function generate_timepoints(base_arrays_dict::Dict)
    # Crear una lista para almacenar los datos
    n_rows = length(base_arrays_dict["start_years"]) * length(base_arrays_dict["months"]) * length(base_arrays_dict["hours"])
    rows = Vector{Tuple{String, String, String}}(undef, n_rows)

    # Asegurarse de que la zona existe en las columnas
    idx = 1
    for year in base_arrays_dict["start_years"]
        for month in base_arrays_dict["months"]
            month_str = month < 10 ? "0$month" : string(month)
            for day in base_arrays_dict["days"]
                day_str = day < 10 ? "0$day" : string(day)
                for hour in base_arrays_dict["hours"]
                    hour_str = hour < 10 ? "0$hour" : string(hour)
                    time = "$year-$month_str-$day_str-$hour_str:00"
                    timepoint = "$year$month_str$day_str$hour_str"
                    timeseries = "$year$month_str$day_str"
                    rows[idx] = (timepoint, time, timeseries)
                    idx += 1
                end
            end
        end
    end 
    output_df = DataFrame(rows, [:timepoint_id, :timestamp, :timeseries])
    return output_df
end

timepoints_df = generate_timepoints(base_arrays_dict)
timepoints_vect = timepoints_df.timepoint_id
timestamp_vect = timepoints_df.timestamp
catalogo_zonas1 = Dict(
    "Arica y Parinacota" => "Parinacota220",
    "Tarapaca" => "Lagunas220",
    "Tarapaca_2" => "NuevaPozoAlmonte220",
    "Antofagasta" => "Kimal220",
    "Antofagasta_2" => "LosChangos500",
    "Antofagasta_3" => "Parinas500",
    "Antofagasta_4" => "LosChangos220",
    "Antofagasta_5" => "Kimal500",
    "Antofagasta_5H2" => "Kimal500H2",
    "Antofagasta_7" => "NuevaZaldivar220",
    "Los Lagos" => "NuevaPuertoMontt500",
    "Los Lagos_2" => "NuevaAncud500",
    "Atacama" => "NuevaMaitencillo500",
    "Atacama_2" => "Cumbre500",
    "Atacama_3" => "NuevaCardones500",
    "Los Rios" => "Pichirropulli500",
    "Coquimbo" => "NuevaPandeAzucar500",
    "Bio Bio" => "Mulchen500",
    "Bio Bio_2" => "Concepcion500",
    "Bio Bio_3" => "NuevaCharrua500",
    "Bio Bio_3H2" => "NuevaCharrua500H2",
    "Libertador General Bernardo Ohiggins_2" => "Candelaria500",
    "Libertador General Bernardo Ohiggins" => "Rapel500",
    "Metropolitana de Santiago" => "AltoJahuel500",
    "Metropolitana de Santiago_2" => "Polpaico500",
    "Maule" => "Ancoa500",
    "Valparaiso" => "Quillota500",
    "Araucania" => "RioMalleco500",
    "Metropolitana de Santiago_2H2" => "Polpaico500H2"
)
catalogo_zonas = Dict(v => k for (k, v) in catalogo_zonas1)

function generar_csv2(input_url::String, Output_url::String, catalogo_zonas::Dict, timestamp_vect::Vector, timepoints_vect::Vector)
    # leer archivo de generadores
    df = CSV.read(input_url, DataFrame)
    filter!(row -> row.connected == 1, df)
    rows = []

    for i in 1:length(df.name)
        GENERATION_PROJECT = df.name[i]
        LOAD_ZONE = "Gxnode-"*GENERATION_PROJECT*"-"*catalogo_zonas[df.busbar[i]]
        for j in 1:length(timestamp_vect)
            # Buscar la demanda para el timepoint
            time = timestamp_vect[j]
            timepoint = timepoints_vect[j]
            demanda = 0
            push!(rows, (LOAD_ZONE, timepoint, demanda))
        end
    end
    # Crear DataFrame y guardar como CSV
    output_df = DataFrame(rows, [:LOAD_ZONE, :TIMEPOINT, :zone_demand_mw])
    # println(output_df)
    CSV.write(Output_url, output_df)
end
Input_url = "G:/Mi unidad/Trabajo_Centra/Catedra_AlmacenamientoLD/Switch/SEN/Fuentes/BD-Pelp-2023-2027/Base de Datos PELP 2023-2027 Informe Preliminar_v2/Rumbo a la CN en 2050/Input/Rumbo  a la Carbono Neutralidad_ThermalGenerator.csv"
Output_url = "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Rumbo_CN/demand_csv_inputs_loadzone/demand_load_zones_termo.csv"
generar_csv2(Input_url, Output_url, catalogo_zonas, timestamp_vect, timepoints_vect)



using CSV
using DataFrames

# Directorio que contiene los archivos CSV
directorio = "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Rumbo_CN/demand_csv_inputs_loadzone"

# Archivo CSV combinado
archivo_combinado = "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Rumbo_CN/demand.csv"

# Obtener una lista de todos los archivos CSV en el directorio
archivos_csv = filter(x -> endswith(x, ".csv"), readdir(directorio, join=true))

# Verificar si hay archivos CSV
if isempty(archivos_csv)
    println("No se encontraron archivos CSV en el directorio.")
    exit()
end

# Abrir el archivo combinado para escritura
open(archivo_combinado, "w") do archivo
    # Procesar el primer archivo CSV
    primer_archivo = archivos_csv[1]
    df_primer = CSV.read(primer_archivo, DataFrame)
    CSV.write(archivo, df_primer; append=false)  # Escribir el primer archivo CSV incluyendo las cabeceras
    
    # Procesar los archivos CSV restantes
    for archivo_csv in archivos_csv[2:end]
        df = CSV.read(archivo_csv, DataFrame)
        CSV.write(archivo, df; append=true, header=false)  # Escribir sin cabeceras
    end
end

println("Los archivos CSV han sido combinados en $archivo_combinado")


# segunda parte: procesamiento y generación de un nuevo perfil para el dia 4, 8 y 12.

# genera el csv de demanda, debe seleccionarse la loadzone.
using CSV
using DataFrames
using Dates
using Statistics
using Random

# Cargar el archivo CSV en un DataFrame
df1 = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/demand.csv", DataFrame)
df = df1[1:66816, :]
df2 = df1[66817:end, :]
# Función para calcular el promedio de cada bloque de 4 horas (de 0-3, 4-7, ..., 20-23)
function calcular_promedios_4_horas(dia_df)
    promedios = Float64[]
    for i in 1:4:96
        # Tomamos las 4 primeras horas de cada día
        # println(dia_df.zone_demand_mw[i:min(i+3, end)])
        push!(promedios, mean(dia_df.zone_demand_mw[i:min(i+3, end)]))
    end
    return promedios
end

# Obtener las zonas de carga únicas (sin usar groupby)
loadzones = unique(df.LOAD_ZONE)

# Iterar sobre cada loadzone
for loadzone in loadzones
    # Filtrar el DataFrame para cada loadzone
    loadzone_df = filter(row -> row.LOAD_ZONE == loadzone, df)
    
    # Obtener los años únicos en los timepoints de este loadzone
    años = [2024, 2026, 2029, 2030, 2031, 2033, 2040, 2050]

    # Iterar sobre cada año
    for año in años
        # Filtrar los datos para el año actual
        year_df = filter(row -> string(row.TIMEPOINT)[1:4] == string(año), loadzone_df)
        # println(year_df)

        # Procesar los días 4, 8 y 12
        for día in ["04", "08", "12"]
            # Filtrar los timepoints correspondientes al día actual
            day_df = filter(row -> string(row.TIMEPOINT)[5:6] == día, year_df)
            
            # Para los días previos (1-4, 5-8, 9-12), calculamos el promedio cada 4 horas
            if día == "04"
                # Para el día 4, calculamos los promedios de los días 1-4
                dias_previos = filter(row -> parse(Int, string(row.TIMEPOINT)[5:6]) <= 4, year_df)
                # println(dias_previos)
                promedios_previos = calcular_promedios_4_horas(dias_previos)
                # println(promedios_previos)
            elseif día == "08"
                # Para el día 8, calculamos los promedios de los días 5-8
                dias_previos = filter(row -> parse(Int, string(row.TIMEPOINT)[5:6]) >= 5 && parse(Int, string(row.TIMEPOINT)[5:6]) <= 8, year_df)
                # println(dias_previos)
                promedios_previos = calcular_promedios_4_horas(dias_previos)
                # println(promedios_previos)
            elseif día == "12"
                # Para el día 12, calculamos los promedios de los días 9-12
                dias_previos = filter(row -> parse(Int, string(row.TIMEPOINT)[5:6]) >= 9 && parse(Int, string(row.TIMEPOINT)[5:6]) <= 12, year_df)
                # println(dias_previos)
                promedios_previos = calcular_promedios_4_horas(dias_previos)
                # println(promedios_previos)
            end
            # Asegurarnos de que estamos distribuyendo los promedios correctamente
            for (i, timepoint) in enumerate(day_df.TIMEPOINT)
                # Crear una condición booleana para buscar el índice
                condition = (df.LOAD_ZONE .== loadzone) .& (df.TIMEPOINT .== day_df.TIMEPOINT[i])

                # Encontrar el índice donde se cumple la condición
                idx = findall(condition)

                # Asegurarnos de que el número de promedios sea suficiente
                if !isempty(idx) && i <= length(promedios_previos)
                    df.zone_demand_mw[idx[1]] = promedios_previos[i]
                else
                    println("Índice fuera de rango para los promedios")
                end
            end
        end
    end
end

# combinar los dos df
df_combined = vcat(df, df2)

# Guardar el archivo con los valores actualizados
CSV.write("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/load.csv", df_combined)