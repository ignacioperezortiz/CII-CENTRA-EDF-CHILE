# script para crear load_zones.csv en base a la pelp
# script para crear el archivo fuel_cost.csv en base a la pelp
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
    df = CSV.read(input_url, DataFrame)
    rows = []

    for i in 1:length(df.name)
        LOAD_ZONE = catalogo_zonas[df.name[i]]
        dbid = df.id[i]
        existing_local_td = 0
        local_td_annual_cost_per_mw = 0
        push!(rows, (LOAD_ZONE, dbid, existing_local_td, local_td_annual_cost_per_mw))
    end
    # Crear DataFrame y guardar como CSV
    output_df = DataFrame(rows, [:LOAD_ZONE, :dbid, :existing_local_td, :local_td_annual_cost_per_mw])
    CSV.write(output_csv_path, output_df)
end
Input_url = "G:/Mi unidad/Trabajo_Centra/Catedra_AlmacenamientoLD/Switch/SEN/Fuentes/BD-Pelp-2023-2027/Base de Datos PELP 2023-2027 Informe Preliminar_v2/Rumbo a la CN en 2050/Input/ele-busbar.csv"
Output_url = "C:/Users/Ignac/Trabajo_Centra/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Load_zones/load_zones_pred.csv"
generar_csv(Input_url, Output_url, catalogo_zonas)

function generar_csv(input_url::String, Output_url::String, catalogo_zonas::Dict)
    # leer archivo de generadores
    df = CSV.read(input_url, DataFrame)
    filter!(row -> row.connected == 1, df)
    rows = []

    for i in 1:length(df.name)
        GENERATION_PROJECT = df.name[i]
        LOAD_ZONE = "Gxnode-"*GENERATION_PROJECT*"-"*catalogo_zonas[df.busbar[i]]
        dbid = @sprintf("t%04d", i)
        existing_local_td = 0
        local_td_annual_cost_per_mw = 0
        push!(rows, (LOAD_ZONE, dbid, existing_local_td,local_td_annual_cost_per_mw))
    end
    # Crear DataFrame y guardar como CSV
    output_df = DataFrame(rows, [:LOAD_ZONE, :dbid, :existing_local_td, :local_td_annual_cost_per_mw])
    CSV.write(Output_url, output_df)
end
Input_url = "G:/Mi unidad/Trabajo_Centra/Catedra_AlmacenamientoLD/Switch/SEN/Fuentes/BD-Pelp-2023-2027/Base de Datos PELP 2023-2027 Informe Preliminar_v2/Rumbo a la CN en 2050/Input/Rumbo  a la Carbono Neutralidad_ThermalGenerator.csv"
Output_url = "C:/Users/Ignac/Trabajo_Centra/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Load_zones/load_zones_termo.csv"
generar_csv(Input_url, Output_url, catalogo_zonas)


# Directorio que contiene los archivos CSV
directorio = "C:/Users/Ignac/Trabajo_Centra/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Load_zones"

# Archivo CSV combinado
archivo_combinado = "load_zones2.csv"

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