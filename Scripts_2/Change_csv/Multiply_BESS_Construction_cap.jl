using CSV
using DataFrames

# Cargar el archivo CSV
file_path = "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/Estudio_Oficial/Sensibilidades_sinLDES/Ok/Corridos/BESS_Construccion_Masiva2/TA/inputs/gen_build_predetermined.csv"
df = CSV.read(file_path, DataFrame)

# Multiplicar la columna 'build_gen_predetermined' por 0.59 desde la fila 836 hasta el final
df[836:end, :build_gen_predetermined] .= df[836:end, :build_gen_predetermined] .* 0.59

# Guardar el DataFrame modificado de nuevo en el archivo CSV
CSV.write(file_path, df)

println("La columna 'build_gen_predetermined' ha sido actualizada exitosamente.")

using CSV
using DataFrames

# Cargar el archivo CSV
file_path = "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/Estudio_Oficial/Sensibilidades_sinLDES/Ok/Corridos/BESS_Construccion_Masiva2/TA/inputs/gen_info.csv"
df = CSV.read(file_path, DataFrame)

# Multiplicar la columna 'build_gen_predetermined' por 0.59 desde la fila 836 hasta el final
df[1239:end, :gen_capacity_limit_mw] .= df[1239:end, :gen_capacity_limit_mw] .* 0.59

# Guardar el DataFrame modificado de nuevo en el archivo CSV
CSV.write(file_path, df)

println("La columna 'build_gen_predetermined' ha sido actualizada exitosamente.")