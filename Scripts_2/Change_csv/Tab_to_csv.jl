# script para transformar archivo .tab a csv.
using DelimitedFiles

# Función para convertir .tab a .csv
function convertir_tab_a_csv(nombre_archivo_tab::String, nombre_archivo_csv::String)
    # Leer el archivo .tab
    datos = readdlm(nombre_archivo_tab, '\t', header=false)
    
    # Escribir los datos en un archivo .csv
    open(nombre_archivo_csv, "w") do archivo_csv
        writedlm(archivo_csv, datos, ',')
    end
end

# Ejemplo de uso
nombre_archivo_tab = "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/CSP-TES_Modulo/switch_inputs_last/switch_inputs_last/inputs/gen_build_costs.tab"   # Cambia esto por el nombre de tu archivo .tab
nombre_archivo_csv = "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/gen_build_costs.csv"    # Nombre del archivo .csv de salida

convertir_tab_a_csv(nombre_archivo_tab, nombre_archivo_csv)