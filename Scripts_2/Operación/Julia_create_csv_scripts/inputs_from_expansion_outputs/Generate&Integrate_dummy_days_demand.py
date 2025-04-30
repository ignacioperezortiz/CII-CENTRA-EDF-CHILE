# -*- coding: utf-8 -*-
import pandas as pd
import numpy as np
import os
from datetime import datetime, timedelta, date
from calendar import monthrange
import warnings
# Importar las librerías necesarias para las cópulas
from copulas.multivariate import GaussianMultivariate
import contextlib
import io

# --- Configuración ---
BASE_PATH = "/content/Operacion"
DEMANDA_INPUT_FILE = "/content/loads_sin_cuatridias.csv"
TARGET_YEAR = 2024
N_SAMPLES_COPULA = 50

# --- Configuración de Selección de Zona ---
# Opciones: "ALL", "FIRST", "SPECIFIC"
ZONA_SELECTION_MODE = "ALL" # Cambia esto a "FIRST" o "SPECIFIC" según necesites

# Solo relevante si ZONA_SELECTION_MODE = "SPECIFIC"
SPECIFIC_ZONE_NAME = "Antofagasta" # Reemplaza con el nombre exacto de la zona si usas "SPECIFIC" (asegúrate que NO empiece con "Gx")

# --- NUEVA CONFIGURACIÓN: Prefijo a Excluir ---
PREFIX_TO_EXCLUDE = "Gx"
# --------------------------------------------

# --- Funciones Auxiliares ---

def parse_timepoint(timepoint_str):
    """
    Parsea un string TIMEPOINT en formato EisenhowerMMDDHH y extrae la fecha y hora.
    'DD' en TIMEPOINT representa el día REAL del mes (1-31).
    """
    # ... (sin cambios) ...
    if not isinstance(timepoint_str, str) or len(timepoint_str) != 10:
        return None, None
    try:
        year_tp = int(timepoint_str[0:4])
        month_tp = int(timepoint_str[4:6])
        day_tp = int(timepoint_str[6:8]) # Día REAL del mes
        hour_tp = int(timepoint_str[8:10])

        if not (0 <= hour_tp <= 23):
            return None, None
        if not (1 <= month_tp <= 12):
             return None, None
        try:
            max_days_in_month = monthrange(year_tp, month_tp)[1]
            if not (1 <= day_tp <= max_days_in_month):
                return None, None
        except ValueError:
             return None, None

        actual_date = date(year_tp, month_tp, day_tp)
        return actual_date, hour_tp
    except (ValueError, TypeError) as e:
        return None, None

# --- Lógica Principal ---

# ====== FUNCIÓN MODIFICADA ======
def cargar_y_preparar_datos_base(filepath, prefix_to_exclude=None):
    """
    Carga los datos de demanda base desde el archivo CSV y los organiza
    en un diccionario anidado por zona, año y mes.
    Excluye las zonas que comienzan con el prefijo especificado.

    Args:
        filepath (str): Ruta al archivo CSV de demanda base.
        prefix_to_exclude (str, optional): Prefijo de las zonas a excluir (ej. "Gx").

    Returns:
        dict: Diccionario con los perfiles base {zona: {año: {mes: [lista_24h]}}}
              o None si ocurre un error al cargar el archivo.
    """
    print(f"Cargando datos base desde: {filepath}")
    if prefix_to_exclude:
        print(f"Excluyendo zonas que comienzan con: '{prefix_to_exclude}'")
    try:
        df_demanda = pd.read_csv(filepath)
    except FileNotFoundError:
        print(f"Error Crítico: No se pudo encontrar el archivo de demanda base en: {filepath}")
        return None
    except Exception as e:
        print(f"Error Crítico: Ocurrió un error al leer {filepath}: {e}")
        return None

    df_demanda['TIMEPOINT'] = df_demanda['TIMEPOINT'].astype(str)
    base_profiles = {}

    parsed_data = [parse_timepoint(tp) for tp in df_demanda['TIMEPOINT']]
    df_demanda['parsed_date'], df_demanda['hour'] = zip(*parsed_data)

    original_rows = len(df_demanda)
    df_demanda = df_demanda.dropna(subset=['parsed_date', 'hour'])
    print(f"Filas después de filtrar TIMEPOINT inválidos en datos base: {len(df_demanda)} (de {original_rows})")
    if len(df_demanda) == 0:
        print("Error Crítico: No quedaron filas válidas después de parsear TIMEPOINT en el archivo base.")
        return None

    df_demanda['hour'] = df_demanda['hour'].astype(int)

    if pd.api.types.is_datetime64_any_dtype(df_demanda['parsed_date']):
        df_demanda['year'] = df_demanda['parsed_date'].dt.year
        df_demanda['month'] = df_demanda['parsed_date'].dt.month
    else:
        df_demanda['year'] = df_demanda['parsed_date'].apply(lambda d: d.year)
        df_demanda['month'] = df_demanda['parsed_date'].apply(lambda d: d.month)

    df_demanda = df_demanda.sort_values(by=['LOAD_ZONE', 'year', 'month', 'hour'])
    grouped = df_demanda.groupby(['LOAD_ZONE', 'year', 'month'])
    zonas_cargadas = set()
    zonas_excluidas_count = 0

    for name, group in grouped:
        zona, year, month = name

        # --- NUEVO: Excluir zonas por prefijo ---
        if prefix_to_exclude and zona.startswith(prefix_to_exclude):
            if zona not in zonas_cargadas: # Contar solo una vez por zona excluida
                 zonas_excluidas_count +=1
                 zonas_cargadas.add(zona) # Añadir a cargadas para no volver a contar
            continue # Saltar al siguiente grupo si la zona debe ser excluida
        # --- FIN NUEVO ---

        if len(group) == 24 and list(group['hour']) == list(range(24)):
            profile_24h = group['zone_demand_mw'].tolist()
            if zona not in base_profiles:
                base_profiles[zona] = {}
            if year not in base_profiles[zona]:
                base_profiles[zona][year] = {}
            base_profiles[zona][year][month] = profile_24h
            zonas_cargadas.add(zona) # Añadir zona válida
        else:
            # Solo imprimir advertencia para zonas que NO fueron excluidas
            if not (prefix_to_exclude and zona.startswith(prefix_to_exclude)):
                 print(f"Advertencia: Perfil base incompleto/desordenado para {zona}, Año {year}, Mes {month}. Se encontraron {len(group)} horas. Horas: {list(group['hour'])}. Se omitirá este perfil base.")

    if not base_profiles:
         print(f"Error Crítico: No se pudo cargar ningún perfil base válido (después de excluir prefijo '{prefix_to_exclude}' si aplica).")
         return None

    zonas_finales = sorted(list(base_profiles.keys()))
    print(f"Perfiles base cargados y válidos para {len(zonas_finales)} zonas.")
    if zonas_excluidas_count > 0:
         print(f"Se excluyeron {zonas_excluidas_count} zonas que comenzaban con '{prefix_to_exclude}'.")
    # Opcional: imprimir las zonas finales si no son demasiadas
    # if len(zonas_finales) < 20:
    #      print(f"Zonas incluidas: {', '.join(zonas_finales)}")

    return base_profiles
# ====== FIN FUNCIÓN MODIFICADA ======


def generar_perfiles_sinteticos_con_copula(perfil_base_mes, dias_del_mes, n_samples_copula):
    """
    Genera perfiles sintéticos para todos los días de un mes usando GaussianMultivariate.
    (Sin cambios)
    """
    # ... (sin cambios) ...
    if not isinstance(perfil_base_mes, list) or len(perfil_base_mes) != 24:
        return [[0.0] * 24 for _ in range(dias_del_mes)]

    perfil_base = np.array(perfil_base_mes)
    if np.all(np.abs(perfil_base - perfil_base[0]) < 1e-9 ):
        return [list(perfil_base) for _ in range(dias_del_mes)]
    
    maximo = np.max(perfil_base)
    minimo = np.min(perfil_base)

    if minimo > 1e-6:
        scale = 0.03 * minimo
    else:
        promedio = np.mean(perfil_base)
        if promedio > 1e-6:
            scale = 0.01 * promedio
        else:
            scale = 1e-3

    entrenamiento = []
    for _ in range(n_samples_copula):
        if scale > 1e-9:
            ruido = np.random.normal(loc=0, scale=scale, size=24)
            muestra = perfil_base + ruido
        else:
            muestra = perfil_base
        clip_min = max(0, minimo * 0.8)
        clip_max = maximo * 1.2
        muestra = np.clip(muestra, clip_min, clip_max)
        entrenamiento.append(muestra)

    df_entrenamiento = pd.DataFrame(entrenamiento, columns=[f"hour_{i}" for i in range(24)])

    if df_entrenamiento.var().lt(1e-9).all():
        return [list(perfil_base) for _ in range(dias_del_mes)]

    modelo = GaussianMultivariate()
    try:
        with contextlib.redirect_stdout(io.StringIO()), warnings.catch_warnings():
            warnings.filterwarnings("ignore", category=RuntimeWarning)
            modelo.fit(df_entrenamiento)
    except Exception as e:
        print(f"Error al entrenar la cópula para perfil base: {perfil_base_mes[:5]}... Error: {e}")
        return [[0.0] * 24 for _ in range(dias_del_mes)]

    try:
        with warnings.catch_warnings():
            warnings.filterwarnings("ignore", category=RuntimeWarning)
            muestras_sinteticas_df = modelo.sample(dias_del_mes)

        clip_min_sample = max(0, minimo * 0.7)
        clip_max_sample = maximo * 1.3
        muestras_sinteticas_df = muestras_sinteticas_df.clip(lower=clip_min_sample, upper=clip_max_sample)

        perfiles_sinteticos_mes = muestras_sinteticas_df.values.tolist()
        return perfiles_sinteticos_mes
    except Exception as e:
        print(f"Error al muestrear de la cópula. Error: {e}")
        return [[0.0] * 24 for _ in range(dias_del_mes)]


# ====== FUNCIÓN MODIFICADA ======
def generar_todos_perfiles_sinteticos(base_profiles, year, selection_mode, specific_zone=None, prefix_to_exclude=None):
    """
    Genera perfiles sintéticos diarios según el modo de selección de zona,
    asegurándose de no procesar zonas excluidas por prefijo.

    Args:
        base_profiles (dict): Diccionario con los perfiles base (ya filtrados).
        year (int): El año para el cual generar los perfiles.
        selection_mode (str): Modo de selección ("ALL", "FIRST", "SPECIFIC").
        specific_zone (str, optional): Nombre de la zona específica si mode="SPECIFIC".
        prefix_to_exclude (str, optional): Prefijo de zonas a excluir (para validación).

    Returns:
        dict: Diccionario con los perfiles sintéticos {zona: {fecha: [lista_24h]}}
              para la(s) zona(s) seleccionada(s), o None si hay error o no hay datos.
    """
    perfiles_sinteticos_anuales = {}
    print(f"Generando perfiles sintéticos para el año {year} (Modo: {selection_mode})")

    if not base_profiles:
        print("Error: No hay perfiles base disponibles (posiblemente todos excluidos o error previo).")
        return None

    # --- Determinar las zonas a procesar según el modo (y excluir prefijo) ---
    zonas_a_procesar = []
    available_zones = list(base_profiles.keys()) # Zonas que pasaron el filtro inicial

    if selection_mode == "ALL":
        # Ya están filtradas en base_profiles, así que las tomamos todas
        zonas_a_procesar = available_zones
        if not zonas_a_procesar:
             print("Advertencia: No quedaron zonas disponibles después de filtrar por prefijo.")
        else:
             print(f"Se procesarán todas las zonas disponibles ({len(zonas_a_procesar)}): {', '.join(sorted(zonas_a_procesar))}")

    elif selection_mode == "FIRST":
        # Encontrar la primera zona disponible que NO empiece con el prefijo
        # (Aunque base_profiles ya está filtrado, esta es una doble seguridad)
        first_zone_found = None
        for zona in available_zones: # Iterar en el orden que Python devuelva las claves
             if not (prefix_to_exclude and zona.startswith(prefix_to_exclude)):
                  first_zone_found = zona
                  break # Encontramos la primera válida
        if first_zone_found:
            zonas_a_procesar = [first_zone_found]
            print(f"Se procesará solo la primera zona disponible encontrada: {first_zone_found}")
        else:
            print(f"Error: No se encontró ninguna zona disponible (que no comience con '{prefix_to_exclude}') para el modo 'FIRST'.")
            return None

    elif selection_mode == "SPECIFIC":
        if not specific_zone:
            print("Error: Modo 'SPECIFIC' seleccionado pero no se proporcionó nombre de zona.")
            return None
        # --- NUEVO: Validar si la zona específica está excluida ---
        if prefix_to_exclude and specific_zone.startswith(prefix_to_exclude):
            print(f"Error: La zona específica '{specific_zone}' comienza con el prefijo excluido '{prefix_to_exclude}' y no será procesada.")
            return None
        # --- FIN NUEVO ---
        if specific_zone in available_zones:
            zonas_a_procesar = [specific_zone]
            print(f"Se procesará la zona específica: {specific_zone}")
        else:
            # Informar si no está porque no existe o porque fue filtrada antes
            print(f"Error: La zona específica '{specific_zone}' no se encontró entre las zonas disponibles y válidas.")
            print(f"Zonas disponibles: {', '.join(sorted(available_zones))}")
            return None
    else:
        print(f"Error: Modo de selección de zona '{selection_mode}' no reconocido. Use 'ALL', 'FIRST' o 'SPECIFIC'.")
        return None

    if not zonas_a_procesar:
         print("Advertencia: No se seleccionó ninguna zona válida para procesar.")
         return {} # Devolver diccionario vacío si no hay nada que hacer

    # --- Iterar sobre las ZONAS SELECCIONADAS y VÁLIDAS ---
    zonas_procesadas_count = 0
    for zona in zonas_a_procesar:
        # Doble chequeo (redundante si la lógica anterior es correcta, pero seguro)
        if prefix_to_exclude and zona.startswith(prefix_to_exclude):
             continue
        if year not in base_profiles[zona]:
             print(f"Advertencia: No hay datos base para la zona {zona} en el año {year}. Saltando.")
             continue

        print(f"  Procesando zona: {zona}")
        perfiles_sinteticos_anuales[zona] = {}
        data_meses_base = base_profiles[zona][year]
        zonas_procesadas_count += 1

        # Bucle de meses (sin cambios)
        for month in range(1, 13):
            perfil_base_mes = data_meses_base.get(month)
            try:
                 dias_del_mes = monthrange(year, month)[1]
                 # imprime el més y el numero de días del mes, indicando que se están generando esa cantidad de perfiles sinteticos
                 print(f"    Procesando mes: {month} (Generando {dias_del_mes} perfiles sintéticos)")
            except ValueError:
                 print(f"Error: Mes inválido ({month}) al calcular días para zona {zona}, año {year}. Saltando mes.")
                 continue
            perfiles_sinteticos_mes = None
            # Lógica de fallback (sin cambios)
            if perfil_base_mes is None:
                fallback_profile = None
                if month > 1: fallback_profile = data_meses_base.get(month - 1)
                if fallback_profile and isinstance(fallback_profile, list) and len(fallback_profile) == 24: perfil_base_mes = fallback_profile
                else: perfil_base_mes = [0.0] * 24; perfiles_sinteticos_mes = [[0.0] * 24 for _ in range(dias_del_mes)]
            elif not isinstance(perfil_base_mes, list) or len(perfil_base_mes) != 24: perfil_base_mes = [0.0] * 24; perfiles_sinteticos_mes = [[0.0] * 24 for _ in range(dias_del_mes)]
            # Generar perfiles (sin cambios)
            if perfiles_sinteticos_mes is None:
                if np.all(np.abs(np.array(perfil_base_mes) - perfil_base_mes[0]) < 1e-9 ): perfiles_sinteticos_mes = [list(perfil_base_mes) for _ in range(dias_del_mes)]
                else: perfiles_sinteticos_mes = generar_perfiles_sinteticos_con_copula(perfil_base_mes, dias_del_mes, N_SAMPLES_COPULA)
            # Asignar perfiles (sin cambios)
            if isinstance(perfiles_sinteticos_mes, list) and len(perfiles_sinteticos_mes) == dias_del_mes:
                for day_index in range(dias_del_mes):
                    try: current_date = date(year, month, day_index + 1); perfiles_sinteticos_anuales[zona][current_date] = perfiles_sinteticos_mes[day_index]
                    except ValueError: print(f"Error: Fecha inválida al asignar perfil: Zona {zona}, Año {year}, Mes {month}, Día {day_index + 1}")
            else:
                for day_index in range(dias_del_mes):
                     try: current_date = date(year, month, day_index + 1); perfiles_sinteticos_anuales[zona][current_date] = [0.0] * 24
                     except ValueError: print(f"Error: Fecha inválida al asignar perfil de ceros: Zona {zona}, Año {year}, Mes {month}, Día {day_index + 1}")
        # Fin bucle meses
    # Fin bucle zonas

    print(f"Generación de perfiles sintéticos completada para {zonas_procesadas_count} zona(s).")
    if not perfiles_sinteticos_anuales:
        return None # O {} ? Devolver None si no se procesó nada útil
    return perfiles_sinteticos_anuales
# ====== FIN FUNCIÓN MODIFICADA ======


# ====== FUNCIÓN MODIFICADA ======
def asignar_perfiles_a_archivos(perfiles_sinteticos, base_path, year, prefix_to_exclude=None):
    """
    Asigna los perfiles sintéticos generados a los archivos CSV diarios,
    asegurándose de saltar las filas cuya zona comience con el prefijo excluido.

    Args:
        perfiles_sinteticos (dict): Perfiles pre-generados {zona: {fecha: [lista_24h]}}.
        base_path (str): Ruta base donde se encuentran las carpetas `inputs_{año}`.
        year (int): El año que se está procesando.
        prefix_to_exclude (str, optional): Prefijo de las zonas a excluir al procesar filas.
    """
    print(f"\nIniciando asignación de perfiles sintéticos a los archivos para el año {year}...")
    if prefix_to_exclude:
        print(f"Se saltarán las filas de zonas que comiencen con: '{prefix_to_exclude}'")

    if not perfiles_sinteticos:
        print("Advertencia: No hay perfiles sintéticos generados para asignar.")
        return

    zonas_con_perfiles = list(perfiles_sinteticos.keys())
    print(f"Se intentará asignar perfiles para la(s) zona(s): {', '.join(sorted(zonas_con_perfiles))}")

    num_days_in_year = 366 if monthrange(year, 2)[1] == 29 else 365

    archivos_procesados = 0
    archivos_no_encontrados = 0
    total_filas_actualizadas = 0
    total_filas_leidas = 0
    total_filas_excluidas_prefijo = 0 # Nuevo contador
    total_errores_parseo = 0
    total_perfiles_no_encontrados = 0
    updates_por_zona = {zona: 0 for zona in zonas_con_perfiles}

    # Iterar sobre cada carpeta diaria
    for day_folder_index in range(num_days_in_year):
        archivo_ruta = os.path.join(base_path, f"inputs_{year}", str(day_folder_index), "inputs_dispatch", "loads.csv")

        if not os.path.exists(archivo_ruta):
            archivos_no_encontrados += 1
            continue

        try:
            df_dia = pd.read_csv(archivo_ruta)
            df_dia['TIMEPOINT'] = df_dia['TIMEPOINT'].astype(str)
            archivos_procesados += 1
        except Exception as e:
            print(f"  Error al leer el archivo {archivo_ruta}: {e}. Saltando.")
            continue

        df_dia['nueva_demanda'] = np.nan
        updates_count_file = 0
        parse_errors_file = 0
        profile_not_found_file = 0
        excluded_prefix_file = 0 # Nuevo contador por archivo

        # Iterar sobre cada fila del archivo
        for index, row in df_dia.iterrows():
            zona_fila = row['LOAD_ZONE']
            timepoint_str = row['TIMEPOINT']
            total_filas_leidas += 1

            # --- NUEVO: Excluir fila si la zona empieza con el prefijo ---
            if prefix_to_exclude and zona_fila.startswith(prefix_to_exclude):
                excluded_prefix_file += 1
                continue # Saltar esta fila completamente
            # --- FIN NUEVO ---

            # Intentar actualizar solo si tenemos perfiles para esta zona (que no fue excluida)
            if zona_fila not in perfiles_sinteticos:
                continue # Saltar si no generamos perfiles para esta zona

            # Parsear TIMEPOINT
            actual_date, target_hour = parse_timepoint(timepoint_str)

            if actual_date is None or target_hour is None:
                parse_errors_file += 1
                continue

            # Buscar perfil
            perfiles_zona_actual = perfiles_sinteticos[zona_fila]
            perfil_correcto = perfiles_zona_actual.get(actual_date)

            if perfil_correcto:
                if isinstance(perfil_correcto, list) and len(perfil_correcto) == 24:
                    valor_correcto = perfil_correcto[target_hour]
                    df_dia.loc[index, 'nueva_demanda'] = valor_correcto
                    updates_count_file += 1
                    updates_por_zona[zona_fila] += 1
                else:
                    profile_not_found_file += 1
            else:
                profile_not_found_file += 1

        # Actualizar columna original
        df_dia['zone_demand_mw'] = df_dia['nueva_demanda'].where(
                                         df_dia['nueva_demanda'].notna(),
                                         df_dia['zone_demand_mw']
                                     )

        # Actualizar totales
        total_filas_actualizadas += updates_count_file
        total_filas_excluidas_prefijo += excluded_prefix_file # Acumular excluidas
        total_errores_parseo += parse_errors_file
        total_perfiles_no_encontrados += profile_not_found_file

        # Guardar archivo
        try:
            columnas_a_quitar = ['nueva_demanda']
            if 'parsed_date' in df_dia.columns: columnas_a_quitar.append('parsed_date')
            if 'hour' in df_dia.columns: columnas_a_quitar.append('hour')
            df_dia_guardar = df_dia.drop(columns=columnas_a_quitar, errors='ignore')
            df_dia_guardar.to_csv(archivo_ruta, index=False)
        except Exception as e:
            print(f"  Error Crítico al guardar el archivo modificado {archivo_ruta}: {e}")

    # Imprimir resumen final
    print("\n" + "-" * 30)
    print("Resumen de la asignación:")
    print(f"  Archivos procesados: {archivos_procesados}")
    print(f"  Archivos no encontrados/saltados: {archivos_no_encontrados}")
    print(f"  Total filas leídas en todos los archivos: {total_filas_leidas}")
    if prefix_to_exclude:
        print(f"  Total filas saltadas (prefijo '{prefix_to_exclude}'): {total_filas_excluidas_prefijo}")
    print(f"  Total filas actualizadas (zonas procesadas): {total_filas_actualizadas}")
    print("  Actualizaciones por zona:")
    for zona, count in sorted(updates_por_zona.items()):
         if count > 0: print(f"    - {zona}: {count}")
    print(f"  Total errores de parseo TIMEPOINT: {total_errores_parseo}")
    print(f"  Total perfiles sintéticos no encontrados (durante asignación): {total_perfiles_no_encontrados}")
    print("-" * 30)
    print("Asignación de perfiles completada.")
# ====== FIN FUNCIÓN MODIFICADA ======


# ====== FUNCIÓN MODIFICADA ======
def ejecutar_proceso_demanda(year, base_path, demanda_input_file, selection_mode, specific_zone=None, prefix_to_exclude=None):
    """
    Orquesta la ejecución completa del proceso según el modo de selección de zona,
    excluyendo zonas por prefijo.

    Args:
        year (int): Año a procesar.
        base_path (str): Ruta base de operación.
        demanda_input_file (str): Ruta al CSV con perfiles base.
        selection_mode (str): Modo ("ALL", "FIRST", "SPECIFIC").
        specific_zone (str, optional): Nombre de la zona si mode="SPECIFIC".
        prefix_to_exclude (str, optional): Prefijo de zonas a excluir.
    """
    print("=" * 50)
    print(f"Iniciando proceso para el año {year}")
    print(f"Modo de selección de zona: {selection_mode}")
    if selection_mode == "SPECIFIC":
        print(f"Zona específica objetivo: {specific_zone if specific_zone else 'NO ESPECIFICADA'}")
    if prefix_to_exclude:
        print(f"Prefijo de exclusión: '{prefix_to_exclude}'")
    print("=" * 50)

    # 1. Cargar y preparar datos base, excluyendo prefijo
    base_profiles = cargar_y_preparar_datos_base(demanda_input_file, prefix_to_exclude)
    if base_profiles is None:
        print("Proceso detenido: Error en la carga de datos base (o no quedaron zonas válidas).")
        return

    # 2. Generar perfiles sintéticos según el modo, validando contra prefijo
    perfiles_sinteticos = generar_todos_perfiles_sinteticos(
        base_profiles, year, selection_mode, specific_zone, prefix_to_exclude
    )
    if perfiles_sinteticos is None or not perfiles_sinteticos:
        print("Proceso detenido: No se generaron perfiles sintéticos (verifique modo, nombre de zona, prefijo y datos base).")
        return

    # 3. Asignar los perfiles generados, excluyendo filas por prefijo
    asignar_perfiles_a_archivos(perfiles_sinteticos, base_path, year, prefix_to_exclude)

    print("\n" + "=" * 50)
    print(f"Proceso para el año {year} (Modo: {selection_mode}) finalizado.")
    print("=" * 50)
# ====== FIN FUNCIÓN MODIFICADA ======

# --- Punto de Entrada ---
if __name__ == "__main__":
    warnings.simplefilter(action='ignore', category=FutureWarning)
    warnings.simplefilter(action='ignore', category=pd.errors.SettingWithCopyWarning)
    warnings.simplefilter(action='ignore', category=RuntimeWarning)
    # warnings.simplefilter(action='ignore', category=UserWarning)

    # --- CONFIGURACIÓN DE EJECUCIÓN ---
    target_year_run = TARGET_YEAR
    base_path_run = BASE_PATH
    demanda_file_run = DEMANDA_INPUT_FILE

    # --- Elige el modo aquí ---
    modo_ejecucion = "ALL"
    # modo_ejecucion = "FIRST"
    # modo_ejecucion = "SPECIFIC"

    # --- Define la zona específica si modo_ejecucion es "SPECIFIC" ---
    # ¡¡¡ASEGÚRATE QUE NO EMPIECE CON EL PREFIJO A EXCLUIR!!!
    zona_especifica_run = "Antofagasta" # Ejemplo
    # zona_especifica_run = None

    # --- Define el prefijo a excluir ---
    prefijo_a_excluir_run = PREFIX_TO_EXCLUDE # Usa la constante definida arriba ("Gx")
    # prefijo_a_excluir_run = None # Si no quieres excluir nada

    # Validar configuración antes de ejecutar
    error_config = False
    if modo_ejecucion == "SPECIFIC":
        if not zona_especifica_run:
            print("ERROR DE CONFIGURACIÓN: El modo es 'SPECIFIC' pero 'zona_especifica_run' no está definida.")
            error_config = True
        elif prefijo_a_excluir_run and zona_especifica_run.startswith(prefijo_a_excluir_run):
             print(f"ERROR DE CONFIGURACIÓN: La zona específica '{zona_especifica_run}' comienza con el prefijo excluido '{prefijo_a_excluir_run}'.")
             error_config = True

    if not error_config:
        # Ejecutar el proceso completo pasando toda la configuración
        ejecutar_proceso_demanda(
            target_year_run,
            base_path_run,
            demanda_file_run,
            modo_ejecucion,
            zona_especifica_run if modo_ejecucion == "SPECIFIC" else None,
            prefijo_a_excluir_run
        )
    else:
        print("\nProceso no ejecutado debido a errores de configuración.")