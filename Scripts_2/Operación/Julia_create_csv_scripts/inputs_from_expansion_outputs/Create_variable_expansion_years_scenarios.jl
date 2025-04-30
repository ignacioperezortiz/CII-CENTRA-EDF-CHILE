# script para crear archivo csv varaible_capacity_factors.csv en base a ??
using CSV
using DataFrames
using Dates
using Statistics
using Random
using Printf

function generar_csv(input_url::String)
    # leer archivo de generadores
    df = CSV.read(input_url*".csv", DataFrame)
    percent = 0.05
    
    # Step 2: Modify the column values
    # Replace `column_name` with the actual name of the column you want to modify
    column_name = :tx_predetermined_cap  # Specify the column to modify

    # Create two new DataFrames with adjusted column values
    df_percent_down = copy(df)
    df_percent_down[!, column_name] .= df[!, column_name] .* (1-percent)

    df_percent_up = copy(df)
    df_percent_up[!, column_name] .= df[!, column_name] .* (1+percent)

    # Step 3: Save the modified DataFrames to new CSV files
    CSV.write(input_url*"05dn.csv", df_percent_down)
    CSV.write(input_url*"05up.csv", df_percent_up)

    println("CSV files created")
end
input_path = CURRENT_STUDY_CASE*CURRENT_INPUTS_FOLDER*"tx_build_predetermined"
generar_csv(input_path);