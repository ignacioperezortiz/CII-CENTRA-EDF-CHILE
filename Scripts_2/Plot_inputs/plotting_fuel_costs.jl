using CSV
using DataFrames
using Plots
using Statistics

df_Alto = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Fuel costs/fuel_cost_Alto.csv", DataFrame)
df_Medio = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Fuel costs/fuel_cost_Medio.csv", DataFrame)
df_Bajo = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Fuel costs/fuel_cost_Bajo.csv", DataFrame)

df_Alto.fuel = string.(df_Alto.fuel)
df_Medio.fuel = string.(df_Medio.fuel)
df_Bajo.fuel = string.(df_Bajo.fuel)

# Función para filtrar por combustible y calcular el promedio por año
function get_avg_cost_by_fuel(df::DataFrame, fuel_type::String15)
    # Filtramos las filas que coinciden con el tipo de combustible
    filtered_df = filter(row -> strip(row.fuel) == fuel_type, df)  # Filtramos por combustible
    avg_cost_by_year = groupby(filtered_df, :period)  # Agrupar por año
    return combine(avg_cost_by_year, :fuel_cost => mean)  # Calcular el promedio de los costos
end

fuel_types = unique(vcat(df_Alto.fuel, df_Medio.fuel, df_Bajo.fuel))

results = Dict()

# Obtener el promedio para cada combustible y escenario
for fuel_type in fuel_types
    println("Procesando combustible: $fuel_type")  
    results[fuel_type] = Dict(
        "Alto" => get_avg_cost_by_fuel(df_Alto, fuel_type),
        "Medio" => get_avg_cost_by_fuel(df_Medio, fuel_type),
        "Bajo" => get_avg_cost_by_fuel(df_Bajo, fuel_type)
    )
end

# Función para graficar los resultados
function plot_fuel_costs(fuel_type::String15, data::Dict)
    years = unique(vcat(data["Alto"].period, data["Medio"].period, data["Bajo"].period))
    
    alto_cost = data["Alto"].fuel_cost_mean
    medio_cost = data["Medio"].fuel_cost_mean
    bajo_cost = data["Bajo"].fuel_cost_mean
    
    # Crear el gráfico para cada tipo de combustible
    plot(years, alto_cost, label="Alto", xlabel="Año", ylabel="Costo Promedio USD/Ton",  title="Costo de Combustible: $fuel_type", linestyle=:solid, linewidth=3, color=:red)
    plot!(years, medio_cost, label="Medio", linestyle=:solid, linewidth=3, color=:blue)
    plot!(years, bajo_cost, label="Bajo", linestyle=:solid, linewidth=3, color=:green)
    return plot!()
end

for (fuel_type, data) in results
    display(plot_fuel_costs(fuel_type, data))
end