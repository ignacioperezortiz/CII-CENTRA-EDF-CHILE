# sript para crear el archivo gen_build_predetermines.csv en base a la Pelp
using CSV
using DataFrames
using Dates
using Statistics
using Random
function generar_csv(GEN_csv_path::String, output_csv_path::String)
    # leer archivo de generadores
    GEN_df = CSV.read(GEN_csv_path, DataFrame)
    println(GEN_df.connected)
    filter!(row -> row.connected == 1, GEN_df) 
    filter!(row -> row.candidate == 0, GEN_df) 

    rows = []

    for i in 1:length(GEN_df.name)
        gen_name = GEN_df.name[i]
        gen_build_year = GEN_df.start_time[i][1:4]
        gen_power = GEN_df.pmax[i]
        push!(rows, (gen_name, gen_build_year, gen_power))
    end
    # Crear DataFrame y guardar como CSV
    output_df = DataFrame(rows, [:GENERATION_PROJECT, :build_year, :build_gen_predetermined])
    CSV.write(output_csv_path, output_df)
end

GEN_filename = "G:/Mi unidad/Trabajo_Centra/Catedra_AlmacenamientoLD/Switch/SEN/Fuentes/BD-Pelp-2023-2027/Base de Datos PELP 2023-2027 Informe Preliminar_v2/Rumbo a la CN en 2050/Input/Rumbo  a la Carbono Neutralidad_Generator.csv"
generar_csv(GEN_filename, "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/gen_build_predetermines2.csv")