using CSV
using DataFrames
using CairoMakie
using Statistics

# Leer los archivos CSV
df_RL = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/Estudio_Oficial/Sensibilidades/Costos_BESS_A5/RL/inputs/gen_build_costs.csv", DataFrame)
df_CN = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/Estudio_Oficial/Sensibilidades/Costos_BESS_A5/CN/inputs/gen_build_costs.csv", DataFrame)
df_TA = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/Estudio_Oficial/Sensibilidades/Costos_BESS_A5/TA/inputs/gen_build_costs.csv", DataFrame)

# Función para procesar cada DataFrame
function process_df(df)
    ess_df = filter(row -> occursin("ESS_", row.GENERATION_PROJECT), df)
    unique_years = unique(ess_df.build_year)
    result_df = DataFrame(period = Int[], avg_cost = Float64[])
    for year in unique_years
        year_df = filter(row -> row.build_year == year, ess_df)
        avg_cost = mean(year_df.gen_overnight_cost) / 1000
        push!(result_df, (period = year, avg_cost = avg_cost))
    end
    first_avg_cost = result_df.avg_cost[1]
    result_df.multiplier = result_df.avg_cost ./ first_avg_cost
    result_df.percentage = vcat([0], fill(5, nrow(result_df) - 1))
    n_periods = nrow(result_df)
    # println(n_periods)
    increment_5 = 1.0 .+ (0:n_periods-1) .* (0.05 / (n_periods-1))
    decrement_5 = 1.0 .- (0:n_periods-1) .* (0.05 / (n_periods-1))
    increment_8 = 1.0 .+ (0:n_periods-1) .* (0.08 / (n_periods-1))
    decrement_8 = 1.0 .- (0:n_periods-1) .* (0.08 / (n_periods-1))
    result_df.avg_cost_increase = result_df.avg_cost .* increment_5
    result_df.avg_cost_decrease = result_df.avg_cost .* decrement_5
    result_df.avg_cost_increase_8 = result_df.avg_cost .* increment_8
    result_df.avg_cost_decrease_8 = result_df.avg_cost .* decrement_8
    println(result_df.avg_cost_increase[7])
    println(result_df.avg_cost[7])
    return result_df
end

# Procesar cada DataFrame
result_df_RL = process_df(df_RL)
result_df_CN = process_df(df_CN)
result_df_TA = process_df(df_TA)

# Generar el gráfico
fig = Figure(resolution = (1000, 600))

ax = Axis(fig[1, 1], 
    title = " ", 
    xlabel = "Años en que ocurren las inversiones", 
    ylabel = "Costos de BESS en USD/KWh",
    xticks = (result_df_RL.period.-2000, string.(result_df_RL.period.-2000))
)

# Ajustar los límites del eje x para que comiencen y terminen en los periodos inicial y final
xlims!(ax, minimum(result_df_RL.period.-2000), maximum(result_df_RL.period.-2000))

# Plotear las líneas para RL
lines!(ax, result_df_RL.period.-2000, result_df_RL.avg_cost, label = "Costos Base RL", color = :red, linestyle = :solid, linewidth = 2)
lines!(ax, result_df_RL.period.-2000, result_df_RL.avg_cost_increase, label = "Aumento Costos 5% RL", color = :red, linestyle = :dash, linewidth = 2)
lines!(ax, result_df_RL.period.-2000, result_df_RL.avg_cost_decrease, label = "Disminución Costos 5% RL", color = :red, linestyle = :dash, linewidth = 2)

# Plotear las líneas para CN
lines!(ax, result_df_CN.period.-2000, result_df_CN.avg_cost, label = "Costos Base CN", color = :blue, linestyle = :solid, linewidth = 2)
lines!(ax, result_df_CN.period.-2000, result_df_CN.avg_cost_increase, label = "Aumento Costos 5% CN", color = :blue, linestyle = :dash, linewidth = 2)
lines!(ax, result_df_CN.period.-2000, result_df_CN.avg_cost_decrease, label = "Disminución Costos 5% CN", color = :blue, linestyle = :dash, linewidth = 2)

# Plotear las líneas para TA
lines!(ax, result_df_TA.period.-2000, result_df_TA.avg_cost, label = "Costos Base TA", color = :green, linestyle = :solid, linewidth = 2)
lines!(ax, result_df_TA.period.-2000, result_df_TA.avg_cost_increase, label = "Aumento Costos 5% TA", color = :green, linestyle = :dash, linewidth = 2)
lines!(ax, result_df_TA.period.-2000, result_df_TA.avg_cost_decrease, label = "Disminución Costos 5% TA", color = :green, linestyle = :dash, linewidth = 2)

# Añadir leyenda fuera del gráfico, a la derecha y reducir el tamaño de la simbología
legend = Legend(fig, ax, "Simbología", title = "Proyecciones", fontsize = 8)
fig[1, 2] = legend

# Mostrar el gráfico
display(fig)
# save("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/CII-CENTRA-EDF-CHILE/Scripts_2/Plot_inputs/BESS_Costs_Sensibility.png", fig)