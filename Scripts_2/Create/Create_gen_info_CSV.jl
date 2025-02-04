#Script para crear archivo gen_info.csv en base a la pelp.
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


# bomb 
function generar_csv(input_url::String, output_csv_path::String, catalogo_zonas::Dict)
    # leer archivo de generadores
    df1 = CSV.read(input_url, DataFrame)
    df = filter(row -> occursin("Bomb", row.name), df1)

    rows = []

    for i in 1:length(df.name)
        GENERATION_PROJECT = df.name[i]
        gen_tech = "Bomb"
        gen_load_zone = catalogo_zonas[df.busbar[i]]
        gen_connect_cost_per_mw = df.gen_inv_cost[i]
        gen_capacity_limit_mw = df.pmax[i]
        gen_full_load_heat_rate = "."
        gen_variable_om = df.vomc_avg[i]
        gen_max_age = df.lifetime[i]
        gen_min_build_capacity = 0
        gen_scheduled_outage_rate = df.unavailability[i]
        gen_forced_outage_rate = df.forced_outage_rate[i]
        gen_is_variable = 0
        gen_is_baseload = 0
        gen_is_cogen = 0
        gen_energy_source = "Bomb"
        gen_unit_size = "."
        gen_ccs_capture_efficiency = "."
        gen_ccs_energy_load = "."
        gen_storage_efficiency = df.ess_effc[i]*df.ess_effd[i]
        gen_store_to_release_ratio = "."
        gen_storage_energy_to_power_ratio = df.ess_emax[i]/df.pmax[i]
        gen_storage_max_cycles_per_year = 365
        gen_inertia = df.inertia[i]
        push!(rows, (GENERATION_PROJECT, gen_tech, gen_load_zone,gen_connect_cost_per_mw,gen_capacity_limit_mw,gen_full_load_heat_rate,
        gen_variable_om,gen_max_age,gen_min_build_capacity,gen_scheduled_outage_rate,gen_forced_outage_rate,gen_is_variable,
        gen_is_baseload,gen_is_cogen,gen_energy_source,gen_unit_size,gen_ccs_capture_efficiency,gen_ccs_energy_load,gen_storage_efficiency,
        gen_store_to_release_ratio,gen_storage_energy_to_power_ratio,gen_storage_max_cycles_per_year,gen_inertia))
    end
    # Crear DataFrame y guardar como CSV
    output_df = DataFrame(rows, [:GENERATION_PROJECT, :gen_tech, :gen_load_zone, :gen_connect_cost_per_mw, :gen_capacity_limit_mw, :gen_full_load_heat_rate,
    :gen_variable_om, :gen_max_age, :gen_min_build_capacity, :gen_scheduled_outage_rate, :gen_forced_outage_rate, :gen_is_variable, 
    :gen_is_baseload, :gen_is_cogen, :gen_energy_source, :gen_unit_size, :gen_ccs_capture_efficiency, :gen_ccs_energy_load, :gen_storage_efficiency,
    :gen_store_to_release_ratio, :gen_storage_energy_to_power_ratio, :gen_storage_max_cycles_per_year, :gen_inertia])
    CSV.write(output_csv_path, output_df)
end
Input_url = "G:/Mi unidad/Trabajo_Centra/Catedra_AlmacenamientoLD/Switch/SEN/Fuentes/BD-Pelp-2023-2027/Base de Datos PELP 2023-2027 Informe Preliminar_v2/Rumbo a la CN en 2050/Input/Rumbo  a la Carbono Neutralidad_ESS.csv"
Output_url = "C:/Users/Ignac/Trabajo_Centra/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/GEN_inputs_CSV/gen_info/gen_info_Bomb.csv"
generar_csv(Input_url, Output_url, catalogo_zonas)


# caes
function generar_csv(input_url::String, output_csv_path::String, catalogo_zonas::Dict)
    # leer archivo de generadores
    df1 = CSV.read(input_url, DataFrame)
    df = filter(row -> occursin("CAES", row.name), df1)

    rows = []

    for i in 1:length(df.name)
        GENERATION_PROJECT = df.name[i]
        gen_tech = "CAES"
        gen_load_zone = catalogo_zonas[df.busbar[i]]
        gen_connect_cost_per_mw = df.gen_inv_cost[i]
        gen_capacity_limit_mw = df.pmax[i]
        gen_full_load_heat_rate = "."
        gen_variable_om = df.vomc_avg[i]
        gen_max_age = df.lifetime[i]
        gen_min_build_capacity = 0
        gen_scheduled_outage_rate = df.unavailability[i]
        gen_forced_outage_rate = df.forced_outage_rate[i]
        gen_is_variable = 0
        gen_is_baseload = 0
        gen_is_cogen = 0
        gen_energy_source = "CAES"
        gen_unit_size = "."
        gen_ccs_capture_efficiency = "."
        gen_ccs_energy_load = "."
        gen_storage_efficiency = df.ess_effc[i]*df.ess_effd[i]
        gen_store_to_release_ratio = "."
        gen_storage_energy_to_power_ratio = df.ess_emax[i]/df.pmax[i]
        gen_storage_max_cycles_per_year = 365
        gen_inertia = df.inertia[i]
        push!(rows, (GENERATION_PROJECT, gen_tech, gen_load_zone,gen_connect_cost_per_mw,gen_capacity_limit_mw,gen_full_load_heat_rate,
        gen_variable_om,gen_max_age,gen_min_build_capacity,gen_scheduled_outage_rate,gen_forced_outage_rate,gen_is_variable,
        gen_is_baseload,gen_is_cogen,gen_energy_source,gen_unit_size,gen_ccs_capture_efficiency,gen_ccs_energy_load,gen_storage_efficiency,
        gen_store_to_release_ratio,gen_storage_energy_to_power_ratio,gen_storage_max_cycles_per_year,gen_inertia))
    end
    # Crear DataFrame y guardar como CSV
    output_df = DataFrame(rows, [:GENERATION_PROJECT, :gen_tech, :gen_load_zone, :gen_connect_cost_per_mw, :gen_capacity_limit_mw, :gen_full_load_heat_rate,
    :gen_variable_om, :gen_max_age, :gen_min_build_capacity, :gen_scheduled_outage_rate, :gen_forced_outage_rate, :gen_is_variable, 
    :gen_is_baseload, :gen_is_cogen, :gen_energy_source, :gen_unit_size, :gen_ccs_capture_efficiency, :gen_ccs_energy_load, :gen_storage_efficiency,
    :gen_store_to_release_ratio, :gen_storage_energy_to_power_ratio, :gen_storage_max_cycles_per_year, :gen_inertia])
    CSV.write(output_csv_path, output_df)
end
Input_url = "G:/Mi unidad/Trabajo_Centra/Catedra_AlmacenamientoLD/Switch/SEN/Fuentes/BD-Pelp-2023-2027/Base de Datos PELP 2023-2027 Informe Preliminar_v2/Rumbo a la CN en 2050/Input/Rumbo  a la Carbono Neutralidad_ESS.csv"
Output_url = "C:/Users/Ignac/Trabajo_Centra/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/GEN_inputs_CSV/gen_info/gen_info_CAES.csv"
generar_csv(Input_url, Output_url, catalogo_zonas)


# carnot
function generar_csv(input_url::String, output_csv_path::String, catalogo_zonas::Dict)
    # leer archivo de generadores
    df1 = CSV.read(input_url, DataFrame)
    df = filter(row -> occursin("Carnot", row.name), df1)

    rows = []

    for i in 1:length(df.name)
        GENERATION_PROJECT = df.name[i]
        gen_tech = "Carnot"
        gen_load_zone = catalogo_zonas[df.busbar[i]]
        gen_connect_cost_per_mw = df.gen_inv_cost[i]
        gen_capacity_limit_mw = df.pmax[i]
        gen_full_load_heat_rate = "."
        gen_variable_om = df.vomc_avg[i]
        gen_max_age = df.lifetime[i]
        gen_min_build_capacity = 0
        gen_scheduled_outage_rate = df.unavailability[i]
        gen_forced_outage_rate = df.forced_outage_rate[i]
        gen_is_variable = 0
        gen_is_baseload = 0
        gen_is_cogen = 0
        gen_energy_source = "Carnot"
        gen_unit_size = "."
        gen_ccs_capture_efficiency = "."
        gen_ccs_energy_load = "."
        gen_storage_efficiency = df.ess_effc[i]*df.ess_effd[i]
        gen_store_to_release_ratio = "."
        gen_storage_energy_to_power_ratio = df.ess_emax[i]/df.pmax[i]
        gen_storage_max_cycles_per_year = 365
        gen_inertia = 0
        push!(rows, (GENERATION_PROJECT, gen_tech, gen_load_zone,gen_connect_cost_per_mw,gen_capacity_limit_mw,gen_full_load_heat_rate,
        gen_variable_om,gen_max_age,gen_min_build_capacity,gen_scheduled_outage_rate,gen_forced_outage_rate,gen_is_variable,
        gen_is_baseload,gen_is_cogen,gen_energy_source,gen_unit_size,gen_ccs_capture_efficiency,gen_ccs_energy_load,gen_storage_efficiency,
        gen_store_to_release_ratio,gen_storage_energy_to_power_ratio,gen_storage_max_cycles_per_year,gen_inertia))
    end
    # Crear DataFrame y guardar como CSV
    output_df = DataFrame(rows, [:GENERATION_PROJECT, :gen_tech, :gen_load_zone, :gen_connect_cost_per_mw, :gen_capacity_limit_mw, :gen_full_load_heat_rate,
    :gen_variable_om, :gen_max_age, :gen_min_build_capacity, :gen_scheduled_outage_rate, :gen_forced_outage_rate, :gen_is_variable, 
    :gen_is_baseload, :gen_is_cogen, :gen_energy_source, :gen_unit_size, :gen_ccs_capture_efficiency, :gen_ccs_energy_load, :gen_storage_efficiency,
    :gen_store_to_release_ratio, :gen_storage_energy_to_power_ratio, :gen_storage_max_cycles_per_year, :gen_inertia])
    CSV.write(output_csv_path, output_df)
end
Input_url = "G:/Mi unidad/Trabajo_Centra/Catedra_AlmacenamientoLD/Switch/SEN/Fuentes/BD-Pelp-2023-2027/Base de Datos PELP 2023-2027 Informe Preliminar_v2/Rumbo a la CN en 2050/Input/Rumbo  a la Carbono Neutralidad_ESS.csv"
Output_url = "C:/Users/Ignac/Trabajo_Centra/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/GEN_inputs_CSV/gen_info/gen_info_Carnot.csv"
generar_csv(Input_url, Output_url, catalogo_zonas)


# csp
function generar_csv(input_url::String, output_csv_path::String, catalogo_zonas::Dict)
    # leer archivo de generadores
    df = CSV.read(input_url, DataFrame)
    filter(row -> startswith(row.name, "CSP"), df)

    rows = []

    for i in 1:length(df.name)
        GENERATION_PROJECT = df.name[i]
        gen_tech = "CSP"
        gen_load_zone = catalogo_zonas[df.busbar[i]]
        gen_connect_cost_per_mw = 0
        gen_capacity_limit_mw = df.pmax[i]
        gen_full_load_heat_rate = "."
        gen_variable_om = df.vomc_avg[i]
        gen_max_age = df.lifetime[i]
        gen_min_build_capacity = 0
        gen_scheduled_outage_rate = df.unavailability[i]
        gen_forced_outage_rate = df.forced_outage_rate[i]
        gen_is_variable = 1
        gen_is_baseload = 0
        gen_is_cogen = 0
        gen_energy_source = "Solar_CSP"
        gen_unit_size = "."
        gen_ccs_capture_efficiency = "."
        gen_ccs_energy_load = "."
        gen_storage_efficiency = "."
        gen_store_to_release_ratio = "."
        gen_storage_energy_to_power_ratio = "."
        gen_storage_max_cycles_per_year = "."
        gen_inertia = 5.6
        push!(rows, (GENERATION_PROJECT, gen_tech, gen_load_zone,gen_connect_cost_per_mw,gen_capacity_limit_mw,gen_full_load_heat_rate,
        gen_variable_om,gen_max_age,gen_min_build_capacity,gen_scheduled_outage_rate,gen_forced_outage_rate,gen_is_variable,
        gen_is_baseload,gen_is_cogen,gen_energy_source,gen_unit_size,gen_ccs_capture_efficiency,gen_ccs_energy_load,gen_storage_efficiency,
        gen_store_to_release_ratio,gen_storage_energy_to_power_ratio,gen_storage_max_cycles_per_year,gen_inertia))
    end
    # Crear DataFrame y guardar como CSV
    output_df = DataFrame(rows, [:GENERATION_PROJECT, :gen_tech, :gen_load_zone, :gen_connect_cost_per_mw, :gen_capacity_limit_mw, :gen_full_load_heat_rate,
    :gen_variable_om, :gen_max_age, :gen_min_build_capacity, :gen_scheduled_outage_rate, :gen_forced_outage_rate, :gen_is_variable, 
    :gen_is_baseload, :gen_is_cogen, :gen_energy_source, :gen_unit_size, :gen_ccs_capture_efficiency, :gen_ccs_energy_load, :gen_storage_efficiency,
    :gen_store_to_release_ratio, :gen_storage_energy_to_power_ratio, :gen_storage_max_cycles_per_year, :gen_inertia])
    CSV.write(output_csv_path, output_df)
end
Input_url = "G:/Mi unidad/Trabajo_Centra/Catedra_AlmacenamientoLD/Switch/SEN/Fuentes/BD-Pelp-2023-2027/Base de Datos PELP 2023-2027 Informe Preliminar_v2/Rumbo a la CN en 2050/Input/Rumbo  a la Carbono Neutralidad_CSPGenerator.csv"
Output_url = "C:/Users/Ignac/Trabajo_Centra/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/GEN_inputs_CSV/gen_info/gen_info_CSP.csv"
generar_csv(Input_url, Output_url, catalogo_zonas)


# ESS
function generar_csv(input_url::String, output_csv_path::String, catalogo_zonas::Dict)
    # leer archivo de generadores
    df1 = CSV.read(input_url, DataFrame)
    df = filter(row -> occursin("ESS", row.name), df1)

    rows = []

    for i in 1:length(df.name)
        GENERATION_PROJECT = df.name[i]
        gen_tech = "ESS"
        gen_load_zone = catalogo_zonas[df.busbar[i]]
        gen_connect_cost_per_mw = df.gen_inv_cost[i]
        gen_capacity_limit_mw = df.pmax[i]
        gen_full_load_heat_rate = "."
        gen_variable_om = df.vomc_avg[i]
        gen_max_age = df.lifetime[i]
        gen_min_build_capacity = 0
        gen_scheduled_outage_rate = df.unavailability[i]
        gen_forced_outage_rate = df.forced_outage_rate[i]
        gen_is_variable = 0
        gen_is_baseload = 0
        gen_is_cogen = 0
        gen_energy_source = "ESS"
        gen_unit_size = "."
        gen_ccs_capture_efficiency = "."
        gen_ccs_energy_load = "."
        gen_storage_efficiency = df.ess_effc[i]*df.ess_effd[i]
        gen_store_to_release_ratio = "."
        gen_storage_energy_to_power_ratio = df.ess_emax[i]/df.pmax[i]
        gen_storage_max_cycles_per_year = 365
        gen_inertia = df.inertia[i]
        push!(rows, (GENERATION_PROJECT, gen_tech, gen_load_zone,gen_connect_cost_per_mw,gen_capacity_limit_mw,gen_full_load_heat_rate,
        gen_variable_om,gen_max_age,gen_min_build_capacity,gen_scheduled_outage_rate,gen_forced_outage_rate,gen_is_variable,
        gen_is_baseload,gen_is_cogen,gen_energy_source,gen_unit_size,gen_ccs_capture_efficiency,gen_ccs_energy_load,gen_storage_efficiency,
        gen_store_to_release_ratio,gen_storage_energy_to_power_ratio,gen_storage_max_cycles_per_year,gen_inertia))
    end
    # Crear DataFrame y guardar como CSV
    output_df = DataFrame(rows, [:GENERATION_PROJECT, :gen_tech, :gen_load_zone, :gen_connect_cost_per_mw, :gen_capacity_limit_mw, :gen_full_load_heat_rate,
    :gen_variable_om, :gen_max_age, :gen_min_build_capacity, :gen_scheduled_outage_rate, :gen_forced_outage_rate, :gen_is_variable, 
    :gen_is_baseload, :gen_is_cogen, :gen_energy_source, :gen_unit_size, :gen_ccs_capture_efficiency, :gen_ccs_energy_load, :gen_storage_efficiency,
    :gen_store_to_release_ratio, :gen_storage_energy_to_power_ratio, :gen_storage_max_cycles_per_year, :gen_inertia])
    CSV.write(output_csv_path, output_df)
end
Input_url = "G:/Mi unidad/Trabajo_Centra/Catedra_AlmacenamientoLD/Switch/SEN/Fuentes/BD-Pelp-2023-2027/Base de Datos PELP 2023-2027 Informe Preliminar_v2/Rumbo a la CN en 2050/Input/Rumbo  a la Carbono Neutralidad_ESS.csv"
Output_url = "C:/Users/Ignac/Trabajo_Centra/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/GEN_inputs_CSV/gen_info/gen_info_ESS.csv"
generar_csv(Input_url, Output_url, catalogo_zonas)


# hydro
function generar_csv(input_url::String, output_csv_path::String, catalogo_zonas::Dict)
    # leer archivo de generadores
    df = CSV.read(input_url, DataFrame)
    filter!(row -> row.connected == 1, df)

    rows = []

    for i in 1:length(df.name)
        GENERATION_PROJECT = df.name[i]
        gen_tech = "HYDRO"
        gen_load_zone = catalogo_zonas[df.busbar[i]]
        gen_connect_cost_per_mw = 0
        gen_capacity_limit_mw = df.pmax[i]
        gen_full_load_heat_rate = "."
        gen_variable_om = df.vomc_avg[i]
        gen_max_age = df.lifetime[i]
        gen_min_build_capacity = 0
        gen_scheduled_outage_rate = df.unavailability[i]
        gen_forced_outage_rate = df.forced_outage_rate[i]
        gen_is_variable = 1
        gen_is_baseload = 0
        gen_is_cogen = 0
        gen_energy_source = "Hidroelectrica"
        gen_unit_size = "."
        gen_ccs_capture_efficiency = "."
        gen_ccs_energy_load = "."
        gen_storage_efficiency = "."
        gen_store_to_release_ratio = "."
        gen_storage_energy_to_power_ratio = "."
        gen_storage_max_cycles_per_year = "."
        gen_inertia = df.inertia[i]                 # duda en esta... la incercia se la inventaron??
        push!(rows, (GENERATION_PROJECT, gen_tech, gen_load_zone,gen_connect_cost_per_mw,gen_capacity_limit_mw,gen_full_load_heat_rate,
        gen_variable_om,gen_max_age,gen_min_build_capacity,gen_scheduled_outage_rate,gen_forced_outage_rate,gen_is_variable,
        gen_is_baseload,gen_is_cogen,gen_energy_source,gen_unit_size,gen_ccs_capture_efficiency,gen_ccs_energy_load,gen_storage_efficiency,
        gen_store_to_release_ratio,gen_storage_energy_to_power_ratio,gen_storage_max_cycles_per_year,gen_inertia))
    end
    # Crear DataFrame y guardar como CSV
    output_df = DataFrame(rows, [:GENERATION_PROJECT, :gen_tech, :gen_load_zone, :gen_connect_cost_per_mw, :gen_capacity_limit_mw, :gen_full_load_heat_rate,
    :gen_variable_om, :gen_max_age, :gen_min_build_capacity, :gen_scheduled_outage_rate, :gen_forced_outage_rate, :gen_is_variable, 
    :gen_is_baseload, :gen_is_cogen, :gen_energy_source, :gen_unit_size, :gen_ccs_capture_efficiency, :gen_ccs_energy_load, :gen_storage_efficiency,
    :gen_store_to_release_ratio, :gen_storage_energy_to_power_ratio, :gen_storage_max_cycles_per_year, :gen_inertia])
    CSV.write(output_csv_path, output_df)
end
Input_url = "G:/Mi unidad/Trabajo_Centra/Catedra_AlmacenamientoLD/Switch/SEN/Fuentes/BD-Pelp-2023-2027/Base de Datos PELP 2023-2027 Informe Preliminar_v2/Rumbo a la CN en 2050/Input/Rumbo  a la Carbono Neutralidad_HydroGenerator.csv"
Output_url = "C:/Users/Ignac/Trabajo_Centra/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/GEN_inputs_CSV/gen_info/gen_info_HYDRO.csv"
generar_csv(Input_url, Output_url, catalogo_zonas)


# pv
function generar_csv(input_url::String, output_csv_path::String, catalogo_zonas::Dict)
    # leer archivo de generadores
    df = CSV.read(input_url, DataFrame)
    filter!(row -> row.connected == 1, df)
    # filter(row -> startswith(row.name, "PV"), df)

    rows = []

    for i in 1:length(df.name)
        GENERATION_PROJECT = df.name[i]
        gen_tech = "PV"
        gen_load_zone = catalogo_zonas[df.busbar[i]]
        gen_connect_cost_per_mw = 0
        gen_capacity_limit_mw = df.pmax[i]
        gen_full_load_heat_rate = "."
        gen_variable_om = df.vomc_avg[i]
        gen_max_age = df.lifetime[i]
        gen_min_build_capacity = 0
        gen_scheduled_outage_rate = df.unavailability[i]
        gen_forced_outage_rate = df.forced_outage_rate[i]
        gen_is_variable = 1
        gen_is_baseload = 0
        gen_is_cogen = 0
        gen_energy_source = "Solar_FV"
        gen_unit_size = "."
        gen_ccs_capture_efficiency = "."
        gen_ccs_energy_load = "."
        gen_storage_efficiency = "."
        gen_store_to_release_ratio = "."
        gen_storage_energy_to_power_ratio = "."
        gen_storage_max_cycles_per_year = "."
        gen_inertia = df.inertia[i]
        push!(rows, (GENERATION_PROJECT, gen_tech, gen_load_zone,gen_connect_cost_per_mw,gen_capacity_limit_mw,gen_full_load_heat_rate,
        gen_variable_om,gen_max_age,gen_min_build_capacity,gen_scheduled_outage_rate,gen_forced_outage_rate,gen_is_variable,
        gen_is_baseload,gen_is_cogen,gen_energy_source,gen_unit_size,gen_ccs_capture_efficiency,gen_ccs_energy_load,gen_storage_efficiency,
        gen_store_to_release_ratio,gen_storage_energy_to_power_ratio,gen_storage_max_cycles_per_year,gen_inertia))
    end
    # Crear DataFrame y guardar como CSV
    output_df = DataFrame(rows, [:GENERATION_PROJECT, :gen_tech, :gen_load_zone, :gen_connect_cost_per_mw, :gen_capacity_limit_mw, :gen_full_load_heat_rate,
    :gen_variable_om, :gen_max_age, :gen_min_build_capacity, :gen_scheduled_outage_rate, :gen_forced_outage_rate, :gen_is_variable, 
    :gen_is_baseload, :gen_is_cogen, :gen_energy_source, :gen_unit_size, :gen_ccs_capture_efficiency, :gen_ccs_energy_load, :gen_storage_efficiency,
    :gen_store_to_release_ratio, :gen_storage_energy_to_power_ratio, :gen_storage_max_cycles_per_year, :gen_inertia])
    CSV.write(output_csv_path, output_df)
end
Input_url = "G:/Mi unidad/Trabajo_Centra/Catedra_AlmacenamientoLD/Switch/SEN/Fuentes/BD-Pelp-2023-2027/Base de Datos PELP 2023-2027 Informe Preliminar_v2/Rumbo a la CN en 2050/Input/Rumbo  a la Carbono Neutralidad_PvGenerator.csv"
Output_url = "C:/Users/Ignac/Trabajo_Centra/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/GEN_inputs_CSV/gen_info/gen_info_PV.csv"
generar_csv(Input_url, Output_url, catalogo_zonas)


# termo
function generar_csv(input_url::String, output_csv_path::String, catalogo_zonas::Dict)
    # leer archivo de generadores
    Fuels_url = "G:/Mi unidad/Trabajo_Centra/Catedra_AlmacenamientoLD/Switch/SEN/Fuentes/BD-Pelp-2023-2027/Base de Datos PELP 2023-2027 Informe Preliminar_v2/Rumbo a la CN en 2050/Input/Rumbo  a la Carbono Neutralidad_Fuel.csv"
    df = CSV.read(input_url, DataFrame)
    filter!(row -> row.connected == 1, df)
    df_fuels = CSV.read(Fuels_url, DataFrame)
    dict_fuels = Dict(row.name => row.fuel_type for row in eachrow(df_fuels))
    dict_fuels2 = Dict("biomass" => "Biomasa",
    "diesel" => "Diesel",
    "coal" => "Carbon",
    "gnl" => "GNL",
    "cogeneration" => "Cogeneracion",
    "geothermal" => "Geotermica",
    "fueloil" => "Biogas")
    # filter(row -> startswith(row.name, "TERMO"), df)

    rows = []

    for i in 1:length(df.name)
        GENERATION_PROJECT = df.name[i]
        gen_tech = "TERMO"
        gen_load_zone = "Gxnode-"*GENERATION_PROJECT*"-"*catalogo_zonas[df.busbar[i]]
        gen_connect_cost_per_mw = 0
        gen_capacity_limit_mw = df.pmax[i]
        gen_full_load_heat_rate = df.heatrate_avg[i]
        gen_variable_om = df.vomc_avg[i]
        gen_max_age = df.lifetime[i]
        gen_min_build_capacity = 0
        gen_scheduled_outage_rate = 0                        # duda acá, porque 0?
        gen_forced_outage_rate = df.forced_outage_rate[i]
        gen_is_variable = 0
        gen_is_baseload = 0
        gen_is_cogen = 0
        gen_energy_source = dict_fuels2[dict_fuels[df.fuel_name[i]]]
        gen_unit_size = "."
        gen_ccs_capture_efficiency = "."
        gen_ccs_energy_load = "."
        gen_storage_efficiency = "."
        gen_store_to_release_ratio = "."
        gen_storage_energy_to_power_ratio = "."
        gen_storage_max_cycles_per_year = "."
        gen_inertia = df.inertia[i]                            # duda acá, tienen otra escala?         
        push!(rows, (GENERATION_PROJECT, gen_tech, gen_load_zone,gen_connect_cost_per_mw,gen_capacity_limit_mw,gen_full_load_heat_rate,
        gen_variable_om,gen_max_age,gen_min_build_capacity,gen_scheduled_outage_rate,gen_forced_outage_rate,gen_is_variable,
        gen_is_baseload,gen_is_cogen,gen_energy_source,gen_unit_size,gen_ccs_capture_efficiency,gen_ccs_energy_load,gen_storage_efficiency,
        gen_store_to_release_ratio,gen_storage_energy_to_power_ratio,gen_storage_max_cycles_per_year,gen_inertia))
    end
    # Crear DataFrame y guardar como CSV
    output_df = DataFrame(rows, [:GENERATION_PROJECT, :gen_tech, :gen_load_zone, :gen_connect_cost_per_mw, :gen_capacity_limit_mw, :gen_full_load_heat_rate,
    :gen_variable_om, :gen_max_age, :gen_min_build_capacity, :gen_scheduled_outage_rate, :gen_forced_outage_rate, :gen_is_variable, 
    :gen_is_baseload, :gen_is_cogen, :gen_energy_source, :gen_unit_size, :gen_ccs_capture_efficiency, :gen_ccs_energy_load, :gen_storage_efficiency,
    :gen_store_to_release_ratio, :gen_storage_energy_to_power_ratio, :gen_storage_max_cycles_per_year, :gen_inertia])
    CSV.write(output_csv_path, output_df)
end
Input_url = "G:/Mi unidad/Trabajo_Centra/Catedra_AlmacenamientoLD/Switch/SEN/Fuentes/BD-Pelp-2023-2027/Base de Datos PELP 2023-2027 Informe Preliminar_v2/Rumbo a la CN en 2050/Input/Rumbo  a la Carbono Neutralidad_ThermalGenerator.csv"
Output_url = "C:/Users/Ignac/Trabajo_Centra/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/GEN_inputs_CSV/gen_info/gen_info_TERMO.csv"
generar_csv(Input_url, Output_url, catalogo_zonas)


# wind
function generar_csv(input_url::String, output_csv_path::String, catalogo_zonas::Dict)
    # leer archivo de generadores
    df = CSV.read(input_url, DataFrame)
    filter!(row -> row.connected == 1, df)
    # filter(row -> startswith(row.name, "Eolica"), df)

    rows = []

    for i in 1:length(df.name)
        GENERATION_PROJECT = df.name[i]
        gen_tech = "WIND"
        gen_load_zone = catalogo_zonas[df.busbar[i]]
        gen_connect_cost_per_mw = 0
        gen_capacity_limit_mw = df.pmax[i]
        gen_full_load_heat_rate = "."
        gen_variable_om = df.vomc_avg[i]
        gen_max_age = df.lifetime[i]
        gen_min_build_capacity = 0
        gen_scheduled_outage_rate = 0                        
        gen_forced_outage_rate = df.forced_outage_rate[i]
        gen_is_variable = 1
        gen_is_baseload = 0
        gen_is_cogen = 0
        gen_energy_source = "Eolica"
        gen_unit_size = "."
        gen_ccs_capture_efficiency = "."
        gen_ccs_energy_load = "."
        gen_storage_efficiency = "."
        gen_store_to_release_ratio = "."
        gen_storage_energy_to_power_ratio = "."
        gen_storage_max_cycles_per_year = "."
        gen_inertia = 0                                  
        push!(rows, (GENERATION_PROJECT, gen_tech, gen_load_zone,gen_connect_cost_per_mw,gen_capacity_limit_mw,gen_full_load_heat_rate,
        gen_variable_om,gen_max_age,gen_min_build_capacity,gen_scheduled_outage_rate,gen_forced_outage_rate,gen_is_variable,
        gen_is_baseload,gen_is_cogen,gen_energy_source,gen_unit_size,gen_ccs_capture_efficiency,gen_ccs_energy_load,gen_storage_efficiency,
        gen_store_to_release_ratio,gen_storage_energy_to_power_ratio,gen_storage_max_cycles_per_year,gen_inertia))
    end
    # Crear DataFrame y guardar como CSV
    output_df = DataFrame(rows, [:GENERATION_PROJECT, :gen_tech, :gen_load_zone, :gen_connect_cost_per_mw, :gen_capacity_limit_mw, :gen_full_load_heat_rate,
    :gen_variable_om, :gen_max_age, :gen_min_build_capacity, :gen_scheduled_outage_rate, :gen_forced_outage_rate, :gen_is_variable, 
    :gen_is_baseload, :gen_is_cogen, :gen_energy_source, :gen_unit_size, :gen_ccs_capture_efficiency, :gen_ccs_energy_load, :gen_storage_efficiency,
    :gen_store_to_release_ratio, :gen_storage_energy_to_power_ratio, :gen_storage_max_cycles_per_year, :gen_inertia])
    CSV.write(output_csv_path, output_df)
end
Input_url = "G:/Mi unidad/Trabajo_Centra/Catedra_AlmacenamientoLD/Switch/SEN/Fuentes/BD-Pelp-2023-2027/Base de Datos PELP 2023-2027 Informe Preliminar_v2/Rumbo a la CN en 2050/Input/Rumbo  a la Carbono Neutralidad_WindGenerator.csv"
Output_url = "C:/Users/Ignac/Trabajo_Centra/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/GEN_inputs_CSV/gen_info/gen_info_EOLICO.csv"
generar_csv(Input_url, Output_url, catalogo_zonas)


# Directorio que contiene los archivos CSV
directorio = "C:/Users/Ignac/Trabajo_Centra/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/GEN_inputs_CSV/gen_info"

# Archivo CSV combinado
archivo_combinado = "gen_info2.csv"

# Obtener una lista de todos los archivos CSV en el directorio
archivos_csv = filter(x -> endswith(x, ".csv"), readdir(directorio, join=true))

# Verificar si hay archivos CSV
if isempty(archivos_csv)
    println("No se encontraron archivos CSV en el directorio.")
    exit()
end

# Abrir el archivo combinado para escritura
open(archivo_combinado, "w") do archivo
    # Procesar el primer archivo CSV
    primer_archivo = archivos_csv[1]
    df_primer = CSV.read(primer_archivo, DataFrame)
    CSV.write(archivo, df_primer; append=false)  # Escribir el primer archivo CSV incluyendo las cabeceras
    
    # Procesar los archivos CSV restantes
    for archivo_csv in archivos_csv[2:end]
        df = CSV.read(archivo_csv, DataFrame)
        CSV.write(archivo, df; append=true, header=false)  # Escribir sin cabeceras
    end
end

println("Los archivos CSV han sido combinados en $archivo_combinado")