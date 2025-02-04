# script para crear el archivo gen_build_costs.jl en base a la pelp
# sript para crear el archivo gen_build_predetermines.csv en base a la Pelp

# primera sección de script para generar un csv con todos los costos "0" de los generadores predeterminados.
using CSV
using DataFrames
using Dates
using Statistics
using Random
using Printf


function generar_csv(GEN_csv_path::String, output_csv_path::String)
    # leer archivo de generadores
    GEN_df = CSV.read(GEN_csv_path, DataFrame)
    # println(GEN_df.connected)
    filter!(row -> row.connected == 1, GEN_df) 
    filter!(row -> row.candidate == 0, GEN_df) 

    rows = []

    for i in 1:length(GEN_df.name)
        gen_name = GEN_df.name[i]
        if gen_name != "Ampliacion PMGD El Boco"
            gen_build_year = GEN_df.start_time[i][1:4]
            gen_overnight_cost = 0
            gen_storage_energy_overnight_cost = "."
            gen_fixed_om = 0
            push!(rows, (gen_name, gen_build_year, gen_overnight_cost, gen_storage_energy_overnight_cost, gen_fixed_om))
        end
    end
    # Crear DataFrame y guardar como CSV
    output_df = DataFrame(rows, [:GENERATION_PROJECT, :build_year, :gen_overnight_cost, :gen_storage_energy_overnight_cost, :gen_fixed_om])
    # println(output_df)
    CSV.write(output_csv_path, output_df)
end

GEN_filename = "G:/Mi unidad/Trabajo_Centra/Catedra_AlmacenamientoLD/Switch/SEN/Fuentes/BD-Pelp-2023-2027/Base de Datos PELP 2023-2027 Informe Preliminar_v2/Rumbo a la CN en 2050/Input/Rumbo  a la Carbono Neutralidad_Generator.csv"
generar_csv(GEN_filename, "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Rumbo_CN/GEN_inputs_CSV/gen_build_costs/Alto/predeterminated.csv")
generar_csv(GEN_filename, "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Rumbo_CN/GEN_inputs_CSV/gen_build_costs/Medio/predeterminated.csv")
generar_csv(GEN_filename, "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Rumbo_CN/GEN_inputs_CSV/gen_build_costs/Bajo/predeterminated.csv")



scenario = ["Bajo","Medio","Alto"]

for i in scenario
    # segunda parte del script para generadores que están disponibles para conectar a futuro.
    function generar_csv(GEN_csv_pathgen_inv_cost_input::String, output_csv_path::String)
        oymcost_url = "G:/Mi unidad/Trabajo_Centra/Catedra_AlmacenamientoLD/Switch/SEN/Fuentes/BD-Pelp-2023-2027/Base de Datos PELP 2023-2027 Informe Preliminar_v2/Rumbo a la CN en 2050/Input/Rumbo  a la Carbono Neutralidad_Generator.csv"
        df_oymcost = CSV.read(oymcost_url, DataFrame)
        df_build_costs = CSV.read(GEN_csv_pathgen_inv_cost_input, DataFrame)
        df = filter!(row -> row.scenario == "$i", df_build_costs)           ### cambiar filtro
        df_col_names = names(df_build_costs)
        df_col_num = length(df_col_names)
        rows = []

        # Definir años y número de días representativos
        años = [2024, 2026, 2029, 2030, 2031, 2033, 2040, 2050]
        filas_años = []
        # Listado de cadenas a buscar
        # busquedas = ["CAES_", "Bomb_", "ESS_"]
        busquedas = ["ESS_"]
        busquedas2 = ["CAES_", "Bomb_","CSP_"]

        for z in años
            push!(filas_años, z-2019)
        end
        for m in filas_años
            for j in 3:df_col_num
                GENERATION_PROJECT = df_col_names[j]
                if any(occursin.(busquedas2, GENERATION_PROJECT))
                    nothing
                # condición occursin "Eolica"
                    # condición occoursin "_araucania_" o "_LosRios_" o "_LosLagos_" 
                        # script analogo a lineas 78 a 90. pero multiplicar gen_overnight_cost X 1.15
                    # end
                # end
                elseif GENERATION_PROJECT != "Ampliacion PMGD El Boco"
                    build_year = df.time[m][1:4]
                    project_name_symbol = Symbol(GENERATION_PROJECT)
                    gen_overnight_cost = @sprintf("%.0f",df[!, project_name_symbol][m]*1000)
                    # Verificar si `nombre` contiene alguna de las cadenas en `busquedas`
                    if any(occursin.(busquedas, GENERATION_PROJECT))
                        gen_storage_energy_overnight_cost = 0
                    else
                        gen_storage_energy_overnight_cost = "."
                    end
                    index = findfirst(row -> row.name == GENERATION_PROJECT, eachrow(df_oymcost))
                    gen_fixed_om = @sprintf("%.0f",df_oymcost[index, :fom_cost]*1000)
                    # fom_cost_value = df_oymcost.Fom_cost[index]
                    push!(rows, (GENERATION_PROJECT, build_year, gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                end
            end
        end
        output_df = DataFrame(rows, [:GENERATION_PROJECT, :build_year, :gen_overnight_cost, :gen_storage_energy_overnight_cost, :gen_fixed_om])
        CSV.write(output_csv_path, output_df)
    end
    GEN_filename = "G:/Mi unidad/Trabajo_Centra/Catedra_AlmacenamientoLD/Switch/SEN/Fuentes/BD-Pelp-2023-2027/Base de Datos PELP 2023-2027 Informe Preliminar_v2/Rumbo a la CN en 2050/Input/Rumbo  a la Carbono Neutralidad_gen_inv_cost/gen_inv_cost.csv"
    generar_csv(GEN_filename, "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Rumbo_CN/GEN_inputs_CSV/gen_build_costs/$i/not_predeterminated.csv")




    # CAPEX LDES
    # Define los años de interés
    years_of_interest = [2024, 2026, 2029, 2030, 2031, 2033, 2040, 2050]

    tec = ["CAES", "TES", "CSP_TES","BOMB"]

    CSP_TES = ["CSP_TES_13", "CSP_TES_17"]
    TES = ["TES_6", "TES_10"]
    CAES = ["CAES_6","CAES_10","CAES_14"]
    BOMB = ["BOMB_6","BOMB_10","BOMB_14"]

    Nombre_gen_tec = Dict(
        "CAES" => "CAES_Pichirropulli500_4h",
        "TES" => "CSP_Coquimbo_1910_13h",
        "CSP_TES" => "CSP_Coquimbo_1910_13h")

    CAPEX_gen_tec_Alto = Dict(
        "CAES_6" => 1178737,
        "CAES_10" => 1205183,
        "CAES_14" => 1230817,
        "TES_6" => 2249649,
        "TES_10" => 2573878,
        "TES_14" => 2835882,
        "CSP_TES_13" => 5381540,
        "CSP_TES_17" => 6208840,
        "BOMB300_6" => 1630000,
        "BOMB300_10" => 1828000,
        "BOMB300_14" => 2026000,
        "BOMB450_6" => 1592000,
        "BOMB450_10" => 1790000,
        "BOMB450_14" => 1988000,
        "BOMB600_6" => 1577000,
        "BOMB600_10" => 1776000,
        "BOMB600_14" => 1974000)
    CAPEX_gen_tec_Medio = Dict(
        "CAES_6" => 1178737*0.95,
        "CAES_10" => 1205183*0.95,
        "CAES_14" => 1230817*0.95,
        "TES_6" => 2249649,
        "TES_10" => 2573878,
        "TES_14" => 2835882,
        "CSP_TES_13" => 5381540,
        "CSP_TES_17" => 6208840,
        "BOMB300_6" => 1630000*0.94,
        "BOMB300_10" => 1828000*0.94,
        "BOMB300_14" => 2026000*0.94,
        "BOMB450_6" => 1592000*0.94,
        "BOMB450_10" => 1790000*0.94,
        "BOMB450_14" => 1988000*0.94,
        "BOMB600_6" => 1577000*0.94,
        "BOMB600_10" => 1776000*0.94,
        "BOMB600_14" => 1974000*0.94)        
    CAPEX_gen_tec_Bajo = Dict(
        "CAES_6" => 1178737*0.9,
        "CAES_10" => 1205183*0.9,
        "CAES_14" => 1230817*0.9,
        "TES_6" => 2249649,
        "TES_10" => 2573878,
        "TES_14" => 2835882,
        "CSP_TES_13" => 5381540,
        "CSP_TES_17" => 6208840,
        "BOMB300_6" => 1630000*0.88,
        "BOMB300_10" => 1828000*0.88,
        "BOMB300_14" => 2026000*0.88,
        "BOMB450_6" => 1592000*0.88,
        "BOMB450_10" => 1790000*0.88,
        "BOMB450_14" => 1988000*0.88,
        "BOMB600_6" => 1577000*0.88,
        "BOMB600_10" => 1776000*0.88,
        "BOMB600_14" => 1974000*0.88)    

    # Lee el archivo CSV (cambia 'tu_archivo.csv' por el nombre de tu archivo)
    df = CSV.File("G:/Mi unidad/Trabajo_Centra/Catedra_AlmacenamientoLD/Switch/SEN/Fuentes/BD-Pelp-2023-2027/Base de Datos PELP 2023-2027 Informe Preliminar_v2/Rumbo a la CN en 2050/Input/Rumbo  a la Carbono Neutralidad_gen_inv_cost/gen_inv_cost.csv") |> DataFrame
    rows = []
    filtered_df = 0
    for l in tec
        if l != "BOMB"
            nombre_gen = Nombre_gen_tec[l] 
            df.time = string.(df.time)
            # Filtra el DataFrame para seleccionar solo los escenarios "Bajo"
            filtered_df = df[df.scenario .== "$i", :]

            # Convierte los años a strings para realizar la comparación
            years_of_interest_str = string.(years_of_interest)

            # Crea un vector para almacenar los valores de "CAES_Pichirropulli500_4h"
            values_vector = []

            # Llena el vector con los valores de la columna "CAES_Pichirropulli500_4h" basados en el tiempo
            for year_str in years_of_interest_str
                # Verifica si los primeros 4 caracteres de "Time" son equivalentes al año
                filtered_df2 = filter(row -> occursin("$year_str", string(row.time)), filtered_df)
                # println(filtered_df2.time)
                push!(values_vector, filtered_df2[!, Symbol(nombre_gen)]...)
            end

            # Imprimir el vector resultante
            println("Valores de $nombre_gen para los años dados: ", values_vector)
            vector_proyeccion = []
            for z in 1:length(values_vector)
                push!(vector_proyeccion, values_vector[z]/values_vector[1])
            end
            println(vector_proyeccion)
        else
            vector_proyeccion = [1,1,1,1,1,1,1,1]
        end

        #ingresar acá valor de CAPEX de la tecnología al 2024
        if i == "Alto"
            if l == "CSP_TES"
                df_names = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Inputs_LDES_Preliminar4/inputs/gen_info.csv", DataFrame)
                df_names_filtred = filter(row -> occursin("CSP-TES", string(row.gen_tech)), df_names)
                for x in 1:length(df_names_filtred.gen_tech)
                    GENERATION_PROJECT = df_names_filtred.GENERATION_PROJECT[x]
                    if occursin("13", string(GENERATION_PROJECT))
                        gen_storage_energy_overnight_cost = "."
                        for j in 1:length(years_of_interest)
                            gen_overnight_cost1 = CAPEX_gen_tec_Alto["CSP_TES_13"]*vector_proyeccion[j]
                            gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Alto["CSP_TES_13"]*vector_proyeccion[j])
                            gen_fixed_om = @sprintf("%.0f",gen_overnight_cost1*0.01)
                            push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                        end
                    elseif occursin("17", string(GENERATION_PROJECT))
                        gen_storage_energy_overnight_cost = "."
                        for j in 1:length(years_of_interest)
                            gen_overnight_cost1 = CAPEX_gen_tec_Alto["CSP_TES_17"]*vector_proyeccion[j]
                            gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Alto["CSP_TES_17"]*vector_proyeccion[j])
                            gen_fixed_om = @sprintf("%.0f",gen_overnight_cost1*0.01)
                            push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                        end
                    end
                end
            elseif l == "TES"
                df_names = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Inputs_LDES_Preliminar4/inputs/gen_info.csv", DataFrame)
                df_names_filtred = filter(row -> occursin("TES", string(row.gen_tech)), df_names)
                for x in 1:length(df_names_filtred.gen_tech)
                    GENERATION_PROJECT = df_names_filtred.GENERATION_PROJECT[x]
                    if occursin("_6h", string(GENERATION_PROJECT))
                        gen_storage_energy_overnight_cost = "."
                        for j in 1:length(years_of_interest)
                            gen_overnight_cost1 = CAPEX_gen_tec_Alto["TES_6"]*vector_proyeccion[j]
                            gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Alto["TES_6"]*vector_proyeccion[j])
                            gen_fixed_om = @sprintf("%.0f",gen_overnight_cost1*0.01)
                            push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                        end
                    elseif occursin("_10h", string(GENERATION_PROJECT))
                        gen_storage_energy_overnight_cost = "."
                        for j in 1:length(years_of_interest)
                            gen_overnight_cost1 = CAPEX_gen_tec_Alto["TES_10"]*vector_proyeccion[j]
                            gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Alto["TES_10"]*vector_proyeccion[j])
                            gen_fixed_om = @sprintf("%.0f",gen_overnight_cost1*0.01)
                            push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                        end
                    elseif occursin("_14h", string(GENERATION_PROJECT))
                        gen_storage_energy_overnight_cost = "."
                        for j in 1:length(years_of_interest)
                            gen_overnight_cost1 = CAPEX_gen_tec_Alto["TES_14"]*vector_proyeccion[j]
                            gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Alto["TES_14"]*vector_proyeccion[j])
                            gen_fixed_om = @sprintf("%.0f",gen_overnight_cost1*0.01)
                            push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                        end
                    end
                end
            elseif l == "CAES"
                df_names = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Inputs_LDES_Preliminar4/inputs/gen_info.csv", DataFrame)
                df_names_filtred = filter(row -> occursin("CAES", string(row.gen_tech)), df_names)
                for x in 1:length(df_names_filtred.gen_tech)
                    GENERATION_PROJECT = df_names_filtred.GENERATION_PROJECT[x]
                    if occursin("_6h", string(GENERATION_PROJECT))
                        gen_storage_energy_overnight_cost = "0"
                        for j in 1:length(years_of_interest)
                            gen_overnight_cost1 = CAPEX_gen_tec_Alto["CAES_6"]*vector_proyeccion[j]
                            gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Alto["CAES_6"]*vector_proyeccion[j])
                            gen_fixed_om = @sprintf("%.0f",gen_overnight_cost1*0.01)
                            push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                        end
                    elseif occursin("_10h", string(GENERATION_PROJECT))
                        gen_storage_energy_overnight_cost = "0"
                        for j in 1:length(years_of_interest)
                            gen_overnight_cost1 = CAPEX_gen_tec_Alto["CAES_10"]*vector_proyeccion[j]
                            gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Alto["CAES_10"]*vector_proyeccion[j])
                            gen_fixed_om = @sprintf("%.0f",gen_overnight_cost1*0.01)
                            push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                        end
                    elseif occursin("_14h", string(GENERATION_PROJECT))
                        gen_storage_energy_overnight_cost = "0"
                        for j in 1:length(years_of_interest)
                            gen_overnight_cost1 = CAPEX_gen_tec_Alto["CAES_14"]*vector_proyeccion[j]
                            gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Alto["CAES_14"]*vector_proyeccion[j])
                            gen_fixed_om = @sprintf("%.0f",gen_overnight_cost1*0.01)
                            push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                        end
                    end
                end
            elseif l == "BOMB"
                df_names = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Inputs_LDES_Preliminar4/inputs/gen_info.csv", DataFrame)
                df_names_filtred = filter(row -> occursin("Bomb", string(row.gen_tech)), df_names)
                for x in 1:length(df_names_filtred.gen_tech)
                    GENERATION_PROJECT = df_names_filtred.GENERATION_PROJECT[x]
                    if occursin("_6h", string(GENERATION_PROJECT))
                        gen_storage_energy_overnight_cost = "0"
                        if df_names_filtred.gen_capacity_limit_mw[x] <= 300
                            for j in 1:length(years_of_interest)
                                gen_overnight_cost1 = CAPEX_gen_tec_Alto["BOMB300_6"]*vector_proyeccion[j]
                                gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Alto["BOMB300_6"]*vector_proyeccion[j])
                                gen_fixed_om = @sprintf("%.0f",3480)
                                push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                            end
                        elseif 301<= df_names_filtred.gen_capacity_limit_mw[x] < 600
                            for j in 1:length(years_of_interest)
                                gen_overnight_cost1 = CAPEX_gen_tec_Alto["BOMB450_6"]*vector_proyeccion[j]
                                gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Alto["BOMB450_6"]*vector_proyeccion[j])
                                gen_fixed_om = @sprintf("%.0f",3480)
                                push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                            end
                        elseif df_names_filtred.gen_capacity_limit_mw[x] >= 600
                            for j in 1:length(years_of_interest)
                                gen_overnight_cost1 = CAPEX_gen_tec_Alto["BOMB600_6"]*vector_proyeccion[j]
                                gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Alto["BOMB600_6"]*vector_proyeccion[j])
                                gen_fixed_om = @sprintf("%.0f",3480)
                                push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                            end
                        end
                    elseif occursin("_10h", string(GENERATION_PROJECT))
                        gen_storage_energy_overnight_cost = "0"
                        if df_names_filtred.gen_capacity_limit_mw[x] <= 300
                            for j in 1:length(years_of_interest)
                                gen_overnight_cost1 = CAPEX_gen_tec_Alto["BOMB300_10"]*vector_proyeccion[j]
                                gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Alto["BOMB300_10"]*vector_proyeccion[j])
                                gen_fixed_om = @sprintf("%.0f",5800)
                                push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                            end
                        elseif 301<= df_names_filtred.gen_capacity_limit_mw[x] < 600
                            for j in 1:length(years_of_interest)
                                gen_overnight_cost1 = CAPEX_gen_tec_Alto["BOMB450_10"]*vector_proyeccion[j]
                                gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Alto["BOMB450_10"]*vector_proyeccion[j])
                                gen_fixed_om = @sprintf("%.0f",5800)
                                push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                            end
                        elseif df_names_filtred.gen_capacity_limit_mw[x] >= 600
                            for j in 1:length(years_of_interest)
                                gen_overnight_cost1 = CAPEX_gen_tec_Alto["BOMB600_10"]*vector_proyeccion[j]
                                gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Alto["BOMB600_10"]*vector_proyeccion[j])
                                gen_fixed_om = @sprintf("%.0f",5800)
                                push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                            end
                        end
                    elseif occursin("_14h", string(GENERATION_PROJECT))
                        gen_storage_energy_overnight_cost = "0"
                        if df_names_filtred.gen_capacity_limit_mw[x] <= 300
                            for j in 1:length(years_of_interest)
                                gen_overnight_cost1 = CAPEX_gen_tec_Alto["BOMB300_14"]*vector_proyeccion[j]
                                gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Alto["BOMB300_14"]*vector_proyeccion[j])
                                gen_fixed_om = @sprintf("%.0f",8120)
                                push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                            end
                        elseif 301<= df_names_filtred.gen_capacity_limit_mw[x] < 600
                            for j in 1:length(years_of_interest)
                                gen_overnight_cost1 = CAPEX_gen_tec_Alto["BOMB450_14"]*vector_proyeccion[j]
                                gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Alto["BOMB450_14"]*vector_proyeccion[j])
                                gen_fixed_om = @sprintf("%.0f",8120)
                                push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                            end
                        elseif df_names_filtred.gen_capacity_limit_mw[x] >= 600
                            for j in 1:length(years_of_interest)
                                gen_overnight_cost1 = CAPEX_gen_tec_Alto["BOMB600_14"]*vector_proyeccion[j]
                                gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Alto["BOMB600_14"]*vector_proyeccion[j])
                                gen_fixed_om = @sprintf("%.0f",8120)
                                push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                            end
                        end
                    end
                end
            end
        elseif i == "Medio"
            if l == "CSP_TES"
                df_names = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Inputs_LDES_Preliminar4/inputs/gen_info.csv", DataFrame)
                df_names_filtred = filter(row -> occursin("CSP-TES", string(row.gen_tech)), df_names)
                for x in 1:length(df_names_filtred.gen_tech)
                    GENERATION_PROJECT = df_names_filtred.GENERATION_PROJECT[x]
                    if occursin("13", string(GENERATION_PROJECT))
                        gen_storage_energy_overnight_cost = "."
                        for j in 1:length(years_of_interest)
                            gen_overnight_cost1 = CAPEX_gen_tec_Medio["CSP_TES_13"]*vector_proyeccion[j]
                            gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Medio["CSP_TES_13"]*vector_proyeccion[j])
                            gen_fixed_om = @sprintf("%.0f",gen_overnight_cost1*0.01)
                            push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                        end
                    elseif occursin("17", string(GENERATION_PROJECT))
                        gen_storage_energy_overnight_cost = "."
                        for j in 1:length(years_of_interest)
                            gen_overnight_cost1 = CAPEX_gen_tec_Medio["CSP_TES_17"]*vector_proyeccion[j]
                            gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Medio["CSP_TES_17"]*vector_proyeccion[j])
                            gen_fixed_om = @sprintf("%.0f",gen_overnight_cost1*0.01)
                            push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                        end
                    end
                end
            elseif l == "TES"
                df_names = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Inputs_LDES_Preliminar4/inputs/gen_info.csv", DataFrame)
                df_names_filtred = filter(row -> occursin("TES", string(row.gen_tech)), df_names)
                for x in 1:length(df_names_filtred.gen_tech)
                    GENERATION_PROJECT = df_names_filtred.GENERATION_PROJECT[x]
                    if occursin("_6h", string(GENERATION_PROJECT))
                        gen_storage_energy_overnight_cost = "."
                        for j in 1:length(years_of_interest)
                            gen_overnight_cost1 = CAPEX_gen_tec_Medio["TES_6"]*vector_proyeccion[j]
                            gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Medio["TES_6"]*vector_proyeccion[j])
                            gen_fixed_om = @sprintf("%.0f",gen_overnight_cost1*0.01)
                            push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                        end
                    elseif occursin("_10h", string(GENERATION_PROJECT))
                        gen_storage_energy_overnight_cost = "."
                        for j in 1:length(years_of_interest)
                            gen_overnight_cost1 = CAPEX_gen_tec_Medio["TES_10"]*vector_proyeccion[j]
                            gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Medio["TES_10"]*vector_proyeccion[j])
                            gen_fixed_om = @sprintf("%.0f",gen_overnight_cost1*0.01)
                            push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                        end
                    elseif occursin("_14h", string(GENERATION_PROJECT))
                        gen_storage_energy_overnight_cost = "."
                        for j in 1:length(years_of_interest)
                            gen_overnight_cost1 = CAPEX_gen_tec_Medio["TES_14"]*vector_proyeccion[j]
                            gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Medio["TES_14"]*vector_proyeccion[j])
                            gen_fixed_om = @sprintf("%.0f",gen_overnight_cost1*0.01)
                            push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                        end
                    end
                end
            elseif l == "CAES"
                df_names = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Inputs_LDES_Preliminar4/inputs/gen_info.csv", DataFrame)
                df_names_filtred = filter(row -> occursin("CAES", string(row.gen_tech)), df_names)
                for x in 1:length(df_names_filtred.gen_tech)
                    GENERATION_PROJECT = df_names_filtred.GENERATION_PROJECT[x]
                    if occursin("_6h", string(GENERATION_PROJECT))
                        gen_storage_energy_overnight_cost = "0"
                        for j in 1:length(years_of_interest)
                            gen_overnight_cost1 = CAPEX_gen_tec_Medio["CAES_6"]*vector_proyeccion[j]
                            gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Medio["CAES_6"]*vector_proyeccion[j])
                            gen_fixed_om = @sprintf("%.0f",gen_overnight_cost1*0.01)
                            push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                        end
                    elseif occursin("_10h", string(GENERATION_PROJECT))
                        gen_storage_energy_overnight_cost = "0"
                        for j in 1:length(years_of_interest)
                            gen_overnight_cost1 = CAPEX_gen_tec_Medio["CAES_10"]*vector_proyeccion[j]
                            gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Medio["CAES_10"]*vector_proyeccion[j])
                            gen_fixed_om = @sprintf("%.0f",gen_overnight_cost1*0.01)
                            push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                        end
                    elseif occursin("_14h", string(GENERATION_PROJECT))
                        gen_storage_energy_overnight_cost = "0"
                        for j in 1:length(years_of_interest)
                            gen_overnight_cost1 = CAPEX_gen_tec_Medio["CAES_14"]*vector_proyeccion[j]
                            gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Medio["CAES_14"]*vector_proyeccion[j])
                            gen_fixed_om = @sprintf("%.0f",gen_overnight_cost1*0.01)
                            push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                        end
                    end
                end
            elseif l == "BOMB"
                df_names = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Inputs_LDES_Preliminar4/inputs/gen_info.csv", DataFrame)
                df_names_filtred = filter(row -> occursin("Bomb", string(row.gen_tech)), df_names)
                for x in 1:length(df_names_filtred.gen_tech)
                    GENERATION_PROJECT = df_names_filtred.GENERATION_PROJECT[x]
                    if occursin("_6h", string(GENERATION_PROJECT))
                        gen_storage_energy_overnight_cost = "0"
                        if df_names_filtred.gen_capacity_limit_mw[x] <= 300
                            for j in 1:length(years_of_interest)
                                gen_overnight_cost1 = CAPEX_gen_tec_Medio["BOMB300_6"]*vector_proyeccion[j]
                                gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Medio["BOMB300_6"]*vector_proyeccion[j])
                                gen_fixed_om = @sprintf("%.0f",3480)
                                push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                            end
                        elseif 301<= df_names_filtred.gen_capacity_limit_mw[x] < 600
                            for j in 1:length(years_of_interest)
                                gen_overnight_cost1 = CAPEX_gen_tec_Medio["BOMB450_6"]*vector_proyeccion[j]
                                gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Medio["BOMB450_6"]*vector_proyeccion[j])
                                gen_fixed_om = @sprintf("%.0f",3480)
                                push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                            end
                        elseif df_names_filtred.gen_capacity_limit_mw[x] >= 600
                            for j in 1:length(years_of_interest)
                                gen_overnight_cost1 = CAPEX_gen_tec_Medio["BOMB600_6"]*vector_proyeccion[j]
                                gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Medio["BOMB600_6"]*vector_proyeccion[j])
                                gen_fixed_om = @sprintf("%.0f",3480)
                                push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                            end
                        end
                    elseif occursin("_10h", string(GENERATION_PROJECT))
                        gen_storage_energy_overnight_cost = "0"
                        if df_names_filtred.gen_capacity_limit_mw[x] <= 300
                            for j in 1:length(years_of_interest)
                                gen_overnight_cost1 = CAPEX_gen_tec_Medio["BOMB300_10"]*vector_proyeccion[j]
                                gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Medio["BOMB300_10"]*vector_proyeccion[j])
                                gen_fixed_om = @sprintf("%.0f",5800)
                                push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                            end
                        elseif 301<= df_names_filtred.gen_capacity_limit_mw[x] < 600
                            for j in 1:length(years_of_interest)
                                gen_overnight_cost1 = CAPEX_gen_tec_Medio["BOMB450_10"]*vector_proyeccion[j]
                                gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Medio["BOMB450_10"]*vector_proyeccion[j])
                                gen_fixed_om = @sprintf("%.0f",5800)
                                push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                            end
                        elseif df_names_filtred.gen_capacity_limit_mw[x] >= 600
                            for j in 1:length(years_of_interest)
                                gen_overnight_cost1 = CAPEX_gen_tec_Medio["BOMB600_10"]*vector_proyeccion[j]
                                gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Medio["BOMB600_10"]*vector_proyeccion[j])
                                gen_fixed_om = @sprintf("%.0f",5800)
                                push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                            end
                        end
                    elseif occursin("_14h", string(GENERATION_PROJECT))
                        gen_storage_energy_overnight_cost = "0"
                        if df_names_filtred.gen_capacity_limit_mw[x] <= 300
                            for j in 1:length(years_of_interest)
                                gen_overnight_cost1 = CAPEX_gen_tec_Medio["BOMB300_14"]*vector_proyeccion[j]
                                gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Medio["BOMB300_14"]*vector_proyeccion[j])
                                gen_fixed_om = @sprintf("%.0f",8120)
                                push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                            end
                        elseif 301<= df_names_filtred.gen_capacity_limit_mw[x] < 600
                            for j in 1:length(years_of_interest)
                                gen_overnight_cost1 = CAPEX_gen_tec_Medio["BOMB450_14"]*vector_proyeccion[j]
                                gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Medio["BOMB450_14"]*vector_proyeccion[j])
                                gen_fixed_om = @sprintf("%.0f",8120)
                                push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                            end
                        elseif df_names_filtred.gen_capacity_limit_mw[x] >= 600
                            for j in 1:length(years_of_interest)
                                gen_overnight_cost1 = CAPEX_gen_tec_Medio["BOMB600_14"]*vector_proyeccion[j]
                                gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Medio["BOMB600_14"]*vector_proyeccion[j])
                                gen_fixed_om = @sprintf("%.0f",8120)
                                push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                            end
                        end
                    end
                end
            end
        else
            if l == "CSP_TES"
                df_names = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Inputs_LDES_Preliminar4/inputs/gen_info.csv", DataFrame)
                df_names_filtred = filter(row -> occursin("CSP-TES", string(row.gen_tech)), df_names)
                for x in 1:length(df_names_filtred.gen_tech)
                    GENERATION_PROJECT = df_names_filtred.GENERATION_PROJECT[x]
                    if occursin("13", string(GENERATION_PROJECT))
                        gen_storage_energy_overnight_cost = "."
                        for j in 1:length(years_of_interest)
                            gen_overnight_cost1 = CAPEX_gen_tec_Bajo["CSP_TES_13"]*vector_proyeccion[j]
                            gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Bajo["CSP_TES_13"]*vector_proyeccion[j])
                            gen_fixed_om = @sprintf("%.0f",gen_overnight_cost1*0.01)
                            push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                        end
                    elseif occursin("17", string(GENERATION_PROJECT))
                        gen_storage_energy_overnight_cost = "."
                        for j in 1:length(years_of_interest)
                            gen_overnight_cost1 = CAPEX_gen_tec_Bajo["CSP_TES_17"]*vector_proyeccion[j]
                            gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Bajo["CSP_TES_17"]*vector_proyeccion[j])
                            gen_fixed_om = @sprintf("%.0f",gen_overnight_cost1*0.01)
                            push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                        end
                    end
                end
            elseif l == "TES"
                df_names = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Inputs_LDES_Preliminar4/inputs/gen_info.csv", DataFrame)
                df_names_filtred = filter(row -> occursin("TES", string(row.gen_tech)), df_names)
                for x in 1:length(df_names_filtred.gen_tech)
                    GENERATION_PROJECT = df_names_filtred.GENERATION_PROJECT[x]
                    if occursin("_6h", string(GENERATION_PROJECT))
                        gen_storage_energy_overnight_cost = "."
                        for j in 1:length(years_of_interest)
                            gen_overnight_cost1 = CAPEX_gen_tec_Bajo["TES_6"]*vector_proyeccion[j]
                            gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Bajo["TES_6"]*vector_proyeccion[j])
                            gen_fixed_om = @sprintf("%.0f",gen_overnight_cost1*0.01)
                            push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                        end
                    elseif occursin("_10h", string(GENERATION_PROJECT))
                        gen_storage_energy_overnight_cost = "."
                        for j in 1:length(years_of_interest)
                            gen_overnight_cost1 = CAPEX_gen_tec_Bajo["TES_10"]*vector_proyeccion[j]
                            gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Bajo["TES_10"]*vector_proyeccion[j])
                            gen_fixed_om = @sprintf("%.0f",gen_overnight_cost1*0.01)
                            push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                        end
                    elseif occursin("_14h", string(GENERATION_PROJECT))
                        gen_storage_energy_overnight_cost = "."
                        for j in 1:length(years_of_interest)
                            gen_overnight_cost1 = CAPEX_gen_tec_Bajo["TES_14"]*vector_proyeccion[j]
                            gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Bajo["TES_14"]*vector_proyeccion[j])
                            gen_fixed_om = @sprintf("%.0f",gen_overnight_cost1*0.01)
                            push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                        end
                    end
                end
            elseif l == "CAES"
                df_names = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Inputs_LDES_Preliminar4/inputs/gen_info.csv", DataFrame)
                df_names_filtred = filter(row -> occursin("CAES", string(row.gen_tech)), df_names)
                for x in 1:length(df_names_filtred.gen_tech)
                    GENERATION_PROJECT = df_names_filtred.GENERATION_PROJECT[x]
                    if occursin("_6h", string(GENERATION_PROJECT))
                        gen_storage_energy_overnight_cost = "0"
                        for j in 1:length(years_of_interest)
                            gen_overnight_cost1 = CAPEX_gen_tec_Bajo["CAES_6"]*vector_proyeccion[j]
                            gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Bajo["CAES_6"]*vector_proyeccion[j])
                            gen_fixed_om = @sprintf("%.0f",gen_overnight_cost1*0.01)
                            push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                        end
                    elseif occursin("_10h", string(GENERATION_PROJECT))
                        gen_storage_energy_overnight_cost = "0"
                        for j in 1:length(years_of_interest)
                            gen_overnight_cost1 = CAPEX_gen_tec_Bajo["CAES_10"]*vector_proyeccion[j]
                            gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Bajo["CAES_10"]*vector_proyeccion[j])
                            gen_fixed_om = @sprintf("%.0f",gen_overnight_cost1*0.01)
                            push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                        end
                    elseif occursin("_14h", string(GENERATION_PROJECT))
                        gen_storage_energy_overnight_cost = "0"
                        for j in 1:length(years_of_interest)
                            gen_overnight_cost1 = CAPEX_gen_tec_Bajo["CAES_14"]*vector_proyeccion[j]
                            gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Bajo["CAES_14"]*vector_proyeccion[j])
                            gen_fixed_om = @sprintf("%.0f",gen_overnight_cost1*0.01)
                            push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                        end
                    end
                end
            elseif l == "BOMB"
                df_names = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Inputs_LDES_Preliminar4/inputs/gen_info.csv", DataFrame)
                df_names_filtred = filter(row -> occursin("Bomb", string(row.gen_tech)), df_names)
                for x in 1:length(df_names_filtred.gen_tech)
                    GENERATION_PROJECT = df_names_filtred.GENERATION_PROJECT[x]
                    if occursin("_6h", string(GENERATION_PROJECT))
                        gen_storage_energy_overnight_cost = "0"
                        if df_names_filtred.gen_capacity_limit_mw[x] <= 300
                            for j in 1:length(years_of_interest)
                                gen_overnight_cost1 = CAPEX_gen_tec_Bajo["BOMB300_6"]*vector_proyeccion[j]
                                gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Bajo["BOMB300_6"]*vector_proyeccion[j])
                                gen_fixed_om = @sprintf("%.0f",3480)
                                push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                            end
                        elseif 301<= df_names_filtred.gen_capacity_limit_mw[x] < 600
                            for j in 1:length(years_of_interest)
                                gen_overnight_cost1 = CAPEX_gen_tec_Bajo["BOMB450_6"]*vector_proyeccion[j]
                                gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Bajo["BOMB450_6"]*vector_proyeccion[j])
                                gen_fixed_om = @sprintf("%.0f",3480)
                                push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                            end
                        elseif df_names_filtred.gen_capacity_limit_mw[x] >= 600
                            for j in 1:length(years_of_interest)
                                gen_overnight_cost1 = CAPEX_gen_tec_Bajo["BOMB600_6"]*vector_proyeccion[j]
                                gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Bajo["BOMB600_6"]*vector_proyeccion[j])
                                gen_fixed_om = @sprintf("%.0f",3480)
                                push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                            end
                        end
                    elseif occursin("_10h", string(GENERATION_PROJECT))
                        gen_storage_energy_overnight_cost = "0"
                        if df_names_filtred.gen_capacity_limit_mw[x]<= 300
                            for j in 1:length(years_of_interest)
                                gen_overnight_cost1 = CAPEX_gen_tec_Bajo["BOMB300_10"]*vector_proyeccion[j]
                                gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Bajo["BOMB300_10"]*vector_proyeccion[j])
                                gen_fixed_om = @sprintf("%.0f",5800)
                                push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                            end
                        elseif 301<= df_names_filtred.gen_capacity_limit_mw[x]< 600
                            for j in 1:length(years_of_interest)
                                gen_overnight_cost1 = CAPEX_gen_tec_Bajo["BOMB450_10"]*vector_proyeccion[j]
                                gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Bajo["BOMB450_10"]*vector_proyeccion[j])
                                gen_fixed_om = @sprintf("%.0f",5800)
                                push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                            end
                        elseif df_names_filtred.gen_capacity_limit_mw[x] >= 600
                            for j in 1:length(years_of_interest)
                                gen_overnight_cost1 = CAPEX_gen_tec_Bajo["BOMB600_10"]*vector_proyeccion[j]
                                gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Bajo["BOMB600_10"]*vector_proyeccion[j])
                                gen_fixed_om = @sprintf("%.0f",5800)
                                push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                            end
                        end
                    elseif occursin("_14h", string(GENERATION_PROJECT))
                        gen_storage_energy_overnight_cost = "0"
                        if df_names_filtred.gen_capacity_limit_mw[x] <= 300
                            for j in 1:length(years_of_interest)
                                gen_overnight_cost1 = CAPEX_gen_tec_Bajo["BOMB300_14"]*vector_proyeccion[j]
                                gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Bajo["BOMB300_14"]*vector_proyeccion[j])
                                gen_fixed_om = @sprintf("%.0f",8120)
                                push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                            end
                        elseif 301<= df_names_filtred.gen_capacity_limit_mw[x]< 600
                            for j in 1:length(years_of_interest)
                                gen_overnight_cost1 = CAPEX_gen_tec_Bajo["BOMB450_14"]*vector_proyeccion[j]
                                gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Bajo["BOMB450_14"]*vector_proyeccion[j])
                                gen_fixed_om = @sprintf("%.0f",8120)
                                push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                            end
                        elseif df_names_filtred.gen_capacity_limit_mw[x] >= 600
                            for j in 1:length(years_of_interest)
                                gen_overnight_cost1 = CAPEX_gen_tec_Bajo["BOMB600_14"]*vector_proyeccion[j]
                                gen_overnight_cost = @sprintf("%.0f",CAPEX_gen_tec_Bajo["BOMB600_14"]*vector_proyeccion[j])
                                gen_fixed_om = @sprintf("%.0f",8120)
                                push!(rows, (GENERATION_PROJECT, years_of_interest[j], gen_overnight_cost,  gen_storage_energy_overnight_cost, gen_fixed_om))
                            end
                        end
                    end
                end
            end
        end
    end 
    output_df = DataFrame(rows, [:GENERATION_PROJECT, :build_year, :gen_overnight_cost, :gen_storage_energy_overnight_cost, :gen_fixed_om])
    CSV.write("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Rumbo_CN/GEN_inputs_CSV/gen_build_costs/$i/not_predeterminatedLDES.csv", output_df)
    
    
    # ju tar en un archivo
    # Directorio que contiene los archivos CSV
    directorio = "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Rumbo_CN/GEN_inputs_CSV/gen_build_costs/$i"

    # Archivo CSV combinado
    archivo_combinado = "gen_build_cost$i.csv"

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
end

