using CSV
using DataFrames
using Dates
using Plots
using Printf

# df = CSV.read("G:/Mi unidad/Trabajo_Centra/Catedra_AlmacenamientoLD/Switch/SEN/Fuentes/BD-Pelp-2023-2027/Base de Datos PELP 2023-2027 Informe Preliminar_v2/Rumbo a la CN en 2050/Input/Rumbo  a la Carbono Neutralidad_demand/demand.csv", DataFrame)
df = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/demanda.csv", DataFrame)
escenarios = ["transicion_acelerada", "rumbo_CN", "recuperacion_lenta"]
df_demanda_total = DataFrame(year=Int[], demanda_total=Float64[], escenario=String[])

# Función para calcular la demanda total por año para un escenario
function calcular_demanda_por_escenario(escenario, df)
    df_filtrado = filter(row -> row.scenario == escenario, df)
    df_filtrado[!, :time] .= DateTime.(df_filtrado[!, :time], "yyyy-mm-dd-HH:MM")
    
    nodos = names(df_filtrado)[3:end]
    
    # Para cada año, calcular la demanda total
    for año in unique(year.(df_filtrado[!, :time]))
        df_año = filter(row -> year(row.time) == año, df_filtrado)
        demanda_total_sistema = 0.0

        for nodo in nodos
            suma_demandas_nodo = sum(df_año[:, nodo])
            demanda_promedio_nodo = suma_demandas_nodo / 12
            demanda_total_sistema += demanda_promedio_nodo
        end
        
        push!(df_demanda_total, (año, demanda_total_sistema*365/1000000, escenario))
    end
end

for escenario in escenarios
    calcular_demanda_por_escenario(escenario, df)
end

println("Demanda total del sistema por año (promedio de 12 días) para cada escenario:")
println(df_demanda_total)

demanda_total_formateada = [parse.(Int, @sprintf("%d", d)) for d in df_demanda_total.demanda_total]

p = plot()

plot!(p, df_demanda_total.year[df_demanda_total.escenario .== "transicion_acelerada"], demanda_total_formateada[df_demanda_total.escenario .== "transicion_acelerada"], 
      label="Transición Acelerada", linewidth=2, color=:blue, markershape=:circle)

plot!(p, df_demanda_total.year[df_demanda_total.escenario .== "rumbo_CN"], demanda_total_formateada[df_demanda_total.escenario .== "rumbo_CN"], 
      label="Rumbo CN", linewidth=2, color=:green, markershape=:circle)

plot!(p, df_demanda_total.year[df_demanda_total.escenario .== "recuperacion_lenta"], demanda_total_formateada[df_demanda_total.escenario .== "recuperacion_lenta"], 
      label="Recuperación Lenta", linewidth=2, color=:red, markershape=:circle)

xlabel!("Año")
ylabel!("Demanda Total del Sistema TWh")
title!("Demanda del SEN por escenario para dia tipico anual", titlefontsize=12)

display(p)