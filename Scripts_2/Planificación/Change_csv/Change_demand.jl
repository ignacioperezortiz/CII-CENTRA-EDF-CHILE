using CSV
using DataFrames

# Leer el archivo CSV
df = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/inputs/variable_capacity_factors.csv", DataFrame)

# Filtrar filas donde la columna 'TIMEPOINT' comience con '2023'
df = filter(row -> occursin("2023", string(row.timepoint)), df)

# Guardar el archivo
CSV.write("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/inputs/variable_capacity_factors2.csv", df)