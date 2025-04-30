using DataFrames
using CSV
using Plots

df = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Inputs_LDES_Preliminar6/inputs/variable_capacity_factors.csv", DataFrame)

df_laja1 = filter(row -> row.GENERATION_PROJECT == "Las_Lajas", df)

df_laja1_2024 = filter(row -> occursin("2024", string(row.timepoint)), df_laja1)

result = DataFrame(GENERATION_PROJECT=String[], month=Int[], gen_max_capacity_factor_sum=Float64[])

# Iterar sobre los datos para agrupar cada 24 filas (por mes)
for i in 1:24:nrow(df_laja1_2024)
    block = df_laja1_2024[i:min(i+23, nrow(df_laja1_2024)), :]
    
    if nrow(block) == 24
        gen_project = block.GENERATION_PROJECT[1]
        
        total_gen_max_capacity_factor = sum(block.gen_max_capacity_factor)
        
        month = ceil(Int, i / 24)  # mes de 1 a 12
        
        push!(result, (gen_project, month, total_gen_max_capacity_factor*213.24*30))
    end
end

println(result)

months = result.month
gen_max_capacity_factor_sum = result.gen_max_capacity_factor_sum

month_labels = ["Mes$i" for i in 1:12]

gen_max_capacity_factor_sum_int = round.(Int, gen_max_capacity_factor_sum)
bar(month_labels, gen_max_capacity_factor_sum_int, 
    xlabel="Meses", ylabel="Energía generada MWh", 
    title="Hidrología central Las lajas (Embalse), año 2026", 
    legend=false, 
    yticks=(0:20000:maximum(gen_max_capacity_factor_sum_int), 
            string.(0:20000:maximum(gen_max_capacity_factor_sum_int)))) # Fo