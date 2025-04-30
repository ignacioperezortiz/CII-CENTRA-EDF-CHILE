# sript para crear el archivo gen_build_predetermines.csv en base a la Pelp
using CSV
using DataFrames

include("../global_vars.jl")

"""
La funcion realiza las siguientes acciones:
- Fija la construccion de almacenamiento y generacion en build_gen_predetermined
- Actualiza el archivo gen_build_costos para que no tenga valores de centrales que no se van a construir (esto ya que sino la validacion del set se vuelve un problema)
"""

function generar_csv(GEN_csv_relative_path::String, STOR_csv_relative_path::String, output_csv_relative_path::String, output_route_storage_build::String, gen_build_costs_csv_relative_path::String, consider_storage_expansion::Bool)
    # leer archivo de generadores y almacenamiento
    GEN_CAPACITY_PREDETERMINED_df = CSV.read(GEN_csv_relative_path, DataFrame)
    # Se filtran las fechas donde efectivamente se construyo
    filter!(row -> row.BuildGen != 0, GEN_CAPACITY_PREDETERMINED_df) 
    # se actualizan los nombres de las columnas de los dataframes
    rename!(GEN_CAPACITY_PREDETERMINED_df, [:GENERATION_PROJECT, :build_year, :build_gen_predetermined])
    if consider_storage_expansion == true
        STOR_PREDETERMINED_df = CSV.read(STOR_csv_relative_path, DataFrame)
        filter!(row -> row.BuildStorageEnergy != 0, STOR_PREDETERMINED_df) 
        rename!(STOR_PREDETERMINED_df, [:GENERATION_PROJECT, :build_year, :build_gen_energy_predetermined])
        CSV.write(output_route_storage_build, STOR_PREDETERMINED_df)
    end
    
    # se exporta el dataframe consolidado como input para el modelo operacional
    CSV.write(output_csv_relative_path, GEN_CAPACITY_PREDETERMINED_df)

    GEN_BUILD_COSTS_DF = CSV.read(gen_build_costs_csv_relative_path, DataFrame)

    GEN_BUILD_COSTS_DF = filter(row -> row.GENERATION_PROJECT in GEN_CAPACITY_PREDETERMINED_df.GENERATION_PROJECT, GEN_BUILD_COSTS_DF)

    CSV.write(gen_build_costs_csv_relative_path, GEN_BUILD_COSTS_DF)
end

input_data_file_gens = CURRENT_STUDY_CASE*CURRENT_OUTPUTS_FOLDER*"BuildGen.csv"
input_data_file_storage = CURRENT_STUDY_CASE*CURRENT_OUTPUTS_FOLDER*"BuildStorageEnergy.csv"
output_route_gen_build = CURRENT_STUDY_CASE*CURRENT_INPUTS_FOLDER*"gen_build_predetermined.csv"
output_route_storage_build = CURRENT_STUDY_CASE*CURRENT_INPUTS_FOLDER*"storage_build_energy_predetermined.csv"
route_gen_build_costs = CURRENT_STUDY_CASE*CURRENT_INPUTS_FOLDER*INPUTS_GEN_BUILD_COST_FILENAME
generar_csv(input_data_file_gens, input_data_file_storage, output_route_gen_build, output_route_storage_build, route_gen_build_costs, true)