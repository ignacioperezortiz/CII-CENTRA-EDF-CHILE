using CSV
using DataFrames
using Statistics

# Leer los archivos CSV
df2040 = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Estudio_oficial/Estudio_Oficial/EEN + EEC + (Transición aceleradaprueba2)/inputs/gen_info.csv", DataFrame)
df2035 = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Estudio_oficial/Estudio_Oficial/EEN 0 EEC 0 (Rumbo CN)/inputs/gen_info.csv", DataFrame)
df2030 = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Estudio_oficial/Estudio_Oficial/EEN - EEC - (Recuperación lenta)/inputs/gen_info.csv", DataFrame)
df2 = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Estudio_oficial/Estudio_Oficial/EEN + EEC + (Transición aceleradaprueba2)/inputs/gen_build_predetermined.csv", DataFrame)

df_names = df2040[:, [:GENERATION_PROJECT, :gen_energy_source]]
names = df_names.GENERATION_PROJECT

build_years = []
capacities = []
max_ages_2040 = []

# Iterar sobre los nombres de los generadores
for name in names
    idx = findfirst(x -> x == name, df2.GENERATION_PROJECT)
    
    if !isnothing(idx)
        push!(build_years, df2[idx, :build_year])
        push!(capacities, df2[idx, :build_gen_predetermined])
    else
        push!(build_years, 0)
        push!(capacities, 0)
    end

    # Ahora buscar la vida útil de la central en cada uno de los dataframes de los escenarios
    idx2040 = findfirst(x -> x == name, df2040.GENERATION_PROJECT)
    if !isnothing(idx2040)
        push!(max_ages_2040, df2040[idx2040, :gen_max_age] - 1)
    else
        push!(max_ages_2040, 0)
    end
end

# Crear el DataFrame con las columnas build_years, max_ages_2040, y demás
df_names = hcat(df_names, DataFrame(
    buildYear = build_years, 
    capacidadInstalada = capacities, 
    maxAge2040 = max_ages_2040
))

# Crear el vector con la suma directa de buildYear y maxAge2040
retiro_years = df_names.buildYear + df_names.maxAge2040

# Agregar la nueva columna 'retiroYear' al DataFrame
df_names.retiroYear = retiro_years

# Imprimir el DataFrame final con la nueva columna 'retiroYear'
println(df_names)

df_names_f = filter(row -> row.buildYear != 0, df_names)

df_filteredd = filter(row -> row.retiroYear <= 2027, df_names_f)

println(df_filteredd)

names_carboneras = unique(df_filteredd.GENERATION_PROJECT)

using CSV
using DataFrames
using Plots
using CSV

# Leer los archivos CSV
df1 = df2
df2 = df2040

# Seleccionar las columnas relevantes de df2
df = df2[:, [:GENERATION_PROJECT, :gen_energy_source]]

# Obtener los nombres de los generadores en df2
names = df.GENERATION_PROJECT

# Inicializar las listas para las columnas build_gen_predetermined y build_year
build_gen_predetermined = []
build_year = []

# Iterar sobre cada generador en df2 (basado en los nombres en `names`)
for name in names
    # Buscar el generador en df1
    idx = findfirst(x -> x == name, df1.GENERATION_PROJECT)
    
    # Si se encuentra el generador en df1, guardar los valores de build_gen_predetermined y build_year
    if !isnothing(idx)
        push!(build_gen_predetermined, df1[idx, :build_gen_predetermined])
        push!(build_year, df1[idx, :build_year])
    else
        # Si no se encuentra el generador, agregar valores missing
        push!(build_gen_predetermined, missing)
        push!(build_year, missing)
    end
end

# Convertir los valores missing en 0 para build_gen_predetermined y build_year
build_gen_predetermined = [ismissing(value) ? 0 : value for value in build_gen_predetermined]
build_year = [ismissing(value) ? 0 : value for value in build_year]

# Agregar las columnas 'build_gen_predetermined' y 'build_year' a df2
df = hcat(df, DataFrame(build_gen_predetermined = build_gen_predetermined, build_year = build_year))
df = filter(row -> row.build_year != 0, df)
CSV.write("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Resultado_generadoress.csv",df)
# Filtrar los generadores cuya fecha de construcción sea menor o igual a 2024
df_filtered = filter(row -> row.build_year <= 2027, df)
df_filtered_final = filter(row -> !(row.GENERATION_PROJECT in names_carboneras), df_filtered)

sum(df_filtered_final.build_gen_predetermined)

# Agrupar por 'gen_energy_source' y sumar la capacidad instalada (build_gen_predetermined)
df_grouped = combine(groupby(df_filtered_final, :gen_energy_source), :build_gen_predetermined => sum)

# Definir los colores para cada tipo de tecnología
colors = Dict(
    "Biogas" => :green,
    "Biomasa" => :darkgreen,
    "Carbon" => :gray,
    "Cogeneracion" => :purple,
    "Diesel" => :orange,
    "Eolica" => :lightgreen,
    "Geotermica" => :brown,
    "GNL" => :blue,
    "Hidroelectrica" => :blue,
    "Solar_CSP" => :yellow,
    "Solar_FV" => :yellowgreen
)

# Extraer los nombres de las tecnologías y las capacidades instaladas
tech_names = df_grouped.gen_energy_source
installed_capacities = df_grouped.build_gen_predetermined_sum

# Crear un DataFrame con los datos de tecnologías y capacidades
df_excel = DataFrame(Technology=tech_names, InstalledCapacity=installed_capacities)

CSV.write("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Resultado_generadores2.csv",df_excel)