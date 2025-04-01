using CSV
using DataFrames
using Dates

# Leer el archivo de demanda
df = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/demanda.csv", DataFrame)
escenarios = ["transicion_acelerada", "rumbo_TA", "recuperacion_lenta"]
df_demanda_total = DataFrame(year=Int[], demanda_total=Float64[], escenario=String[])

# Mostrar la demanda total por año
# println(df_demanda_total)

# Crear el DataFrame inicial
items = ["Potencia no servida", "Recortes", "Recortes %", "Emisiones CO2 anual (MM)", "Energía movida por BESS anual",
         "Energía movida por LDES", "Energía total demandada (GWh)", "Capacidad instalada Generación","Capacidad instalada BESS", "Capacidad instalada LDES",
         "Generación bruta", "Participación renovable", "Participación renovable variable",  "Costos marginales", "Congestiones sistémicas","Participación renovable energía", "Participación renovable variable energía",]

df = DataFrame(Item = items)

# Agregar las columnas adicionales llenas de ceros y asegurarse de que sean de tipo Float64
for year in ["2024", "2026", "2029", "2030", "2031", "2033", "2040", "2050"]
    df[!, Symbol(year)] = fill(0.0, length(items))
end

# Llenar la fila "Energía total demandada (GWh)" con 
df_demanda = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/outputs/electricity_cost.csv", DataFrame)
for row in eachrow(df_demanda)
    period = string(row.PERIOD)
    if period in names(df)
        df[df.Item .== "Energía total demandada (GWh)", Symbol(period)] .= row.SystemDemandPerYear_MWh/1000
        df[df.Item .== "Costos marginales", Symbol(period)] .= row.EnergyCostReal_per_MWh
    end
end

# Mostrar el DataFrame actualizado
# println(df)

# Llenar columna Emisiones CO2 anual
Emissions_DF = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/outputs/emissions.csv", DataFrame)

# Asignar valores de Emissions_DF a df
for row in eachrow(Emissions_DF)
    period = string(row.PERIOD)
    if period in names(df)
        df[df.Item .== "Emisiones CO2 anual (MM)", Symbol(period)] .= row.AnnualEmissions_tCO2_per_yr / 1000
    end
end

# Mostrar el DataFrame actualizado
# println(df)

# Llenar columna Energía movida por BESS
dispatch_annual_summary = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/outputs/dispatch_annual_summary.csv", DataFrame)

# Filtrar el DataFrame para obtener solo las filas donde gen_tech es "ESS"
filtered_dispatch = filter(row -> row.gen_tech == "ESS", dispatch_annual_summary)

# Asignar valores de filtered_dispatch a df
for row in eachrow(filtered_dispatch)
    period = string(row.period)
    if period in names(df)
        df[df.Item .== "Energía movida por BESS anual", Symbol(period)] .= row.Discharge_GWh_typical_yr
    end
end

# Mostrar el DataFrame actualizado
# println(df)

# Llenar columna Energía movida por LDES
filtered_dispatch2 = filter(row -> row.gen_tech in ["Bomb", "TES", "CAES", "CSP-TES"], dispatch_annual_summary)

# Asignar valores de filtered_dispatch2 a df sumando los valores de las distintas teTAologías para cada periodo
for period in unique(filtered_dispatch2.period)
    total_discharge = sum(filtered_dispatch2[filtered_dispatch2.period .== period, :Discharge_GWh_typical_yr])
    if string(period) in names(df)
        df[df.Item .== "Energía movida por LDES", Symbol(string(period))] .= total_discharge
    end
end

# Mostrar el DataFrame actualizado
# println(df)

# Llenar fila Capacidad instalada Generación
df_anual_summary3 = filter(row -> row.gen_tech in ["HYDRO", "PV", "TERMO", "WIND"], dispatch_annual_summary)
for period in unique(df_anual_summary3.period)
    total_capacity = sum(df_anual_summary3[df_anual_summary3.period .== period, :GenCapacity_MW])
    total_gen = sum(df_anual_summary3[df_anual_summary3.period .== period, :Energy_GWh_typical_yr])
    total_demand = sum(dispatch_annual_summary[dispatch_annual_summary.period .== period, :Energy_GWh_typical_yr])
    if string(period) in names(df)
        df[df.Item .== "Capacidad instalada Generación", Symbol(string(period))] .= total_capacity
        df[df.Item .== "Generación bruta", Symbol(string(period))] .= total_gen
        # df[df.Item .== "Energía total demandada (GWh)", Symbol(string(period))] .= total_demand
    end
end

# Mostrar el DataFrame actualizado con la fila Capacidad instalada Generación llena
# println(df)

# Llenar fila Capacidad instalada BESS
df_anual_summary4 = filter(row -> row.gen_tech in ["Bomb", "TES", "CAES", "CSP-TES"], dispatch_annual_summary)
for period in unique(df_anual_summary4.period)
    total_capacity = sum(df_anual_summary4[df_anual_summary4.period .== period, :GenCapacity_MW])
    if string(period) in names(df)
        df[df.Item .== "Capacidad instalada LDES", Symbol(string(period))] .= total_capacity
    end
end

# Mostrar el DataFrame actualizado con la fila Capacidad instalada Generación llena
# println(df)

# Llenar fila Capacidad instalada BESS
df_anual_summary4 = filter(row -> row.gen_tech in ["ESS"], dispatch_annual_summary)
for period in unique(df_anual_summary4.period)
    total_capacity = sum(df_anual_summary4[df_anual_summary4.period .== period, :GenCapacity_MW])
    if string(period) in names(df)
        df[df.Item .== "Capacidad instalada BESS", Symbol(string(period))] .= total_capacity
    end
end

# Mostrar el DataFrame actualizado con la fila Capacidad instalada Generación llena
# println(df)

# Llenar fila participación renovable
df_anual_summary5 = filter(row -> row.gen_energy_source in ["Hidroelectrica", "Solar_CSP","Solar_FV","Biomasa","Cogeneracion","Geotermica","Eolica"], dispatch_annual_summary)
for period in unique(df_anual_summary5.period)
    total_capacity = sum(df_anual_summary5[df_anual_summary5.period .== period, :GenCapacity_MW])
    total_capacity2 = sum(df_anual_summary3[df_anual_summary3.period .== period, :GenCapacity_MW])
    if string(period) in names(df)
        df[df.Item .== "Participación renovable", Symbol(string(period))] .= total_capacity/total_capacity2*100
    end
end

# Llenar fila participación renovable variable
df_anual_summary5 = filter(row -> row.gen_tech in ["PV", "WIND"], dispatch_annual_summary)
for period in unique(df_anual_summary5.period)
    total_capacity = sum(df_anual_summary5[df_anual_summary5.period .== period, :GenCapacity_MW])
    total_capacity2 = sum(df_anual_summary3[df_anual_summary3.period .== period, :GenCapacity_MW])
    if string(period) in names(df)
        df[df.Item .== "Participación renovable variable", Symbol(string(period))] .= total_capacity/total_capacity2*100
    end
end

# Llenar columna Energía movida por renovables
filtered_dispatch5 = filter(row -> row.gen_energy_source in ["Hidroelectrica", "Solar_CSP","Solar_FV","Biomasa","Cogeneracion","Geotermica","Eolica"], dispatch_annual_summary)

# Asignar valores de filtered_dispatch2 a df sumando los valores de las distintas teTAologías para cada periodo
for period in unique(filtered_dispatch5.period)
    total_discharge = sum(filtered_dispatch5[filtered_dispatch5.period .== period, :Energy_GWh_typical_yr])
    total_energy = sum(df_anual_summary3[df_anual_summary3.period .== period, :Energy_GWh_typical_yr])
    if string(period) in names(df)
        df[df.Item .== "Participación renovable energía", Symbol(string(period))] .= total_discharge/total_energy*100
    end
end

# Llenar columna Energía movida por renovables variables
filtered_dispatch6 = filter(row -> row.gen_tech in ["PV", "WIND"], dispatch_annual_summary)

# Asignar valores de filtered_dispatch2 a df sumando los valores de las distintas teTAologías para cada periodo
for period in unique(filtered_dispatch6.period)
    total_discharge = sum(filtered_dispatch6[filtered_dispatch6.period .== period, :Energy_GWh_typical_yr])
    total_energy = sum(df_anual_summary3[df_anual_summary3.period .== period, :Energy_GWh_typical_yr])
    if string(period) in names(df)
        df[df.Item .== "Participación renovable variable energía", Symbol(string(period))] .= total_discharge/total_energy*100
    end
end

# Lectura de archivos
df_dispatch = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/outputs/DispatchGen.csv", DataFrame)
df_limits = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/inputs/variable_capacity_factors.csv", DataFrame)
df_genbuild = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/outputs/dispatch_gen_annual_summary.csv", DataFrame)

# Trabajo de archivo dispatch para que solo hayan renovables variables
unicue = unique(df_limits.GENERATION_PROJECT)
df_dispatch2 = filter(row -> row.GEN_TPS_1 in unicue, df_dispatch)

# Crear un diccionario para almacenar la capacidad instalada por generador y periodo
capacity_dict = Dict{String, Dict{String, Float64}}()

for row in eachrow(df_genbuild)
    gen_project = row[:generation_project]
    period = string(row[:period])
    capacity = row[:GenCapacity_MW]
    
    if !haskey(capacity_dict, gen_project)
        capacity_dict[gen_project] = Dict{String, Float64}()
    end
    
    capacity_dict[gen_project][period] = capacity
end

# Añadir la columna de capacidad instalada al dataframe df_dispatch2
df_dispatch2[:, :Installed_Capacity_MW] = [capacity_dict[row[:GEN_TPS_1]][string(row[:GEN_TPS_2])[1:4]] for row in eachrow(df_dispatch2)]
# println(df_dispatch2[16000:17000,:])
# Crear un diccionario para almacenar el factor de capacidad máxima por generador y punto de tiempo
capacity_factor_dict = Dict{String, Dict{String, Float64}}()

for row in eachrow(df_limits)
    gen_project = row[:GENERATION_PROJECT]
    timepoint = string(row[:timepoint])
    capacity_factor = row[:gen_max_capacity_factor]
    
    if !haskey(capacity_factor_dict, gen_project)
        capacity_factor_dict[gen_project] = Dict{String, Float64}()
    end
    
    capacity_factor_dict[gen_project][timepoint] = capacity_factor
end

# Añadir la columna de factor de capacidad máxima al dataframe df_dispatch2
df_dispatch2[:, :Max_Capacity_Factor] = [capacity_factor_dict[row[:GEN_TPS_1]][string(row[:GEN_TPS_2])] for row in eachrow(df_dispatch2)]

# Añadir la columna de potencial de generación
df_dispatch2[:, :Generation_Potential] = df_dispatch2[:, :Installed_Capacity_MW] .* df_dispatch2[:, :Max_Capacity_Factor]
# Añadir la columna de recortes
df_dispatch2[:, :Recortes] = df_dispatch2[:, :Generation_Potential].- df_dispatch2[:,:DispatchGen]

# Crear un nuevo DataFrame para sumar los recortes por punto de tiempo
df_recortes_totales = combine(groupby(df_dispatch2, :GEN_TPS_2), :Recortes => sum => :Total_Recortes)
# Crear un nuevo DataFrame para sumar los recortes por punto de tiempo
df_potencial_generacion_totales = combine(groupby(df_dispatch2, :GEN_TPS_2), :Generation_Potential => sum => :Total_Generacion_Potencial)

# Expandir la columna GEN_TPS_2 en tres columnas: año, día y hora
df_recortes_totales[:, :año] = parse.(Int, [string(row[:GEN_TPS_2])[1:4] for row in eachrow(df_recortes_totales)])
df_recortes_totales[:, :día] = parse.(Int, [string(row[:GEN_TPS_2])[5:6] for row in eachrow(df_recortes_totales)])
df_recortes_totales[:, :hora] = parse.(Int, [string(row[:GEN_TPS_2])[9:10] for row in eachrow(df_recortes_totales)])

# Expandir la columna GEN_TPS_2 en tres columnas: año, día y hora
df_potencial_generacion_totales[:, :año] = parse.(Int, [string(row[:GEN_TPS_2])[1:4] for row in eachrow(df_potencial_generacion_totales)])
df_potencial_generacion_totales[:, :día] = parse.(Int, [string(row[:GEN_TPS_2])[5:6] for row in eachrow(df_potencial_generacion_totales)])
df_potencial_generacion_totales[:, :hora] = parse.(Int, [string(row[:GEN_TPS_2])[9:10] for row in eachrow(df_potencial_generacion_totales)])

# df_recortes_totales

# Crear un nuevo DataFrame para sumar los recortes diarios
df_recortes_diarios = combine(groupby(df_recortes_totales, [:año, :día]), :Total_Recortes => sum => :Total_Recortes_Diarios)

# Crear un nuevo DataFrame para sumar los recortes diarios
df_potencial_generacion_totales = combine(groupby(df_potencial_generacion_totales, [:año, :día]), :Total_Generacion_Potencial => sum => :Total_Generacion_Potencial_Diarios)

# Añadir una nueva columna con el string concatenado
df_recortes_diarios[:, :GEN_TPS_2] = [string(row[:año]) * lpad(string(row[:día]), 2, '0') * "23" for row in eachrow(df_recortes_diarios)]

# Añadir una nueva columna con el string concatenado
df_potencial_generacion_totales[:, :GEN_TPS_2] = [string(row[:año]) * lpad(string(row[:día]), 2, '0') * "23" for row in eachrow(df_potencial_generacion_totales)]

# df_recortes_diarios
# Leer el archivo timeseries.csv
df_timeseries = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/inputs/timeseries.csv", DataFrame)
# df_timeseries[:, :TIMESERIES] = string.(df_timeseries[:, :TIMESERIES])
# Crear una nueva columna en df_recortes_diarios para ts_scale_to_period
df_recortes_diarios[:, :ts_scale_to_period] = Vector{Float64}(undef, nrow(df_recortes_diarios))
df_recortes_diarios[:, :GEN_TPS_2] = string.(df_recortes_diarios[:, :GEN_TPS_2])
df_recortes_diarios[:, :ts_scale_to_period] = df_timeseries.ts_scale_to_period[:]
# df_recortes_diarios

df_potencial_generacion_totales[:, :ts_scale_to_period] = Vector{Float64}(undef, nrow(df_potencial_generacion_totales))
df_potencial_generacion_totales[:, :GEN_TPS_2] = string.(df_potencial_generacion_totales[:, :GEN_TPS_2])
df_potencial_generacion_totales[:, :ts_scale_to_period] = df_timeseries.ts_scale_to_period[:]

# Multiplicar los recortes de los días 4, 8 y 12 por 4
df_recortes_diarios[df_recortes_diarios[:, :día] .== 4, :Total_Recortes_Diarios] .*= 4
df_recortes_diarios[df_recortes_diarios[:, :día] .== 8, :Total_Recortes_Diarios] .*= 4
df_recortes_diarios[df_recortes_diarios[:, :día] .== 12, :Total_Recortes_Diarios] .*= 4

# Multiplicar los recortes de los días 4, 8 y 12 por 4
df_potencial_generacion_totales[df_potencial_generacion_totales[:, :día] .== 4, :Total_Generacion_Potencial_Diarios] .*= 4
df_potencial_generacion_totales[df_potencial_generacion_totales[:, :día] .== 8, :Total_Generacion_Potencial_Diarios] .*= 4
df_potencial_generacion_totales[df_potencial_generacion_totales[:, :día] .== 12, :Total_Generacion_Potencial_Diarios] .*= 4

df_recortes_diarios.Total_Recortes_Diarios = df_recortes_diarios.Total_Recortes_Diarios.*df_recortes_diarios.ts_scale_to_period
# df_recortes_diarios
df_potencial_generacion_totales.Total_Generacion_Potencial_Diarios = df_potencial_generacion_totales.Total_Generacion_Potencial_Diarios.*df_potencial_generacion_totales.ts_scale_to_period

# Crear un nuevo DataFrame para sumar los recortes anuales
df_recortes_anuales = combine(groupby(df_recortes_diarios, :año), :Total_Recortes_Diarios => sum => :Total_Recortes_Anuales)
df_recortes_anuales.Total_Recortes_Anuales = df_recortes_anuales.Total_Recortes_Anuales./(1000)
df_recortes_anuales.Total_Recortes_Anuales[1] = df_recortes_anuales.Total_Recortes_Anuales[1]/2
df_recortes_anuales.Total_Recortes_Anuales[2] = df_recortes_anuales.Total_Recortes_Anuales[2]/3
df_recortes_anuales.Total_Recortes_Anuales[3] = df_recortes_anuales.Total_Recortes_Anuales[3]/1
df_recortes_anuales.Total_Recortes_Anuales[4] = df_recortes_anuales.Total_Recortes_Anuales[4]/1
df_recortes_anuales.Total_Recortes_Anuales[5] = df_recortes_anuales.Total_Recortes_Anuales[5]/2
df_recortes_anuales.Total_Recortes_Anuales[6] = df_recortes_anuales.Total_Recortes_Anuales[6]/7
df_recortes_anuales.Total_Recortes_Anuales[7] = df_recortes_anuales.Total_Recortes_Anuales[7]/10
df_recortes_anuales.Total_Recortes_Anuales[8] = df_recortes_anuales.Total_Recortes_Anuales[8]/10

# Crear un nuevo DataFrame para sumar los recortes anuales
df_generacion_potencial_anuales = combine(groupby(df_potencial_generacion_totales, :año), :Total_Generacion_Potencial_Diarios => sum => :Total_Potencial_generacion_Anuales)
df_generacion_potencial_anuales.Total_Potencial_generacion_Anuales = df_generacion_potencial_anuales.Total_Potencial_generacion_Anuales./(1000)
df_generacion_potencial_anuales.Total_Potencial_generacion_Anuales[1] = df_generacion_potencial_anuales.Total_Potencial_generacion_Anuales[1]/2
df_generacion_potencial_anuales.Total_Potencial_generacion_Anuales[2] = df_generacion_potencial_anuales.Total_Potencial_generacion_Anuales[2]/3
df_generacion_potencial_anuales.Total_Potencial_generacion_Anuales[3] = df_generacion_potencial_anuales.Total_Potencial_generacion_Anuales[3]/1
df_generacion_potencial_anuales.Total_Potencial_generacion_Anuales[4] = df_generacion_potencial_anuales.Total_Potencial_generacion_Anuales[4]/1
df_generacion_potencial_anuales.Total_Potencial_generacion_Anuales[5] = df_generacion_potencial_anuales.Total_Potencial_generacion_Anuales[5]/2
df_generacion_potencial_anuales.Total_Potencial_generacion_Anuales[6] = df_generacion_potencial_anuales.Total_Potencial_generacion_Anuales[6]/7
df_generacion_potencial_anuales.Total_Potencial_generacion_Anuales[7] = df_generacion_potencial_anuales.Total_Potencial_generacion_Anuales[7]/10
df_generacion_potencial_anuales.Total_Potencial_generacion_Anuales[8] = df_generacion_potencial_anuales.Total_Potencial_generacion_Anuales[8]/10

for period in unique(df_recortes_anuales.año)
    Total_Recortes_Anuales = df_recortes_anuales.Total_Recortes_Anuales[findfirst(x -> x==period, df_recortes_anuales.año)]
    total_discharge = sum(filtered_dispatch6[filtered_dispatch6.period .== period, :Energy_GWh_typical_yr])
    total_energy = sum(df_anual_summary3[df_anual_summary3.period .== period, :Energy_GWh_typical_yr])
    if string(period) in names(df)
        df[df.Item .== "Recortes", Symbol(string(period))] .= Total_Recortes_Anuales
        # df[df.Item .== "Recortes %", Symbol(string(period))] .= (Total_Recortes_Anuales./(total_discharge)).*100
    end
end

for period in unique(df_recortes_anuales.año)
    total_discharge = sum(filtered_dispatch6[filtered_dispatch6.period .== period, :Energy_GWh_typical_yr])
    total_energy = sum(df_anual_summary3[df_anual_summary3.period .== period, :Energy_GWh_typical_yr])
    total_gen = sum(df_anual_summary3[df_anual_summary3.period .== period, :Energy_GWh_typical_yr])
    Total_Recortes_Anuales = df_recortes_anuales.Total_Recortes_Anuales[findfirst(x -> x==period, df_recortes_anuales.año)]
    generacion_potencial_anuales = df_generacion_potencial_anuales.Total_Potencial_generacion_Anuales[findfirst(x -> x==period, df_generacion_potencial_anuales.año)]
    if string(period) in names(df)
        df[df.Item .== "Recortes %", Symbol(string(period))] .= (Total_Recortes_Anuales./((total_discharge/total_energy).*total_gen).*100)
    end
end

println(df)

CSV.write("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Tabla_Resultados_Energeticos.csv", df)