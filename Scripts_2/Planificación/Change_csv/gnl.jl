using DataFrames
using CSV
using Statistics

df = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Estudio_oficial/Estudio_Oficial/Nuevos/EEN 0 EEC 0 (Rumbo CNprueba)/inputs/fuel_cost.csv", DataFrame)

# Filtrar los datos para obtener solo los registros donde fuel es 'GNL'
df_filtered = filter(row -> row.fuel == "GNL", df)

# Calcular el promedio de fuel_cost para cada periodo
df_avg_cost = combine(groupby(df_filtered, :period), :fuel_cost => mean)

# Renombrar las columnas para claridad
rename!(df_avg_cost, :fuel_cost_mean => :avg_fuel_cost)

# Mostrar el DataFrame resultante
println(df_avg_cost)


df2 = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Estudio_oficial/Estudio_Oficial/Nuevos_GNLMarket/EEN 0 EEC 0 (Rumbo CNprueba)/inputs/fuel_cost.csv", DataFrame)
# Eliminar filas donde la columna 'fuel' tenga el valor 'GNL'
df2 = filter(row -> row.fuel != "GNL", df2)

# Mostrar el DataFrame resultante
CSV.write("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Estudio_oficial/Estudio_Oficial/Nuevos_GNLMarket/EEN 0 EEC 0 (Rumbo CNprueba)/inputs/fuel_cost2.csv", df2)