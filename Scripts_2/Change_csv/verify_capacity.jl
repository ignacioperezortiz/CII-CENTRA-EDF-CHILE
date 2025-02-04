using CSV
using DataFrames
using Statistics

# Leer los archivos CSV
df1 = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Estudio_oficial/Estudio_Oficial/EEN + EEC + (Transición aceleradaprueba2)/inputs/gen_build_predetermined.csv", DataFrame)
df2 = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Estudio_oficial/Estudio_Oficial/EEN + EEC + (Transición aceleradaprueba2)/inputs/gen_info.csv", DataFrame)

names = unique(df1.GENERATION_PROJECT)
rows = []
for i in 1:length(names)
    name = names[i]
    capacity = df1.build_gen_predetermined[i]
    df3 = filter(row->row.GENERATION_PROJECT == name,df2)
    capacity2 = df3.gen_capacity_limit_mw[1]
    diference = capacity - capacity2
    push!(rows, (name, capacity, capacity2, diference))
end
df = DataFrame(rows, [:GENERATION_PROJECT, :capacity, :capacity2, :diff])
filtred_df = filter(row->row.diff != 0, df)