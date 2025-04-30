# script para crear archivo csv varaible_capacity_factors.csv en base a ??
using CSV
using DataFrames

include("../global_vars.jl")
##TODO Agregar que el year por defecto si no se construyo sea un valor que venga de un archivo global vars
##TODO Agregar que el year por defecto de no construccion para la recuperacion del year, revise si es menor al year de inicio del estudio, en vez de 1970 en especifico
function generar_csv_load_zones_local_TD(input_data_route::String, input_load_zone_data_file::String, output_data_route::String)

    df_output_local_td_build = CSV.read(input_data_route, DataFrame)
    df_input_load_zones = CSV.read(input_load_zone_data_file, DataFrame)

    consolidated_data_build_local_TD = combine(groupby(df_output_local_td_build, :BuildLocalTD_index_1), 
    :BuildLocalTD => sum => :total_capacity_added
    )

    # println(filter(row -> row.total_capacity_added > 0, consolidated_data_build_local_TD))

    output_df = leftjoin(df_input_load_zones, consolidated_data_build_local_TD, on=:LOAD_ZONE => :BuildLocalTD_index_1, renamecols = "" => "_right")

    # Se reemplazan los datos del dataframe input de lineas de transmision con la expansion detectada
    output_df.existing_local_td = output_df.existing_local_td + output_df.total_capacity_added_right

    # Se botan las columnas adicionales generadas que no son de uso
    select!(output_df, Not([:total_capacity_added_right]))

    CSV.write(output_data_route, output_df)

end
input_Tx_data = CURRENT_STUDY_CASE*"outputs/BuildLocalTD.csv"
input_Tx_lines = CURRENT_STUDY_CASE*"inputs/load_zones.csv"
output_route_TX = CURRENT_STUDY_CASE*"inputs/load_zones_2.csv"
generar_csv_load_zones_local_TD(input_Tx_data, input_Tx_lines, output_route_TX);