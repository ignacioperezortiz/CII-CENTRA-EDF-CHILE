# script para crear archivo csv varaible_capacity_factors.csv en base a ??
using CSV
using DataFrames
using Printf

include("../global_vars.jl")

function generar_csv_tx(input_data_route::String, input_tx_data_file::String, output_data_route_tx_lines::String, output_data_route_tx_predetermined::String)

    df_output_tx_build = CSV.read(input_data_route, DataFrame)
    df_input_tx_lines = CSV.read(input_tx_data_file, DataFrame)

    # consolidated_data_build_tx = combine(groupby(df_output_tx_build, :TRANS_BLD_YRS_1), 
    # [:TRANS_BLD_YRS_2, :BuildTx] => ((year, cap_added) -> isempty(year[cap_added .> 0]) ? DEFAULT_YEAR_NOT_BUILD_TX : minimum(year[cap_added .> 0])) => :first_expansion_year,
    # :BuildTx => sum => :total_capacity_added
    # )

    # output_df = leftjoin(df_input_tx_lines, consolidated_data_build_tx, on=:TRANSMISSION_LINE => :TRANS_BLD_YRS_1, renamecols = "" => "_right")

    rename!(df_output_tx_build, [:TRANSMISSION_LINE, :build_year, :tx_predetermined_cap])

    # Se reemplazan los datos del dataframe input de lineas de transmision con la expansion detectada
    # output_df.expansion_year = [y1 >= STARTING_YEAR && y2 >= STARTING_YEAR ? minimum([y1, y2]) : maximum([y1,y2]) for (y1, y2) in zip(output_df.expansion_year, output_df.first_expansion_year_right)]
    # output_df.expansion_year = coalesce.(output_df.first_expansion_year_right, output_df.expansion_year)
    # output_df.expansion_trans_cap = coalesce.(output_df.total_capacity_added_right, output_df.expansion_trans_cap)
    # output_df.expansion_trans_cap = output_df.expansion_trans_cap + output_df.total_capacity_added_right

    # Se botan las columnas adicionales generadas que no son de uso
    # select!(output_df, Not([:first_expansion_year_right, :total_capacity_added_right]))

    # Se fuerza que no se pueda generar expansion de la transmision en el modelo
    df_input_tx_lines.trans_new_build_allowed = fill(0, nrow(df_input_tx_lines))

    CSV.write(output_data_route_tx_lines, df_input_tx_lines)
    CSV.write(output_data_route_tx_predetermined, df_output_tx_build)

end
input_Tx_data = CURRENT_STUDY_CASE*CURRENT_OUTPUTS_FOLDER*"BuildTx.csv"
input_Tx_lines = CURRENT_STUDY_CASE*CURRENT_INPUTS_FOLDER*"transmission_lines.csv"
output_route_TX_lines = CURRENT_STUDY_CASE*CURRENT_INPUTS_FOLDER*"transmission_lines.csv"
output_route_TX_predetermined = CURRENT_STUDY_CASE*CURRENT_INPUTS_FOLDER*"tx_build_predetermined.csv"
generar_csv_tx(input_Tx_data, input_Tx_lines, output_route_TX_lines, output_route_TX_predetermined);