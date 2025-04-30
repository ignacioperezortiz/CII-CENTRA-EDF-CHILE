# script para crear el archivo fuel_cost.csv en base a la pelp
using CSV
using DataFrames
using Dates
using Statistics
using Random


catalogo_zonas1 = Dict(
    "Arica y Parinacota" => "Parinacota220",
    "Tarapaca" => "Lagunas220",
    "Tarapaca_2" => "NuevaPozoAlmonte220",
    "Antofagasta" => "Kimal220",
    "Antofagasta_2" => "LosChangos500",
    "Antofagasta_3" => "Parinas500",
    "Antofagasta_4" => "LosChangos220",
    "Antofagasta_5" => "Kimal500",
    "Antofagasta_5H2" => "Kimal500H2",
    "Antofagasta_7" => "NuevaZaldivar220",
    "Los Lagos" => "NuevaPuertoMontt500",
    "Los Lagos_2" => "NuevaAncud500",
    "Atacama" => "NuevaMaitencillo500",
    "Atacama_2" => "Cumbre500",
    "Atacama_3" => "NuevaCardones500",
    "Los Rios" => "Pichirropulli500",
    "Coquimbo" => "NuevaPandeAzucar500",
    "Bio Bio" => "Mulchen500",
    "Bio Bio_2" => "Concepcion500",
    "Bio Bio_3" => "NuevaCharrua500",
    "Bio Bio_3H2" => "NuevaCharrua500H2",
    "Libertador General Bernardo Ohiggins_2" => "Candelaria500",
    "Libertador General Bernardo Ohiggins" => "Rapel500",
    "Metropolitana de Santiago" => "AltoJahuel500",
    "Metropolitana de Santiago_2" => "Polpaico500",
    "Maule" => "Ancoa500",
    "Valparaiso" => "Quillota500",
    "Araucania" => "RioMalleco500",
    "Metropolitana de Santiago_2H2" => "Polpaico500H2"
)
catalogo_zonas = Dict(v => k for (k, v) in catalogo_zonas1)

Load_zones = collect(keys(catalogo_zonas))
function generar_csv(Thermal_gen_URL::String, output_csv_path::String, catalogo_zonas::Dict)
    # Leer el archivo de demanda
    Fuels_url = "G:/Mi unidad/Trabajo_Centra/Catedra_AlmacenamientoLD/Switch/SEN/Fuentes/BD-Pelp-2023-2027/Base de Datos PELP 2023-2027 Informe Preliminar_v2/Rumbo a la CN en 2050/Input/Rumbo  a la Carbono Neutralidad_Fuel.csv"
    Fuels_prices_url= "G:/Mi unidad/Trabajo_Centra/Catedra_AlmacenamientoLD/Switch/SEN/Fuentes/BD-Pelp-2023-2027/Base de Datos PELP 2023-2027 Informe Preliminar_v2/Rumbo a la CN en 2050/Input/Rumbo  a la Carbono Neutralidad_fuel_price/fuel_price.csv"
    df1 = CSV.read(Thermal_gen_URL, DataFrame)
    df3 = filter(row -> row.name != "Llanos Blancos", df1)
    df2 = filter(row -> row.scenario == "PComb_Bajo", df3)        ### cambiar filtro
    df = filter!(row -> row.connected == 1, df2)
    df_fuels = CSV.read(Fuels_url, DataFrame)
    df_fuels_prices = CSV.read(Fuels_prices_url, DataFrame)
    dict_fuels = Dict(row.name => row.fuel_type for row in eachrow(df_fuels))
    dict_fuels2 = Dict("biomass" => "Biomasa",
    "diesel" => "Diesel",
    "coal" => "Carbon",
    "gnl" => "GNL",
    "cogeneration" => "Cogeneracion",
    "geothermal" => "Geotermica",
    "fueloil" => "Biogas")

    rows = []

    # Definir años y número de días representativos
    años = [2020, 2023, 2026, 2029, 2030, 2031, 2033, 2040, 2050]
    for j in años
        for i in 1:length(df.name)
            Project_name = df.name[i]
            Fuel_name = dict_fuels2[dict_fuels[df.fuel_name[i]]]
            nombre_zona_GX = "Gxnode-"*Project_name*"-"*catalogo_zonas[df.busbar[i]]
            project_name_symbol = Symbol("Comb_", Project_name)
            fuel_price = df_fuels_prices[!, project_name_symbol][j - 2019]
            push!(rows, (nombre_zona_GX, Fuel_name, j, fuel_price))
        end
    end
    push!(rows, ("Gxnode-Llanos Blancos-Coquimbo","Diesel",2020,657.9344466542269))
    push!(rows, ("Gxnode-Llanos Blancos-Coquimbo","Diesel",2023,838.5130346964777))
    push!(rows, ("Gxnode-Llanos Blancos-Coquimbo","Diesel",2026,944.5638608119722))
    push!(rows, ("Gxnode-Llanos Blancos-Coquimbo","Diesel",2029,1001.8099278190131))
    push!(rows, ("Gxnode-Llanos Blancos-Coquimbo","Diesel",2030,1027.7989754246466))
    push!(rows, ("Gxnode-Llanos Blancos-Coquimbo","Diesel",2031,1041.754925427466))
    push!(rows, ("Gxnode-Llanos Blancos-Coquimbo","Diesel",2033,1073.6533810556357))
    push!(rows, ("Gxnode-Llanos Blancos-Coquimbo","Diesel",2040,1168.8524185669032))
    push!(rows, ("Gxnode-Llanos Blancos-Coquimbo","Diesel",2050,1283.6486873584497))
    output_df = DataFrame(rows, [:load_zone, :fuel, :period, :fuel_cost])
    CSV.write(output_csv_path, output_df)
end
Input_url = "G:/Mi unidad/Trabajo_Centra/Catedra_AlmacenamientoLD/Switch/SEN/Fuentes/BD-Pelp-2023-2027/Base de Datos PELP 2023-2027 Informe Preliminar_v2/Rumbo a la CN en 2050/Input/Rumbo  a la Carbono Neutralidad_ThermalGenerator.csv"
Output_url = "C:/Users/Ignac/Trabajo_Centra/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/fuel_costs/fuel_cost2.csv"
generar_csv(Input_url, Output_url, catalogo_zonas)