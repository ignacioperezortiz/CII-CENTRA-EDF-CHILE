using CSV
using DataFrames
using CairoMakie
using PrettyTables
using FilePathsBase

# Definir la carpeta base que contiene las carpetas de los escenarios
base_dir = "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/Estudio_Oficial/Sensibilidades/OK/Corridos/CasoBase"

# Obtener la lista de carpetas de escenarios
scenarios = readdir(base_dir, join=true) |> filter(isdir)

# Definir colores para cada tecnología
colors = Dict(
    "Solar_FV" => "#FFD700",  # Amarillo oscuro
    "Hidroelectrica" => "#4682B4",  # Azul acero (Steel Blue)
    "Eolica" => "#32CD32",  # Verde lima (Lime Green)
    "Carbon" => "#696969",  # Gris oscuro
    "Diesel" => "#A9A9A9",  # Gris claro
    "GNL" => "#FF8C00",  # Naranja oscuro
    "Biomasa" => "#8B4513",  # Marrón silla (Saddle Brown)
    "BESS" => "#800080",  # Púrpura
    "Cogeneracion" => "#FF69B4",  # Rosa fuerte (Hot Pink)
    "Solar_CSP" => "#FFD700",  # Amarillo oscuro
    "Geotermica" => "#DC143C",  # Carmesí (Crimson)
    "Biogas" => "#00CED1",  # Turquesa oscuro (Dark Turquoise)
    "PSP" => "#4169E1",  # Azul real (Royal Blue)
    "CAES" => "#006400",  # Verde oscuro (Dark Green)
    "TES" => "#000080"  # Azul marino (Navy)
)

# Función para calcular el radio externo basado en la capacidad instalada
function calcular_radio(capacidad, capacidad_min, capacidad_max)
    return 2.5 + (capacidad - capacidad_min) * (5 - 2.5) / (capacidad_max - capacidad_min)
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
            
            region_df = filter(row -> occursin(region, row.gen_load_zone), dispatch_df)
            pivot_df = unstack(region_df, :period, :gen_energy_source, :GenCapacity_MW, combine=sum)
            for col in names(pivot_df)[2:end]
                replace!(pivot_df[!, col], missing => 0)
            end
            
            # Renombrar la columna 'ESS' a 'BESS'
            if "ESS" in names(pivot_df)
                rename!(pivot_df, "ESS" => "BESS")
            end

            # Renombrar la columna 'Bomb' a 'PSP'
            if "Bomb" in names(pivot_df)
                rename!(pivot_df, "Bomb" => "PSP")
            end

            # Manejar las columnas 'Solar-CSP' y 'Solar_CSP'
            if "Solar-CSP" in names(pivot_df) && "Solar_CSP" in names(pivot_df)
                pivot_df.Solar_CSP .+= pivot_df."Solar-CSP"
                select!(pivot_df, Not(:"Solar-CSP"))
            elseif "Solar-CSP" in names(pivot_df) && !("Solar_CSP" in names(pivot_df))
                rename!(pivot_df, "Solar-CSP" => "Solar_CSP")
            end
            
            period_df = filter(row -> row.period == period, pivot_df)
            data = period_df[:, Not(:period)]
            
            fig = Figure(resolution=(800, 800))  # Aumentar la resolución para mantener la escala
            ax = Axis(fig[1, 1], title="Capacidad instalada por tecnología - Periodo $period - Región $region")
            
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
            Legend(fig[1,2], [PolyElement(color=c) for c in pie_colors], pie_labels, framevisible=false)
            
            output_img_file = joinpath(scenario, "Regions/"*replace(region, r"\s+" => "")*"_PieChart_$period.png")
            save(output_img_file, fig)
            
            # display(fig)
        end
    end
end

println("Processing complete.")