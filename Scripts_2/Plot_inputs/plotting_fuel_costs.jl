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
    filtered_df = filter(row -> strip(row.fuel) == fuel_type, df)
    avg_cost_by_year = groupby(filtered_df, :period)
    return combine(avg_cost_by_year, :fuel_cost => mean)
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
function plot_fuel_costs(fuel_type::String15, data::Dict, ruta_guardado::String)
    years = unique(vcat(data["Alto"].period, data["Medio"].period, data["Bajo"].period))
    
    alto_cost = data["Alto"].fuel_cost_mean
    medio_cost = data["Medio"].fuel_cost_mean
    bajo_cost = data["Bajo"].fuel_cost_mean
    
    # Determinar la etiqueta del eje y según el tipo de combustible
    ylabel_text = ""
    if fuel_type in ["Biomasa", "Carbon"]
        ylabel_text = "Costo Promedio USD/Ton"
    elseif fuel_type in ["Cogeneracion", "GNL", "Biogas"]
        ylabel_text = "Costo Promedio USD/MMBtu"
    elseif fuel_type == "Diesel"
        ylabel_text = "Costo Promedio USD/m3"
    else
        ylabel_text = "Costo Promedio" # Etiqueta por defecto si no coincide
    end
    
    # Crear el gráfico para cada tipo de combustible
    p = plot(years, alto_cost, label="Alto", xlabel="Año", ylabel=ylabel_text, title="Costo de Combustible: $fuel_type", linestyle=:solid, linewidth=3, color=:red)
    plot!(p, years, medio_cost, label="Medio", linestyle=:solid, linewidth=3, color=:blue)
    plot!(p, years, bajo_cost, label="Bajo", linestyle=:solid, linewidth=3, color=:green)
    
    # Guardar el gráfico como PNG
    savefig(p, joinpath(ruta_guardado, "costo_combustible_$fuel_type.png"))
    
    return p
end

# Mostrar los gráficos y guardar los archivos CSV
ruta_guardado = "C:\\Users\\Ignac\\Trabajo_Centra\\Catedra-LDES\\CII-Centra-EDF\\SEN\\SEN-Files\\Electricity Generation\\CII-CENTRA-EDF-CHILE\\Estudio_Sensibilidades" # Especifica la ruta de guardado
for (fuel_type, data) in results
    # Guardar los gráficos en la misma ruta
    plot_fuel_costs(fuel_type, data, ruta_guardado)
    
    # Crear un DataFrame para los datos del combustible
    df_combustible = DataFrame(
        Año = data["Alto"].period,
        Alto = data["Alto"].fuel_cost_mean,
        Medio = data["Medio"].fuel_cost_mean,
        Bajo = data["Bajo"].fuel_cost_mean
    )
    # Guardar el DataFrame como archivo CSV
    CSV.write(joinpath(ruta_guardado, "costos_combustible_$fuel_type.csv"), df_combustible)
end
