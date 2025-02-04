using CSV
using DataFrames
using CairoMakie
using PrettyTables
using FilePathsBase

# Diccionario para asignar nombres reales a las zonas
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

# Definir la carpeta base que contiene las carpetas de los escenarios
base_dir = "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Estudio_oficial/Estudio_Oficial/Nuevos_GNLMarket/"

# Obtener la lista de carpetas de escenarios
scenarios = readdir(base_dir, join=true) |> filter(isdir)

# Definir colores para cada grupo de tecnologías
colors = Dict(
    "Solar_FV" => "#FFD700",  # Amarillo oscuro
    "Eolica" => "#32CD32",  # Verde lima (Lime Green)
    "Termicas" => "#696969",  # Gris oscuro
    "Almacenamiento de larga duración" => "#4169E1",  # Azul real (Royal Blue)
    "Almacenamiento de corta duración" => "#800080",  # Púrpura
    "Otros" => "#8B0000"  # Rojo oscuro (Dark Red)
)

# Diccionario para asignar nombres reales a las zonas
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

# Función para calcular el radio externo basado en la capacidad instalada
function calcular_radio(capacidad, capacidad_min, capacidad_max)
    return 2.5 + (capacidad - capacidad_min) * (5 - 2.5) / (capacidad_max - capacidad_min)
end

# Función para agrupar tecnologías
function agrupar_tecnologias(df)
    # Asegurarse de que todas las columnas necesarias estén presentes
    for col in ["Carbon", "Diesel", "GNL", "Biomasa", "Cogeneracion", "Biogas", "Bomb", "CAES", "TES", "Solar_CSP", "ESS", "Hidroelectrica", "Geotermica"]
        if !(col in names(df))
            df[!, col] = fill(0.0, nrow(df))
        end
    end
    
    df.Termicas = df.Carbon .+ df.Diesel .+ df.GNL .+ df.Biomasa .+ df.Cogeneracion .+ df.Biogas
    df."Almacenamiento de larga duración" = df.Bomb .+ df.CAES .+ df.TES .+ df.Solar_CSP
    df."Almacenamiento de corta duración" = df.ESS
    df.Otros = df.Hidroelectrica .+ df.Geotermica
    select!(df, Not([:Carbon, :Diesel, :GNL, :Biomasa, :Cogeneracion, :Biogas, :Bomb, :CAES, :TES, :Solar_CSP, :ESS, :Hidroelectrica, :Geotermica]))
    return df
end

# Iterar sobre cada carpeta de escenario y procesar los archivos
for scenario in scenarios
    println("Processing scenario: $scenario")
    
    # Verificar si el directorio del escenario está vacío
    if isempty(readdir(scenario*"/outputs"))
        println("Skipping empty scenario: $scenario")
        continue
    end
    
    # Leer el archivo load_zones.csv
    load_zones_file = joinpath(scenario, "inputs", "load_zones.csv")
    load_zones_df = CSV.read(load_zones_file, DataFrame)
    load_zones = load_zones_df.LOAD_ZONE[1:29]  # Considerar solo hasta la fila 29
    
    # Leer y filtrar el archivo dispatch_gen_annual_summary.csv por región y calcular capacidades totales por periodo
    dispatch_file = joinpath(scenario, "outputs", "dispatch_gen_annual_summary.csv")
    dispatch_df = CSV.read(dispatch_file, DataFrame)
    
    capacidades_totales = DataFrame(period=unique(dispatch_df.period))
    
    for region in load_zones
        if occursin("H2", region)
            nothing
        else
            region_df = filter(row -> occursin(region, row.gen_load_zone), dispatch_df)
            pivot_df = unstack(region_df, :period, :gen_energy_source, :GenCapacity_MW, combine=sum)
            for col in names(pivot_df)[2:end]
                replace!(pivot_df[!, col], missing => 0)
            end
            pivot_df = agrupar_tecnologias(pivot_df)
        end
        total_capacities = [sum(row[Not(:period)]) for row in eachrow(pivot_df)]
        
        # Asegurarse de que las longitudes coincidan
        if length(total_capacities) < nrow(capacidades_totales)
            total_capacities = vcat(total_capacities, fill(0.0, nrow(capacidades_totales) - length(total_capacities)))
        elseif length(total_capacities) > nrow(capacidades_totales)
            capacidades_totales = vcat(capacidades_totales, DataFrame(period=fill(missing, length(total_capacities) - nrow(capacidades_totales))))
        end
        
        capacidades_totales[!, region] = total_capacities
    end
    
    for period in unique(dispatch_df.period)
        capacidades_periodo = capacidades_totales[capacidades_totales.period .== period, Not(:period)]
        capacidad_max = maximum(vcat(eachcol(capacidades_periodo)...))
        capacidad_min = minimum(vcat(eachcol(capacidades_periodo)...))
        
        for region in load_zones
            println("Processing region: $region")
            region_nom = catalogo_zonas1[region]
            
            region_df = filter(row -> occursin(region, row.gen_load_zone), dispatch_df)
            pivot_df = unstack(region_df, :period, :gen_energy_source, :GenCapacity_MW, combine=sum)
            for col in names(pivot_df)[2:end]
                replace!(pivot_df[!, col], missing => 0)
            end
            pivot_df = agrupar_tecnologias(pivot_df)
            # Manejar las columnas 'Solar-CSP' y 'Solar_CSP'
            if "Solar-CSP" in names(pivot_df)
                select!(pivot_df, Not(:"Solar-CSP"))
            end
            period_df = filter(row -> row.period == period, pivot_df)
            data = period_df[:, Not(:period)]
            
            fig = Figure(resolution=(800, 800), backgroundcolor=:transparent)  # Aumentar la resolución para mantener la escala
            ax = Axis(fig[1, 1], title="Año $period - $region_nom", backgroundcolor=:transparent)
            
            if occursin("H2", region)
                nothing
            else
                pie_data = collect(values(data[1, :]))
                pie_labels = collect(names(data))
                pie_colors = [colors[label] for label in pie_labels]
                radio_externo = calcular_radio(sum(pie_data), capacidad_min, capacidad_max)
                pie!(ax, pie_data, inner_radius=1, radius=radio_externo, color=pie_colors)
                xlims!(ax, -5, 5)  # Establecer los límites del eje x
                ylims!(ax, -5, 5)  # Establecer los límites del eje y
            end
            
            hidedecorations!(ax)
            hidespines!(ax)
            # Legend(fig[1,2], [PolyElement(color=c) for c in pie_colors], pie_labels, framevisible=false)
            
            output_img_file = joinpath(scenario, "Regions/"*replace(region, r"\s+" => "")*"_PieChart2_$period.png")
            save(output_img_file, fig)
            CSV.write(joinpath(scenario, "Regions/"*replace(catalogo_zonas1[region], r"\s+" => "")*"_Capacity_$period.csv"), period_df)
            
            # display(fig)
        end
    end
end

println("Processing complete.")