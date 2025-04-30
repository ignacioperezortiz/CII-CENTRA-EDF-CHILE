using CSV
using DataFrames
using Dates
using Statistics
using Random
using Printf


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

function generar_csv(input_url::String, output_csv_path::String, catalogo_zonas::Dict)
    # leer archivo de generadores
    df_branch = CSV.read(input_url, DataFrame)
    df_branch2 = filter!(row -> row.connected == 1, df_branch)
    df = filter!(row -> row.candidate == 0, df_branch2)
    rows = []

    # Comparar cada fila con todas las demás filas
    equivalente_df = DataFrame(Index1 = Int[], Index2 = Int[], Busbari = String[], Busbarf = String[])
    for i in 1:nrow(df)
        for j in i+1:nrow(df)
            if df.busbari[i] == df.busbari[j] && df.busbarf[i] == df.busbarf[j] || df.busbari[i] == df.busbarf[j] && df.busbarf[i] == df.busbari[j]
                if df.start_time[i][1:4] <= df.start_time[j][1:4]
                    push!(equivalente_df, (i, j, df.busbari[i], df.busbarf[i]))
                else
                    push!(equivalente_df, (j, i, df.busbari[i], df.busbarf[i]))
                end
            end
        end
    end

    # Crear un conjunto de índices que representan filas con ampliaciones
    ampliaciones_ids = []
    for row in eachrow(equivalente_df)
        push!(ampliaciones_ids, row.Index1)
        push!(ampliaciones_ids, row.Index2)
    end

    sin_ampliacion_ids = [i for i in 1:nrow(df) if !(i in ampliaciones_ids)]

    for i in sin_ampliacion_ids
            TRANSMISSION_LINE = catalogo_zonas[df.busbari[i]]*"_"*catalogo_zonas[df.busbarf[i]]
            trans_lz1 = catalogo_zonas[df.busbari[i]]
            trans_lz2 = catalogo_zonas[df.busbarf[i]]
            trans_length_km = "de donde sacó la distancia?" # duda
            trans_efficiency = 0.96
            existing_trans_cap = df.max_flow[i]
            initial_bld_year = 2025
            expansion_year = df.start_time[i][1:4]
            expansion_trans_cap = 0
            push!(rows, (TRANSMISSION_LINE, trans_lz1, trans_lz2, trans_length_km, trans_efficiency, existing_trans_cap, initial_bld_year, expansion_year, expansion_trans_cap))
    end
    for i in 1:nrow(equivalente_df)
        x = equivalente_df.Index1[i]
        z = equivalente_df.Index2[i]
        TRANSMISSION_LINE = catalogo_zonas[df.busbari[x]]*"_"*catalogo_zonas[df.busbarf[x]]
        trans_lz1 = catalogo_zonas[df.busbari[x]]
        trans_lz2 = catalogo_zonas[df.busbarf[x]]
        trans_length_km = "de donde sacó la distancia?" # duda
        trans_efficiency = 0.96
        existing_trans_cap = df.max_flow[x]
        initial_bld_year = 2025
        expansion_year = df.start_time[z][1:4]
        expansion_trans_cap = df.max_flow[z]
        push!(rows, (TRANSMISSION_LINE, trans_lz1, trans_lz2, trans_length_km, trans_efficiency, existing_trans_cap, initial_bld_year, expansion_year, expansion_trans_cap))
    end
    # # Crear DataFrame y guardar como CSV
    output_df = DataFrame(rows, [:TRANSMISSION_LINE, :trans_lz1, :trans_lz2, :trans_length_km, :trans_efficiency, :existing_trans_cap, :initial_bld_year, :expansion_year, :expansion_trans_cap])
    CSV.write(output_csv_path, output_df)
    return output_df
end
Input_url = "G:/Mi unidad/Trabajo_Centra/Catedra_AlmacenamientoLD/Switch/SEN/Fuentes/BD-Pelp-2023-2027/Base de Datos PELP 2023-2027 Informe Preliminar_v2/Rumbo a la CN en 2050/Input/Rumbo  a la Carbono Neutralidad_Branch.csv"
Output_url = "C:/Users/Ignac/Trabajo_Centra/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/transmission_lines_inputs/transmisision_lines_only.csv"
y = generar_csv(Input_url, Output_url, catalogo_zonas);
println(y)

# parte 2. lineas de transmisión para los gx nodes.
function generar_csv(input_url::String, Output_url::String, catalogo_zonas::Dict)
    # leer archivo de generadores
    df = CSV.read(input_url, DataFrame)
    filter!(row -> row.connected == 1, df)
    rows = []

    for i in 1:length(df.name)
        GENERATION_PROJECT = df.name[i]
        TRANSMISSION_LINE = "Tx-"*GENERATION_PROJECT
        trans_lz1 = "Gxnode-"*GENERATION_PROJECT*"-"*catalogo_zonas[df.busbar[i]]
        trans_lz2 = catalogo_zonas[df.busbar[i]]
        trans_length_km = 0# duda
        trans_efficiency = 1
        existing_trans_cap = 9999
        initial_bld_year = 2025
        expansion_year = 1970
        expansion_trans_cap = 0
        push!(rows, (TRANSMISSION_LINE, trans_lz1, trans_lz2, trans_length_km, trans_efficiency, existing_trans_cap, initial_bld_year, expansion_year, expansion_trans_cap))
    end
    # Crear DataFrame y guardar como CSV
    output_df = DataFrame(rows, [:TRANSMISSION_LINE, :trans_lz1, :trans_lz2, :trans_length_km, :trans_efficiency, :existing_trans_cap, :initial_bld_year, :expansion_year, :expansion_trans_cap])
    CSV.write(Output_url, output_df)
end
Input_url = "G:/Mi unidad/Trabajo_Centra/Catedra_AlmacenamientoLD/Switch/SEN/Fuentes/BD-Pelp-2023-2027/Base de Datos PELP 2023-2027 Informe Preliminar_v2/Rumbo a la CN en 2050/Input/Rumbo  a la Carbono Neutralidad_ThermalGenerator.csv"
Output_url = "C:/Users/Ignac/Trabajo_Centra/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/transmission_lines_inputs/transmisision_lines_thermalgen.csv"
generar_csv(Input_url, Output_url, catalogo_zonas)

# Directorio que contiene los archivos CSV
directorio = "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/transmission_lines_inputs"

# Archivo CSV combinado
archivo_combinado = "transmission_lines2.csv"

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

