using CSV
using DataFrames

# Leer el archivo CSV
df = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/demand.csv", DataFrame)

# Multiplicar cada valor de la columna 'zone_demand_mw' por 0.930569
df[:,3:end] .*= 0.930569

# guardar archivo
CSV.write("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/demanda.csv", df)