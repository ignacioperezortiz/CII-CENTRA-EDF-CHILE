using CSV
using DataFrames
using Statistics

# Leer los archivos CSV
df2040 = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/gen_infos/gen_info2030.csv", DataFrame)
df2035 = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/gen_infos/gen_info2035.csv", DataFrame)
df2030 = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/gen_infos/gen_info2040.csv", DataFrame)
df2 = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Inputs_LDES_Preliminar6/inputs/gen_build_predetermined.csv", DataFrame)

df = df2040[:, [:GENERATION_PROJECT, :gen_energy_source]]
df_names = filter(row -> row.gen_energy_source == "Carbon", df)
names = df_names.GENERATION_PROJECT

build_years = []
capacities = []
max_ages_2030 = []
max_ages_2035 = []
max_ages_2040 = []

# Iterar sobre los nombres de los generadores
for name in names
    idx = findfirst(x -> x == name, df2.GENERATION_PROJECT)
    
    if !isnothing(idx)
        push!(build_years, df2[idx, :build_year])
        push!(capacities, df2[idx, :build_gen_predetermined])
    else
        push!(build_years, missing)
        push!(capacities, missing)
    end

    # Ahora buscar la vida útil de la central en cada uno de los dataframes de los escenarios
    idx2030 = findfirst(x -> x == name, df2030.GENERATION_PROJECT)
    if !isnothing(idx2030)
        push!(max_ages_2030, df2030[idx2030, :gen_max_age]-1)
    else
        push!(max_ages_2030, missing)
    end

    idx2035 = findfirst(x -> x == name, df2035.GENERATION_PROJECT)
    if !isnothing(idx2035)
        push!(max_ages_2035, df2035[idx2035, :gen_max_age]-1)
    else
        push!(max_ages_2035, missing)
    end

    idx2040 = findfirst(x -> x == name, df2040.GENERATION_PROJECT)
    if !isnothing(idx2040)
        push!(max_ages_2040, df2040[idx2040, :gen_max_age]-1)
    else
        push!(max_ages_2040, missing)
    end
end

df_names = hcat(df_names, DataFrame(buildYear = build_years, capacidadInstalada = capacities, 
                                    maxAge2030 = max_ages_2030, maxAge2035 = max_ages_2035, maxAge2040 = max_ages_2040))

println(df_names)

start_year = 2024
end_year = 2050

installed_capacity_2030 = []
installed_capacity_2035 = []
installed_capacity_2040 = []

# Calcular la capacidad instalada total por año desde 2024 hasta 2050 para cada escenario
for year in start_year:end_year
    total_capacity_2030 = 0
    total_capacity_2035 = 0
    total_capacity_2040 = 0
    
    # Iterar sobre cada generador en df_names
    for i in 1:nrow(df_names)
        build_year = df_names[i, :buildYear]
        capacity = df_names[i, :capacidadInstalada]
        
        if !ismissing(build_year) && !ismissing(capacity)
            max_age_2030 = df_names[i, :maxAge2030]
            max_age_2035 = df_names[i, :maxAge2035]
            max_age_2040 = df_names[i, :maxAge2040]
            
            # Verificar si la central está activa en cada escenario
            if !ismissing(max_age_2030) && build_year + max_age_2030 >= year
                total_capacity_2030 += capacity
            end
            
            if !ismissing(max_age_2035) && build_year + max_age_2035 >= year
                total_capacity_2035 += capacity
            end
            
            if !ismissing(max_age_2040) && build_year + max_age_2040 >= year
                total_capacity_2040 += capacity
            end
        end
    end
    
    push!(installed_capacity_2030, total_capacity_2030)
    push!(installed_capacity_2035, total_capacity_2035)
    push!(installed_capacity_2040, total_capacity_2040)
end

capacity_df = DataFrame(
    Year = start_year:end_year,
    InstalledCapacity2030 = installed_capacity_2030,
    InstalledCapacity2035 = installed_capacity_2035,
    InstalledCapacity2040 = installed_capacity_2040
)

println(capacity_df)
plot(capacity_df.Year, capacity_df.InstalledCapacity2030, label="Escenario 2040", xlabel="Año", ylabel="Capacidad Instalada (MW)", 
     title="Capacidad Instalada Total de Centrales a Carbón", linewidth=2, color=:red, marker=:circle)
plot!(capacity_df.Year, capacity_df.InstalledCapacity2035, label="Escenario 2035", linewidth=2, color=:blue, marker=:circle)
plot!(capacity_df.Year, capacity_df.InstalledCapacity2040, label="Escenario 2030", linewidth=2, color=:green, marker=:circle)

