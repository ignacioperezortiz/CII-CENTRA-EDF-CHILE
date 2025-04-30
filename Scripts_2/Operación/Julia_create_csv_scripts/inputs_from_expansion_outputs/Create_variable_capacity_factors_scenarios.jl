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
    percent = 0.1
    
    # Step 2: Modify the column values
    # Replace `column_name` with the actual name of the column you want to modify
    column_name = :gen_max_capacity_factor  # Specify the column to modify

    # Create two new DataFrames with adjusted column values
    df_90 = copy(df)
    df_90[!, column_name] .= df[!, column_name] .* (1-percent)

    df_110 = copy(df)
    df_110[!, column_name] .= min.(df[!, column_name] .* (1+percent), 1.0)

    # Step 3: Save the modified DataFrames to new CSV files
    CSV.write(input_url*"05dn.csv", df_90)
    CSV.write(input_url*"05up.csv", df_110)

    println("CSV files created: output_90.csv and output_120.csv")
end
input_path = CURRENT_STUDY_CASE*CURRENT_INPUTS_FOLDER*"variable_capacity_factors"
generar_csv(input_path);