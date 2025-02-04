using CSV
using DataFrames
using Printf

# Leer el archivo CSV y crear un DataFrame
df = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Inputs_CSP-TES/inputs/gen_build_costs.csv", DataFrame)

# Filtrar las filas donde el índice es mayor a 700 y "build_year" no sea igual a 2018
df_filtrado = DataFrame()
for i in 1:size(df, 1)
    if !(i > 1000 && df.build_year[i] == 2018)
        push!(df_filtrado, df[i, :])
    end
end
# Convertir las columnas numéricas a tipo String para evitar notación científica
# Convertir columnas numéricas a un formato de número completo
# Convertir columnas numéricas a formato de texto sin notación científica
for col in names(df_filtrado)
    if eltype(df_filtrado[!, col]) <: Number
        df_filtrado[!, col] .= map(x -> @sprintf("%.0f", x), df_filtrado[!, col])
    end
end
# Escribir el DataFrame filtrado de nuevo en un archivo CSV
CSV.write("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Inputs_CSP-TES/inputs/gen_build_costs2.csv", df_filtrado)

println("Archivo filtrado creado: tu_archivo_filtrado.csv")







df = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Inputs_LDES_Preliminar4/inputs/variable_capacity_factors.csv", DataFrame)
# Supongamos que ya tienes el dataframe df sin las filas 700 a 1200
df1 = df[1:1741824, :]
df2 = vcat(df1, df[2200609:end, :])

# Especifica la ruta de la carpeta y el nombre del archivo CSV
ruta_carpeta = "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/"  # Cambia esto a tu ruta deseada
nombre_archivo = "variable_capacity_factors.csv"

# Guardar el dataframe como CSV
CSV.write(joinpath(ruta_carpeta, nombre_archivo), df2)

println("El archivo CSV se ha guardado en: ", joinpath(ruta_carpeta, nombre_archivo))





df = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Inputs_LDES_Preliminar4/inputs/variable_capacity_factors.csv", DataFrame)
subset_df = filter(row -> !occursin("2020", string(row.timepoint)), df)


# Si deseas guardar el subconjunto en un nuevo archivo CSV
CSV.write("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/variable_capacity_factors.csv", subset_df)







# script para generar inputs caso tipo, dias tipicos variabilidad.
using CSV
using DataFrames
using Printf

# variable_capacity_factors
df1 = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Inputs_LDES_Preliminar5/inputs/gen_info.csv", DataFrame)
df = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Inputs_LDES_Preliminar5/inputs/variable_capacity_factors.csv", DataFrame)

df1_filtrado_Eolicas = filter(row -> occursin("WIND", string(row.gen_tech)), df1)
Nombres_Eolicas = df1_filtrado_Eolicas.GENERATION_PROJECT
# Eolica
for i in 1:length(df.GENERATION_PROJECT)
    if df.GENERATION_PROJECT[i] in Nombres_Eolicas
        if occursin("042300", string(df.timepoint[i])) || occursin("082300", string(df.timepoint[i])) || occursin("122300", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 1
            println("true")
        elseif occursin("042301", string(df.timepoint[i])) || occursin("082301", string(df.timepoint[i])) || occursin("122301", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 1
            println("true")
        elseif occursin("042302", string(df.timepoint[i])) || occursin("082302", string(df.timepoint[i])) || occursin("122302", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 1
            println("true")
        elseif occursin("042303", string(df.timepoint[i])) || occursin("082303", string(df.timepoint[i])) || occursin("122303", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 1
            println("true")
        elseif occursin("042304", string(df.timepoint[i])) || occursin("082304", string(df.timepoint[i])) || occursin("122304", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 1
            println("true")
        elseif occursin("042305", string(df.timepoint[i])) || occursin("082305", string(df.timepoint[i])) || occursin("122305", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 1
            println("true")
        elseif occursin("042318", string(df.timepoint[i])) || occursin("082318", string(df.timepoint[i])) || occursin("122318", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 1
            println("true")
        elseif occursin("042319", string(df.timepoint[i])) || occursin("082319", string(df.timepoint[i])) || occursin("122319", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 1
            println("true")
        elseif occursin("042320", string(df.timepoint[i])) || occursin("082320", string(df.timepoint[i])) || occursin("122320", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 1
            println("true")
        elseif occursin("042321", string(df.timepoint[i])) || occursin("082321", string(df.timepoint[i])) || occursin("122321", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 1
            println("true")
        elseif occursin("042322", string(df.timepoint[i])) || occursin("082322", string(df.timepoint[i])) || occursin("122322", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 1
            println("true")
        elseif occursin("042323", string(df.timepoint[i])) || occursin("082323", string(df.timepoint[i])) || occursin("122323", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 1
            println("true")
        elseif occursin("042306", string(df.timepoint[i])) || occursin("082306", string(df.timepoint[i])) || occursin("122306", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 0
            println("true")
        elseif occursin("042307", string(df.timepoint[i])) || occursin("082307", string(df.timepoint[i])) || occursin("122307", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 0
            println("true")
        elseif occursin("042308", string(df.timepoint[i])) || occursin("082308", string(df.timepoint[i])) || occursin("122308", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 0
            println("true")
        elseif occursin("042309", string(df.timepoint[i])) || occursin("082309", string(df.timepoint[i])) || occursin("122309", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 0
            println("true")
        elseif occursin("042310", string(df.timepoint[i])) || occursin("082310", string(df.timepoint[i])) || occursin("122310", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 0
            println("true")
        elseif occursin("042311", string(df.timepoint[i])) || occursin("082311", string(df.timepoint[i])) || occursin("122311", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 0
            println("true")
        elseif occursin("042312", string(df.timepoint[i])) || occursin("082312", string(df.timepoint[i])) || occursin("122312", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 0
            println("true")
        elseif occursin("042313", string(df.timepoint[i])) || occursin("082313", string(df.timepoint[i])) || occursin("122313", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 0
            println("true")
        elseif occursin("042314", string(df.timepoint[i])) || occursin("082314", string(df.timepoint[i])) || occursin("122314", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 0
            println("true")
        elseif occursin("042315", string(df.timepoint[i])) || occursin("082315", string(df.timepoint[i])) || occursin("122315", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 0
            println("true")
        elseif occursin("042316", string(df.timepoint[i])) || occursin("082316", string(df.timepoint[i])) || occursin("122316", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 0
            println("true")
        elseif occursin("042317", string(df.timepoint[i])) || occursin("082317", string(df.timepoint[i])) || occursin("122317", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 0
            println("true")
        end
    end
end

df1 = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Inputs_LDES_Preliminar5/inputs/gen_info.csv", DataFrame)
df1_filtrado_Solar = filter(row -> occursin("PV", string(row.gen_tech)), df1)
Nombres_Solar = df1_filtrado_Solar.GENERATION_PROJECT
# solar
for i in 1:length(df.GENERATION_PROJECT)
    if df.GENERATION_PROJECT[i] in Nombres_Solar
        if occursin("042300", string(df.timepoint[i])) || occursin("082300", string(df.timepoint[i])) || occursin("122300", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 0
            println("true")
        elseif occursin("042301", string(df.timepoint[i])) || occursin("082301", string(df.timepoint[i])) || occursin("122301", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 0
            println("true")
        elseif occursin("042302", string(df.timepoint[i])) || occursin("082302", string(df.timepoint[i])) || occursin("122302", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 1
            println("true")
        elseif occursin("042303", string(df.timepoint[i])) || occursin("082303", string(df.timepoint[i])) || occursin("122303", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 1
            println("true")
        elseif occursin("042304", string(df.timepoint[i])) || occursin("082304", string(df.timepoint[i])) || occursin("122304", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 1
            println("true")
        elseif occursin("042305", string(df.timepoint[i])) || occursin("082305", string(df.timepoint[i])) || occursin("122305", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 0
            println("true")
        elseif occursin("042318", string(df.timepoint[i])) || occursin("082318", string(df.timepoint[i])) || occursin("122318", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 0
            println("true")
        elseif occursin("042319", string(df.timepoint[i])) || occursin("082319", string(df.timepoint[i])) || occursin("122319", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 0
            println("true")
        elseif occursin("042320", string(df.timepoint[i])) || occursin("082320", string(df.timepoint[i])) || occursin("122320", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 1
            println("true")
        elseif occursin("042321", string(df.timepoint[i])) || occursin("082321", string(df.timepoint[i])) || occursin("122321", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 1
            println("true")
        elseif occursin("042322", string(df.timepoint[i])) || occursin("082322", string(df.timepoint[i])) || occursin("122322", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 1
            println("true")
        elseif occursin("042323", string(df.timepoint[i])) || occursin("082323", string(df.timepoint[i])) || occursin("122323", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 0
            println("true")
        elseif occursin("042306", string(df.timepoint[i])) || occursin("082306", string(df.timepoint[i])) || occursin("122306", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 0
            println("true")
        elseif occursin("042307", string(df.timepoint[i])) || occursin("082307", string(df.timepoint[i])) || occursin("122307", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 0
            println("true")
        elseif occursin("042308", string(df.timepoint[i])) || occursin("082308", string(df.timepoint[i])) || occursin("122308", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 0
            println("true")
        elseif occursin("042309", string(df.timepoint[i])) || occursin("082309", string(df.timepoint[i])) || occursin("122309", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 0
            println("true")
        elseif occursin("042310", string(df.timepoint[i])) || occursin("082310", string(df.timepoint[i])) || occursin("122310", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 0
            println("true")
        elseif occursin("042311", string(df.timepoint[i])) || occursin("082311", string(df.timepoint[i])) || occursin("122311", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 0
            println("true")
        elseif occursin("042312", string(df.timepoint[i])) || occursin("082312", string(df.timepoint[i])) || occursin("122312", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 0
            println("true")
        elseif occursin("042313", string(df.timepoint[i])) || occursin("082313", string(df.timepoint[i])) || occursin("122313", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 0
            println("true")
        elseif occursin("042314", string(df.timepoint[i])) || occursin("082314", string(df.timepoint[i])) || occursin("122314", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 0
            println("true")
        elseif occursin("042315", string(df.timepoint[i])) || occursin("082315", string(df.timepoint[i])) || occursin("122315", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 0
            println("true")
        elseif occursin("042316", string(df.timepoint[i])) || occursin("082316", string(df.timepoint[i])) || occursin("122316", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 0
            println("true")
        elseif occursin("042317", string(df.timepoint[i])) || occursin("082317", string(df.timepoint[i])) || occursin("122317", string(df.timepoint[i]))
            df.gen_max_capacity_factor[i] = 0
            println("true")
        end
    end
end

CSV.write("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/variable_capacity_factors10.csv", df)




df = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Inputs_LDES_Preliminar5/inputs/gen_build_costs.csv",DataFrame)
df2 = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Inputs_LDES_Preliminar5/inputs/gen_build_costs2.csv", DataFrame)
df3 = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Inputs_LDES_Preliminar5/inputs/gen_build_predetermined.csv", DataFrame)

for i in 1:length(df.GENERATION_PROJECT)
    GENERATION_PROJECT = df.GENERATION_PROJECT[i]
    if GENERATION_PROJECT in df3.GENERATION_PROJECT
        idx = findfirst(x -> x==string(GENERATION_PROJECT), df2.GENERATION_PROJECT)
        println(idx)
        df.build_year[i] = df2.build_year[idx]
    end
end

CSV.write("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/gen_build_costs.csv",df)

# Preparación de perfiles de demanda