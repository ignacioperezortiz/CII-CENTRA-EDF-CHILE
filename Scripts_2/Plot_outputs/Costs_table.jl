using DataFrames
using CSV
using XLSX

# Definir la carpeta base que contiene las carpetas de los escenarios
base_dir = "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Estudio_oficial/Estudio_Oficial/Sensibilidades/1/"

# Obtener la lista de carpetas de escenarios
scenarios = readdir(base_dir, join=true) |> filter(isdir)

# Inicializar un DataFrame vacío para almacenar los datos combinados
combined_df = DataFrame()
combined_df2 = DataFrame()

# Iterar sobre cada carpeta de escenario y procesar los archivos
for scenario in scenarios
    println("Processing scenario: $scenario")
    
    # Verificar si el directorio del escenario está vacío
    if isempty(readdir(scenario * "/outputs"))
        println("Skipping empty scenario: $scenario")
        continue
    end
    
    # Leer el archivo costs_itemized.csv
    file_path = joinpath(scenario, "outputs", "costs_itemized.csv")
    if !isfile(file_path)
        println("Skipping missing costs_itemized file in scenario: $scenario")
        continue
    end
    data = CSV.read(file_path, DataFrame)

    # Leer el archivo dispatch_annual_summary.csv
    file_path2 = joinpath(scenario, "outputs", "dispatch_annual_summary.csv")
    if !isfile(file_path2)
        println("Skipping missing dispatch_annual_summary file in scenario: $scenario")
        continue
    end
    data2 = CSV.read(file_path2, DataFrame)
    
    # Cambiar los nombres de las columnas
    println(names(data))
    replace!(data.Component, "StorageEnergyFixedCost" => "OtherGENSCapitalCosts", "LocalTDFixedCosts" => "LDESCapitalCosts")

    # Pivotar el DataFrame para obtener la estructura deseada
    pivot_df = unstack(data, :Component, :PERIOD, :AnnualCost_NPV)

    # Filtrar y sumar los datos de dispatch para LDESCapitalCosts
    ldes_techs = ["Bomb", "Solar_CSP", "TES"]
    ldes_df = filter(row -> row.gen_tech in ldes_techs, data2)
    ldes_sum = combine(groupby(ldes_df, :period), :GenCapitalCosts => sum => :LDESCapitalCosts)
    # println(ldes_sum)

    pivot_ldes_sum = unstack(ldes_sum, :period, :LDESCapitalCosts)
    # println(pivot_ldes_sum)
    # println(pivot_df)
    # Usar la primera fila de pivot_ldes_sum para llenar las filas correspondiente en data
    if "LDESCapitalCosts" in data.Component
        row_idx = findfirst(data.Component .== "LDESCapitalCosts")
        for col in names(pivot_ldes_sum)[2:end]
            pivot_df[row_idx, Symbol(col)] = pivot_ldes_sum[1, Symbol(col)]
        end
    end
    # println(pivot_df)
    
    # Filtrar y sumar los datos de dispatch para LDESCapitalCosts
    BESS_techs = ["ESS"]
    BESS_df = filter(row -> row.gen_tech in BESS_techs, data2)
    BESS_sum = combine(groupby(BESS_df, :period), :GenCapitalCosts => sum => :BESSCapitalCosts)
    # println(ldes_sum)

    pivot_BESS_sum = unstack(BESS_sum, :period, :BESSCapitalCosts)
    # println(pivot_BESS_sum)
    push!(pivot_df, ("BESSCapitalCosts", pivot_BESS_sum."2024"[1], pivot_BESS_sum."2026"[1], pivot_BESS_sum."2029"[1], pivot_BESS_sum."2030"[1], pivot_BESS_sum."2031"[1], pivot_BESS_sum."2033"[1], pivot_BESS_sum."2040"[1], pivot_BESS_sum."2050"[1]))
    # println(pivot_BESS_sum)

    # Filtrar y sumar los datos de dispatch para otras tecnologías excluyendo ESS y CSP-TES
    other_techs = filter(row -> !(row.gen_tech in ldes_techs) && !(row.gen_tech in ["ESS", "CSP-TES"]), data2)
    # println(other_techs)
    other_sum = combine(groupby(other_techs, :period), :GenCapitalCosts => sum => :OtherGENSCapitalCosts)
    pivot_other_sum = unstack(other_sum, :period, :OtherGENSCapitalCosts)
    # println(pivot_other_sum)
    if "OtherGENSCapitalCosts" in data.Component
        row_idx = findfirst(data.Component .== "OtherGENSCapitalCosts")
        for col in names(pivot_other_sum)[2:end]
            pivot_df[row_idx, Symbol(col)] = pivot_other_sum[1, Symbol(col)]
        end
    end
    # println(pivot_df)
    # println(other_sum)
    # Filtrar y sumar los datos de dispatch para LDESFixedOMCosts
    ldes_fixed_om_sum = combine(groupby(ldes_df, :period), :GenFixedOMCosts => sum => :LDESFixedOMCosts)
    pivot_ldes_fixed_om_sum = unstack(ldes_fixed_om_sum, :period, :LDESFixedOMCosts)
    push!(pivot_df, ("LDESFixedOMCosts", 0, pivot_ldes_fixed_om_sum."2026"[1], pivot_ldes_fixed_om_sum."2029"[1], pivot_ldes_fixed_om_sum."2030"[1], pivot_ldes_fixed_om_sum."2031"[1], pivot_ldes_fixed_om_sum."2033"[1], pivot_ldes_fixed_om_sum."2040"[1], pivot_ldes_fixed_om_sum."2050"[1]))

    # Filtrar y sumar los datos de dispatch para BESSFixedOMCosts
    bess_fixed_om_sum = combine(groupby(BESS_df, :period), :GenFixedOMCosts => sum => :BESSFixedOMCosts)
    pivot_bess_fixed_om_sum = unstack(bess_fixed_om_sum, :period, :BESSFixedOMCosts)
    push!(pivot_df, ("BESSFixedOMCosts", pivot_bess_fixed_om_sum."2024"[1], pivot_bess_fixed_om_sum."2026"[1], pivot_bess_fixed_om_sum."2029"[1], pivot_bess_fixed_om_sum."2030"[1], pivot_bess_fixed_om_sum."2031"[1], pivot_bess_fixed_om_sum."2033"[1], pivot_bess_fixed_om_sum."2040"[1], pivot_bess_fixed_om_sum."2050"[1]))

    # Filtrar y sumar los datos de dispatch para otras tecnologías excluyendo ESS y CSP-TES para OtherGENSFixedOMCosts
    other_fixed_om_sum = combine(groupby(other_techs, :period), :GenFixedOMCosts => sum => :OtherGENSFixedOMCosts)
    pivot_other_fixed_om_sum = unstack(other_fixed_om_sum, :period, :OtherGENSFixedOMCosts)
    push!(pivot_df, ("OtherGENSfixed_om", pivot_other_fixed_om_sum."2024"[1], pivot_other_fixed_om_sum."2026"[1], pivot_other_fixed_om_sum."2029"[1], pivot_other_fixed_om_sum."2030"[1], pivot_other_fixed_om_sum."2031"[1], pivot_other_fixed_om_sum."2033"[1], pivot_other_fixed_om_sum."2040"[1], pivot_other_fixed_om_sum."2050"[1]))

    # Mostrar el DataFrame final
    ldes_Var_om_sum = combine(groupby(ldes_df, :period), :VariableCost_per_yr => sum => :LDESVariableCost_per_yr)
    pivot_ldes_Var_om_sum = unstack(ldes_Var_om_sum, :period, :LDESVariableCost_per_yr)
    push!(pivot_df, ("LDESVar_omCosts", 0, pivot_ldes_Var_om_sum."2026"[1], pivot_ldes_Var_om_sum."2029"[1], pivot_ldes_Var_om_sum."2030"[1], pivot_ldes_Var_om_sum."2031"[1], pivot_ldes_Var_om_sum."2033"[1], pivot_ldes_Var_om_sum."2040"[1], pivot_ldes_Var_om_sum."2050"[1]))

    # Filtrar y sumar los datos de dispatch para BESSFixedOMCosts
    bess_Var_om_sum = combine(groupby(BESS_df, :period), :VariableCost_per_yr => sum => :BESSVariableCost_per_yr)
    pivot_bess_Var_om_sum = unstack(bess_Var_om_sum, :period, :BESSVariableCost_per_yr)
    push!(pivot_df, ("BESSVar_omCosts", pivot_bess_Var_om_sum."2024"[1], pivot_bess_Var_om_sum."2026"[1], pivot_bess_Var_om_sum."2029"[1], pivot_bess_Var_om_sum."2030"[1], pivot_bess_Var_om_sum."2031"[1], pivot_bess_Var_om_sum."2033"[1], pivot_bess_Var_om_sum."2040"[1], pivot_bess_Var_om_sum."2050"[1]))

    # Filtrar y sumar los datos de dispatch para otras tecnologías excluyendo ESS y CSP-TES para OtherGENSFixedOMCosts
    other_Var_om_sum = combine(groupby(other_techs, :period), :VariableCost_per_yr => sum => :OtherGENSVariableCost_per_yr)
    pivot_other_Var_om_sum = unstack(other_Var_om_sum, :period, :OtherGENSVariableCost_per_yr)
    push!(pivot_df, ("OtherVar_omCosts", pivot_other_Var_om_sum."2024"[1], pivot_other_Var_om_sum."2026"[1], pivot_other_Var_om_sum."2029"[1], pivot_other_Var_om_sum."2030"[1], pivot_other_Var_om_sum."2031"[1], pivot_other_Var_om_sum."2033"[1], pivot_other_Var_om_sum."2040"[1], pivot_other_Var_om_sum."2050"[1]))
    
    # Redondear todos los elementos a un entero, exceptuando el contenido de la columna "Component"
    println(pivot_df)
    for col in names(pivot_df)[2:end]
        pivot_df[!, col] = round.(Int, pivot_df[!, col])
    end
    
    # Guardar el DataFrame pivot_df en un archivo Excel para cada escenario
    output_file = joinpath(scenario, "$(basename(scenario))_Costs_per_period.csv")
    CSV.write(output_file, pivot_df)
    println("Saved pivot_df to $output_file")
end