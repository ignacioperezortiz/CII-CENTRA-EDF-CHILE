using DataFrames
using CSV
using Printf

# Cargar los datos
df1 = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Estudio_oficial/Estudio_Oficial/Nuevos_GNLMarket/EEN - EEC - (Recuperación lentaprueba)/inputs/gen_build_costs.csv", DataFrame)
df2 = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Estudio_oficial/Estudio_Oficial/Nuevos_GNLMarket/EEN + EEC + (Transición aceleradaprueba)/inputs/gen_build_costs.csv", DataFrame)
df3 = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Estudio_oficial/Estudio_Oficial/Nuevos_GNLMarket/EEN 0 EEC 0 (Rumbo CNprueba)/inputs/gen_build_costs.csv", DataFrame)

df1.gen_overnight_cost .= Int64.(df1.gen_overnight_cost)
df2.gen_overnight_cost .= Int64.(df2.gen_overnight_cost)
df3.gen_overnight_cost .= Int64.(df3.gen_overnight_cost)

# Identificar los índices donde GENERATION_PROJECT contiene "Eolica_"
idx1 = findall(x -> occursin("Eolica_", x), df1.GENERATION_PROJECT)
idx2 = findall(x -> occursin("Eolica_", x), df2.GENERATION_PROJECT)
idx3 = findall(x -> occursin("Eolica_", x), df3.GENERATION_PROJECT)

# Modificar los valores de gen_overnight_cost para las filas identificadas
df1[idx1, :gen_overnight_cost] .= map(x -> round(Int64, x * 1.39), df1[idx1, :gen_overnight_cost])
df2[idx2, :gen_overnight_cost] .= map(x -> round(Int64, x * 1.23), df2[idx2, :gen_overnight_cost])
df3[idx3, :gen_overnight_cost] .= map(x -> round(Int64, x * 1.26), df3[idx3, :gen_overnight_cost])

# Si deseas guardar los archivos modificados
CSV.write("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Estudio_oficial/Estudio_Oficial/Nuevos_GNLMarket/EEN - EEC - (Recuperación lentaprueba)/inputs/gen_build_costs3.csv", df1)
CSV.write("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Estudio_oficial/Estudio_Oficial/Nuevos_GNLMarket/EEN + EEC + (Transición aceleradaprueba)/inputs/gen_build_costs3.csv", df2)
CSV.write("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Estudio_oficial/Estudio_Oficial/Nuevos_GNLMarket/EEN 0 EEC 0 (Rumbo CNprueba)/inputs/gen_build_costs3.csv", df3)