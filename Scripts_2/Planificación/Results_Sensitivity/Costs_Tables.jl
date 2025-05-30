# Script para generar un vector con un resumen de costos totales de planificación para cada escenario, diferenciado por item
using CSV
using DataFrames

df_fuente = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/Estudio_Oficial/Sensibilidades/OK/Corridos/Ausencia_Diesel&GNL/TA/outputs/cost_components.csv", DataFrame)

function calculate_present_value(future_value, discount_rate, years)
    return future_value / ((1 + discount_rate) ^ years)
end

function calculate_annuity_value(payment, discount_rate, periods)
    return (1 - (1 + discount_rate) ^ -periods) / discount_rate * payment
end

# Define the discount rate
discount_rate = 0.06

# Define the periods of investment
investment_periods = Dict(
    2024 => 3,
    2026 => 3,
    2029 => 1,
    2030 => 1,
    2031 => 2,
    2033 => 7,
    2040 => 10,
    2050 => 10
)

# Read the CSV file into a DataFrame
df = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/Estudio_Oficial/Sensibilidades/OK/Corridos/Ausencia_Diesel&GNL/TA/outputs/dispatch_annual_summary.csv", DataFrame)

# Initialize a dictionary to store the NPV for each energy source
npv_dict = Dict{String, Float64}()

# Iterate over each unique energy source
for energy_source in unique(df.gen_energy_source)
    # Filter the DataFrame for the current energy source
    df_filtered = df[df.gen_energy_source .== energy_source, :]
    
    # Initialize the total NPV for the current energy source
    total_npv = 0.0
    
    # Iterate over each row in the filtered DataFrame
    for row in eachrow(df_filtered)
        period = row[:period]
        gen_capital_costs = row[:GenCapitalCosts]
        gen_fixed_om_costs = row[:GenFixedOMCosts]
        
        # Calculate the annuity value at the start of the investment period for GenCapitalCosts
        annuity_value_capital = calculate_annuity_value(gen_capital_costs, discount_rate, investment_periods[period])
        
        # Calculate the annuity value at the start of the investment period for GenFixedOMCosts
        annuity_value_fixed_om = calculate_annuity_value(gen_fixed_om_costs, discount_rate, investment_periods[period])
        
        # Calculate the present value of the annuity value at the base year (2024) for GenCapitalCosts
        present_value_capital = calculate_present_value(annuity_value_capital, discount_rate, period - 2024)
        
        # Calculate the present value of the annuity value at the base year (2024) for GenFixedOMCosts
        present_value_fixed_om = calculate_present_value(annuity_value_fixed_om, discount_rate, period - 2024)
        
        # Add the present values to the total NPV for the current energy source
        total_npv += present_value_capital + present_value_fixed_om
    end
    
    # Store the total NPV for the current energy source in the dictionary
    npv_dict[energy_source] = total_npv / 1000000
end

# Combine specific technologies into LDES, ESS, and Gens categories
ldes_technologies = ["Bomb", "CAES", "TES"]
ess_technology = "ESS"
ess_technologys = ["Bomb", "CAES", "TES", "ESS"]

ldes_npv = sum(npv_dict[tech] for tech in ldes_technologies if haskey(npv_dict, tech))
ess_npv = get(npv_dict, ess_technology, 0.0)
gens_npv = sum(npv_dict[tech] for tech in keys(npv_dict) if !(tech in ess_technologys))

# Print the NPV for each category and the total NPV
println("The NPV for LDES is $ldes_npv million USD.")
println("The NPV for ESS is $ess_npv million USD.")
println("The NPV for Gens is $gens_npv million USD.")
println("The total NPV across all categories is $(ess_npv + gens_npv + ldes_npv) million USD.")

df_fuente.npv_cost = df_fuente.npv_cost./1000000

push!(df_fuente, ("Ldes_nvp", ldes_npv))
push!(df_fuente, ("ess_npv", ess_npv))
push!(df_fuente, ("gens_npv", gens_npv))

println(df_fuente)

CSV.write("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/Estudio_Oficial/Sensibilidades/OK/Corridos/Ausencia_Diesel&GNL/TA/NVP_costs.csv", df_fuente)