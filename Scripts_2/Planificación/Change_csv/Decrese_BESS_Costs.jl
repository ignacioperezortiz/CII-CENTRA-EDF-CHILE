using CSV
using DataFrames
using Statistics

# Función para procesar cada DataFrame y calcular las proyecciones
function process_df(df)
    ess_df = filter(row -> occursin("ESS_", row.GENERATION_PROJECT), df)
    ess_df1 = filter(row -> !occursin("H2", row.GENERATION_PROJECT), ess_df)
    unique_years = unique(ess_df.build_year)
    result_df = DataFrame(period = Int[], avg_cost = Float64[])
    for year in unique_years
        year_df = filter(row -> row.build_year == year, ess_df1)
        avg_cost = mean(year_df.gen_overnight_cost)
        push!(result_df, (period = year, avg_cost = avg_cost))
    end
    first_avg_cost = result_df.avg_cost[1]
    result_df.multiplier = result_df.avg_cost ./ first_avg_cost
    n_periods = nrow(result_df)
    decrement_5 = 1.0 .+ (0:n_periods-1) .* (0.05 / (n_periods-1))
    result_df.avg_cost_decrease = result_df.avg_cost .* decrement_5
    return result_df
end

# Función para actualizar los costos en un DataFrame
function update_costs(df, result_df)
    for row in eachrow(df)
        if occursin("ESS_", row.GENERATION_PROJECT)
            period = row.build_year
            decrement_5 = result_df.avg_cost_decrease[result_df.period .== period][1]
            row.gen_overnight_cost = round(decrement_5)
        end
    end
    return df
end

# Leer y actualizar los archivos CSV
function update_csv(file_path, result_df)
    df = CSV.read(file_path, DataFrame)
    updated_df = update_costs(df, result_df)
    CSV.write(file_path, updated_df)
end

# Leer los archivos CSV
df_RL = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/Estudio_Oficial/Sensibilidades/OK/Corridos/Costos_BESS_A5/RL/inputs/gen_build_costs.csv", DataFrame)
df_CN = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/Estudio_Oficial/Sensibilidades/OK/Corridos/Costos_BESS_A5/CN/inputs/gen_build_costs.csv", DataFrame)
df_TA = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/Estudio_Oficial/Sensibilidades/OK/Corridos/Costos_BESS_A5/TA/inputs/gen_build_costs.csv", DataFrame)

# Procesar cada DataFrame
result_df_RL = process_df(df_RL)
result_df_CN = process_df(df_CN)
result_df_TA = process_df(df_TA)

# Actualizar cada archivo CSV
update_csv("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/Estudio_Oficial/Sensibilidades/OK/Corridos/Costos_BESS_A5/RL/inputs/gen_build_costs.csv", result_df_RL)
update_csv("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/Estudio_Oficial/Sensibilidades/OK/Corridos/Costos_BESS_A5/CN/inputs/gen_build_costs.csv", result_df_CN)
update_csv("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/Estudio_Oficial/Sensibilidades/OK/Corridos/Costos_BESS_A5/TA/inputs/gen_build_costs.csv", result_df_TA)

println("Los archivos CSV han sido actualizados con las proyecciones de disminución de costos en un 5% para proyectos de tecnología 'ESS'.")