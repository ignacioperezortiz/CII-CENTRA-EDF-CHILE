# script para crear archivo csv varaible_capacity_factors.csv en base a ??
using CSV
using DataFrames
using Dates
using Statistics
using Random
using Printf

function generar_csv(input_url::String, output_csv_path::String)
    # leer archivo de generadores
    df = CSV.read(input_url, DataFrame)
    rows = []

    # Comparar cada fila con todas las demás filas
    # Definir años y número de días representativos
    years = [2020, 2023, 2026, 2029, 2030, 2031, 2033, 2040, 2050]
    months = 1:12
    months_str = []
    for month in months
        push!(months_str, month < 10 ? "0$month" : string(month))
    end
    hours = 0:23
    hours_str = []
    for hour in hours
        push!(hours_str, hour < 10 ? "0$hour" : string(hour))
    end
    representative_day = 23
    power_representative_year = 2019
    power_representative_day = 1
    gen_csv_profile_names = names(df)
    
    day_str = representative_day < 10 ? "0$representative_day" : string(representative_day)
    power_day_str = power_representative_day < 10 ? "0$power_representative_day" : string(power_representative_day)
    # Recorrer los nombres de las columnas desde la segunda hasta el final
    for year in years
        for month_str in months_str
            for hour_str in hours_str
                timepoint = "$year$month_str$day_str$hour_str"
                power_csv_time = "$power_representative_year-$month_str-$power_day_str-$hour_str:00"
                # Buscar la demanda para el timepoint
                gens_hour_date_capacity_factors_df = df[df.time .== power_csv_time, :]
                for gen_csv_profile_name in gen_csv_profile_names[3:end]
                    gen_capacity_factor_value = gens_hour_date_capacity_factors_df[!, gen_csv_profile_name][1]
                    GENERATION_PROJECT = replace(gen_csv_profile_name, "Profile_"=>"")
                    push!(rows, (GENERATION_PROJECT, timepoint, gen_capacity_factor_value))
                end
            end
        end
    end
    output_df = DataFrame(rows, [:GENERATION_PROJECT, :timepoint, :gen_max_capacity_factor])
    CSV.write(output_csv_path, output_df)
end
input_url = "PELP_inputs/Rumbo_a_la_Carbono_Neutralidad_Covid/power.csv"
output_url = "inputs_test/variable_capacity_factors2.csv"
generar_csv(input_url, output_url);