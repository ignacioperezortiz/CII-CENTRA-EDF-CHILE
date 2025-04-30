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
# AJUSTA ESTAS RUTAS SEGÚN TU ENTORNO DE COLAB/LOCAL
BASE_PATH = "/content/Operacion" # Ruta base donde está la carpeta Operacion
CAPACITY_FACTOR_INPUT_FILE = "/content/variable_capacity_factors_sin_cuatridias.csv" # Archivo con factores de capacidad base
GEN_INFO_INPUT_FILE = "/content/gen_info.csv" # Archivo con info de generadores (tipo y ZONA DE CARGA)

TARGET_YEAR = 2024 # Año para el cual generar los perfiles
N_SAMPLES_COPULA = 50 # Número de muestras para entrenar la cópula

# --- Configuración de Selección de Generador ---
# ALL: Procesa todos los generadores (o representantes de grupo)
# SPECIFIC: Procesa solo el generador especificado (o su grupo representativo)
# FIRST: Procesa el primer generador válido encontrado (o su grupo representativo)
GENERATOR_SELECTION_MODE = "ALL"
SPECIFIC_GENERATOR_NAME = "NombreGeneradorEspecifico" # Relevante solo si GENERATOR_SELECTION_MODE = "SPECIFIC"
PREFIX_TO_EXCLUDE = None # Ejemplo: "ExcludePrefix_" para ignorar generadores que empiecen así
# --------------------------------------------

# --- Funciones Auxiliares ---

def parse_timepoint(timepoint_str):
    """Parsea formato YYYYMMDDHH."""
    # (Sin cambios en esta función)
    if not isinstance(timepoint_str, str) or len(timepoint_str) != 10: return None, None
    try:
        year_tp = int(timepoint_str[0:4]); month_tp = int(timepoint_str[4:6])
        day_tp = int(timepoint_str[6:8]); hour_tp = int(timepoint_str[8:10])
        if not (0 <= hour_tp <= 23): return None, None
        if not (1 <= month_tp <= 12): return None, None
        try:
            max_days_in_month = monthrange(year_tp, month_tp)[1]
            if not (1 <= day_tp <= max_days_in_month): return None, None
        except ValueError: return None, None
        actual_date = date(year_tp, month_tp, day_tp)
        return actual_date, hour_tp
    except (ValueError, TypeError): return None, None

# ====== FUNCIÓN MODIFICADA ======
def obtener_info_generador(gen_name, df_gen_info):
    """
    Obtiene el tipo ('PV', 'WIND', 'OTHER') y la zona de carga ('gen_load_zone')
    del generador. Devuelve ('OTHER', 'UNKNOWN_ZONE') si no se encuentra o hay error.
    """
    default_type = 'OTHER'
    default_zone = 'UNKNOWN_ZONE' # Zona por defecto si no se encuentra

    if df_gen_info is None or 'GENERATION_PROJECT' not in df_gen_info.columns:
        # print(f"Advertencia: df_gen_info no válido o falta 'GENERATION_PROJECT'. Usando defaults para {gen_name}.")
        return default_type, default_zone

    # Asegurarse que las columnas necesarias existen
    required_cols = ['GENERATION_PROJECT', 'gen_tech', 'gen_load_zone']
    if not all(col in df_gen_info.columns for col in required_cols):
        # print(f"Advertencia: Faltan columnas {required_cols} en gen_info.csv. Usando defaults para {gen_name}.")
        return default_type, default_zone

    info = df_gen_info[df_gen_info['GENERATION_PROJECT'] == gen_name]

    if info.empty:
        # print(f"Advertencia: Generador '{gen_name}' no encontrado en gen_info.csv. Usando defaults.")
        return default_type, default_zone

    # Obtener tipo
    tipo_tech = info['gen_tech'].iloc[0]
    if pd.isna(tipo_tech):
        gen_type = default_type
    elif tipo_tech == 'PV':
        gen_type = 'PV'
    elif tipo_tech == 'WIND':
        gen_type = 'WIND'
    else:
        gen_type = default_type

    # Obtener zona de carga
    load_zone = info['gen_load_zone'].iloc[0]
    if pd.isna(load_zone) or not isinstance(load_zone, str) or not load_zone.strip():
        # print(f"Advertencia: Zona de carga inválida o faltante para '{gen_name}'. Usando '{default_zone}'.")
        load_zone = default_zone
    else:
        load_zone = load_zone.strip() # Limpiar espacios

    return gen_type, load_zone
# ====== FIN FUNCIÓN MODIFICADA ======


# ====== FUNCIÓN MODIFICADA ======
def cargar_y_preparar_datos_capacidad(capacity_factor_filepath, gen_info_filepath, prefix_to_exclude=None):
    """
    Carga los datos base de factores de capacidad y la información de generadores.
    Organiza los datos por generador, año y mes, incluyendo tipo y ZONA DE CARGA.
    Excluye generadores que comienzan con el prefijo especificado.
    """
    print(f"Cargando datos de factores de capacidad base desde: {capacity_factor_filepath}")
    print(f"Cargando información de generadores (tipo y zona) desde: {gen_info_filepath}")
    if prefix_to_exclude:
        print(f"Excluyendo generadores que comienzan con: '{prefix_to_exclude}'")

    try:
        df_capacity = pd.read_csv(capacity_factor_filepath)
    except FileNotFoundError:
        print(f"Error Crítico: No se pudo encontrar el archivo de factores de capacidad en: {capacity_factor_filepath}")
        return None
    except Exception as e:
        print(f"Error Crítico: Ocurrió un error al leer {capacity_factor_filepath}: {e}")
        return None

    try:
        df_gen_info = pd.read_csv(gen_info_filepath)
    except FileNotFoundError:
        print(f"Advertencia: No se pudo encontrar el archivo de información de generadores en: {gen_info_filepath}. Se asumirá tipo 'OTHER' y zona 'UNKNOWN_ZONE'.")
        df_gen_info = None # Continuar sin info de generador si no se encuentra
    except Exception as e:
        print(f"Advertencia: Ocurrió un error al leer {gen_info_filepath}: {e}. Se asumirá tipo 'OTHER' y zona 'UNKNOWN_ZONE'.")
        df_gen_info = None

    # Validar columnas de df_capacity
    required_cap_cols = ['GENERATION_PROJECT', 'timepoint', 'gen_max_capacity_factor']
    if not all(col in df_capacity.columns for col in required_cap_cols):
        print(f"Error Crítico: Faltan columnas requeridas en {capacity_factor_filepath}. Se necesitan: {required_cap_cols}")
        print(f"Columnas encontradas: {list(df_capacity.columns)}")
        return None

    # Validar columnas de df_gen_info si existe
    if df_gen_info is not None:
        required_gen_cols = ['GENERATION_PROJECT', 'gen_tech', 'gen_load_zone']
        if not all(col in df_gen_info.columns for col in required_gen_cols):
            print(f"Error Crítico: Faltan columnas requeridas en {gen_info_filepath}. Se necesitan: {required_gen_cols}. Columnas encontradas: {list(df_gen_info.columns)}")
            # Decidir si continuar o detenerse. Por ahora, continuamos con defaults.
            print("Advertencia: Se continuará asumiendo tipo 'OTHER' y zona 'UNKNOWN_ZONE' para los generadores.")
            # df_gen_info = None # Podríamos anularlo aquí si preferimos detenernos
    else:
         print("Información: No se cargó df_gen_info, se usarán valores por defecto para tipo y zona.")


    df_capacity['timepoint'] = df_capacity['timepoint'].astype(str)
    base_profiles_capacity = {}

    parsed_data = [parse_timepoint(tp) for tp in df_capacity['timepoint']]
    df_capacity['parsed_date'], df_capacity['hour'] = zip(*parsed_data)

    original_rows = len(df_capacity)
    df_capacity = df_capacity.dropna(subset=['parsed_date', 'hour'])
    rows_after_dropna = len(df_capacity)
    print(f"Filas después de filtrar timepoint inválidos en datos base: {rows_after_dropna} (de {original_rows})")
    if rows_after_dropna == 0:
        print("Error Crítico: No quedaron filas válidas después de parsear timepoint en el archivo base.")
        return None

    df_capacity['hour'] = df_capacity['hour'].astype(int)

    # Extraer año y mes de forma segura
    try:
        # Intentar conversión directa si es datetime
        if pd.api.types.is_datetime64_any_dtype(df_capacity['parsed_date']):
            df_capacity['year'] = df_capacity['parsed_date'].dt.year
            df_capacity['month'] = df_capacity['parsed_date'].dt.month
        else: # Intentar conversión manual si son objetos date
            df_capacity['year'] = df_capacity['parsed_date'].apply(lambda d: d.year if isinstance(d, date) else None)
            df_capacity['month'] = df_capacity['parsed_date'].apply(lambda d: d.month if isinstance(d, date) else None)
            df_capacity = df_capacity.dropna(subset=['year', 'month']) # Eliminar filas donde no se pudo extraer
            if not df_capacity.empty:
                 df_capacity['year'] = df_capacity['year'].astype(int)
                 df_capacity['month'] = df_capacity['month'].astype(int)

    except Exception as e:
         print(f"Error Crítico al extraer año/mes de 'parsed_date': {e}")
         return None

    if df_capacity.empty:
         print("Error Crítico: No quedaron filas válidas después de extraer año/mes.")
         return None


    df_capacity = df_capacity.sort_values(by=['GENERATION_PROJECT', 'year', 'month', 'hour'])

    grouped = df_capacity.groupby(['GENERATION_PROJECT', 'year', 'month'])
    generadores_cargados = set()
    generadores_excluidos_prefijo_count = 0
    generadores_perfil_incompleto = set()

    for name, group in grouped:
        generador, year, month = name

        # Aplicar exclusión por prefijo
        if prefix_to_exclude and generador.startswith(prefix_to_exclude):
            if generador not in generadores_cargados and generador not in generadores_perfil_incompleto: # Contar solo una vez por generador excluido
                 generadores_excluidos_prefijo_count += 1
                 generadores_cargados.add(generador) # Añadir a cargados para no volver a contar
            continue # Saltar este grupo

        # Verificar perfil completo (24 horas ordenadas)
        if len(group) == 24 and list(group['hour']) == list(range(24)):
            profile_24h = group['gen_max_capacity_factor'].tolist()
            profile_24h = np.clip(profile_24h, 0, 1).tolist() # Asegurar rango [0, 1]

            # Obtener tipo y zona de carga
            gen_type, load_zone = obtener_info_generador(generador, df_gen_info)

            # Almacenar perfil base junto con tipo y zona
            if generador not in base_profiles_capacity: base_profiles_capacity[generador] = {}
            if year not in base_profiles_capacity[generador]: base_profiles_capacity[generador][year] = {}
            base_profiles_capacity[generador][year][month] = {
                'profile': profile_24h,
                'type': gen_type,
                'load_zone': load_zone # Guardar la zona de carga
            }
            generadores_cargados.add(generador)
        else:
            # Registrar advertencia solo una vez por generador con perfil incompleto
            if generador not in generadores_perfil_incompleto and generador not in generadores_cargados:
                 print(f"Advertencia: Perfil base de capacidad incompleto/desordenado para {generador} (Año {year}, Mes {month}). Se encontraron {len(group)} horas. Horas: {list(group['hour'])}. Se omitirán los perfiles base de este generador.")
                 generadores_perfil_incompleto.add(generador)


    if not base_profiles_capacity:
        print(f"Error Crítico: No se pudo cargar ningún perfil base de capacidad válido (después de aplicar filtros y exclusiones).")
        return None

    generadores_finales = sorted(list(base_profiles_capacity.keys()))
    print(f"Perfiles base de capacidad cargados y válidos para {len(generadores_finales)} generadores.")
    if generadores_excluidos_prefijo_count > 0:
        print(f"Se excluyeron {generadores_excluidos_prefijo_count} generadores que comenzaban con '{prefix_to_exclude}'.")
    if generadores_perfil_incompleto:
         print(f"Se omitieron perfiles base incompletos para {len(generadores_perfil_incompleto)} generadores.")

    return base_profiles_capacity
# ====== FIN FUNCIÓN MODIFICADA ======


def generar_perfiles_sinteticos_con_copula(perfil_base_mes, tipo_generador, dias_del_mes, n_samples_copula):
    """Genera perfiles sintéticos con cópula."""
    # (Sin cambios funcionales significativos en esta función)
    # Asegurarse que la entrada es válida
    if not isinstance(perfil_base_mes, list) or len(perfil_base_mes) != 24:
        # print(f"Advertencia interna (cópula): Perfil base inválido recibido ({type(perfil_base_mes)}). Usando ceros.")
        return [[0.0] * 24 for _ in range(dias_del_mes)]

    perfil_base = np.clip(np.array(perfil_base_mes), 0, 1)

    # Aplicar perfil nocturno cero para PV
    if tipo_generador == "PV":
        perfil_base[0:6] = 0 # Horas 0-5
        perfil_base[20:24] = 0 # Horas 20-23

    # Si el perfil base es constante, no usar cópula, repetir el perfil
    if np.all(np.abs(perfil_base - perfil_base[0]) < 1e-9):
        # print(f"      -> Perfil base constante detectado ({tipo_generador}). Repitiendo perfil base.")
        return [list(perfil_base) for _ in range(dias_del_mes)]

    # Determinar escala del ruido según tipo
    if tipo_generador == "PV":
        scale = 0.02
    elif tipo_generador == "WIND":
        scale = 0.15
    else: # OTHER o desconocido
        scale = 0.1

    # Generar datos de entrenamiento añadiendo ruido gaussiano
    entrenamiento = []
    for _ in range(n_samples_copula):
        if scale > 1e-9: # Solo añadir ruido si la escala es significativa
            ruido = np.random.normal(loc=0, scale=scale, size=24)
            muestra = perfil_base + ruido
        else:
            muestra = perfil_base.copy() # Usar copia para evitar modificar el original

        muestra = np.clip(muestra, 0, 1) # Asegurar rango [0, 1]

        # Re-aplicar perfil nocturno cero para PV después del ruido
        if tipo_generador == "PV":
            muestra[0:6] = 0
            muestra[20:24] = 0

        entrenamiento.append(muestra)

    df_entrenamiento = pd.DataFrame(entrenamiento, columns=[f"hour_{i}" for i in range(24)])

    # Verificar si hay varianza suficiente para la cópula
    if df_entrenamiento.var().lt(1e-9).all():
        # print(f"      -> Varianza insuficiente en datos de entrenamiento ({tipo_generador}). Repitiendo perfil base.")
        return [list(perfil_base) for _ in range(dias_del_mes)]

    # Entrenar el modelo de Cópula Gaussiana
    modelo = GaussianMultivariate()
    try:
        # Suprimir salida estándar y warnings durante el fit
        with contextlib.redirect_stdout(io.StringIO()), warnings.catch_warnings():
            warnings.simplefilter("ignore", category=RuntimeWarning)
            warnings.simplefilter("ignore", category=UserWarning) # Ignorar warnings de copulas
            modelo.fit(df_entrenamiento)
    except Exception as e:
        print(f"      Error al entrenar la cópula ({tipo_generador}), perfil base (primeros 5): {perfil_base[:5]}... Error: {e}. Se usarán ceros.")
        return [[0.0] * 24 for _ in range(dias_del_mes)] # Retornar ceros en caso de error

    # Generar muestras sintéticas
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", category=RuntimeWarning)
            warnings.simplefilter("ignore", category=UserWarning) # Ignorar warnings de copulas
            muestras_sinteticas_df = modelo.sample(dias_del_mes)

        # Post-procesamiento de las muestras
        muestras_sinteticas_df = muestras_sinteticas_df.clip(lower=0, upper=1) # Asegurar [0, 1]

        # Aplicar perfil nocturno cero para PV en las muestras generadas
        if tipo_generador == "PV":
            night_hours_cols = [f"hour_{i}" for i in list(range(6)) + list(range(20, 24))]
            for col in night_hours_cols:
                if col in muestras_sinteticas_df.columns:
                    muestras_sinteticas_df[col] = 0

        return muestras_sinteticas_df.values.tolist() # Devolver como lista de listas

    except Exception as e:
        print(f"      Error al muestrear de la cópula ({tipo_generador}). Error: {e}. Se usarán ceros.")
        return [[0.0] * 24 for _ in range(dias_del_mes)] # Retornar ceros en caso de error


# ====== FUNCIÓN MODIFICADA ======
def generar_todos_perfiles_capacidad_sinteticos(base_profiles_capacity, year, selection_mode, specific_generator=None, prefix_to_exclude=None):
    """
    Genera perfiles sintéticos anuales, optimizando por grupo (zona, tipo).
    Genera perfiles solo para representantes de grupo (PV/WIND) y para generadores 'OTHER'.
    Devuelve los perfiles sintéticos y un mapeo de cada generador a su representante.
    """
    perfiles_sinteticos_representantes = {}
    generator_to_representative_map = {}
    representatives_chosen = {} # (load_zone, type) -> representative_gen_name
    processed_groups = set() # (load_zone, type)
    generators_to_process = [] # Lista final de generadores para los que se generará perfil

    print(f"\nIniciando identificación de grupos y representantes para el año {year}...")
    if not base_profiles_capacity:
        print("Error: No hay perfiles base de capacidad disponibles.")
        return None, None

    # 1. Identificar todos los generadores válidos iniciales (tienen datos para el año)
    valid_generators_for_year = {
        gen: info[year]
        for gen, info in base_profiles_capacity.items()
        if year in info and not (prefix_to_exclude and gen.startswith(prefix_to_exclude))
    }

    if not valid_generators_for_year:
        print(f"Error: No se encontraron datos base para ningún generador en el año {year} (después de exclusión por prefijo).")
        return None, None

    print(f"Generadores con datos base válidos para {year}: {len(valid_generators_for_year)}")

    # 2. Aplicar modo de selección para determinar el conjunto inicial a considerar
    initial_selection = []
    available_gen_names = sorted(list(valid_generators_for_year.keys()))

    if selection_mode == "ALL":
        initial_selection = available_gen_names
        print(f"Modo ALL: Se considerarán todos los {len(initial_selection)} generadores válidos.")
    elif selection_mode == "FIRST":
        if available_gen_names:
            initial_selection = [available_gen_names[0]]
            print(f"Modo FIRST: Se considerará el primer generador válido: {initial_selection[0]}")
        else:
             print("Error: Modo FIRST pero no hay generadores válidos disponibles.")
             return None, None
    elif selection_mode == "SPECIFIC":
        if not specific_generator:
            print("Error: Modo SPECIFIC pero no se especificó 'SPECIFIC_GENERATOR_NAME'.")
            return None, None
        if prefix_to_exclude and specific_generator.startswith(prefix_to_exclude):
             print(f"Error: Generador específico '{specific_generator}' está excluido por prefijo '{prefix_to_exclude}'.")
             return None, None
        if specific_generator in valid_generators_for_year:
            initial_selection = [specific_generator]
            print(f"Modo SPECIFIC: Se considerará el generador: {specific_generator}")
        else:
            print(f"Error: Generador específico '{specific_generator}' no tiene datos base válidos para {year} o no existe.")
            print(f"Generadores válidos disponibles: {', '.join(available_gen_names[:10])}...")
            return None, None
    else:
        print(f"Error: Modo de selección '{selection_mode}' no reconocido.")
        return None, None

    if not initial_selection:
         print("Advertencia: Ningún generador seleccionado después de aplicar el modo.")
         return {}, {} # Devolver vacío pero no None

    # 3. Determinar representantes y mapeo para la selección inicial
    print("Determinando representantes de grupo (Zona, Tipo) para la selección...")
    representatives_needed = set() # Nombres de los generadores para los que SÍ hay que generar perfil
    temp_gen_to_rep_map = {} # Mapeo temporal solo para la selección

    for gen_name in initial_selection:
        # Necesitamos obtener tipo y zona del primer mes válido encontrado para este generador en el año
        gen_year_data = valid_generators_for_year.get(gen_name)
        if not gen_year_data: continue # Debería existir por la lógica anterior

        first_valid_month = next((m for m in range(1, 13) if m in gen_year_data), None)
        if first_valid_month is None:
            print(f"Advertencia: Generador {gen_name} no tiene datos válidos en ningún mes de {year}. Saltando.")
            continue

        gen_info_month = gen_year_data[first_valid_month]
        gen_type = gen_info_month.get('type', 'OTHER')
        load_zone = gen_info_month.get('load_zone', 'UNKNOWN_ZONE')

        if gen_type in ['PV', 'WIND']:
            group_key = (load_zone, gen_type)
            if group_key not in representatives_chosen:
                representatives_chosen[group_key] = gen_name # Elegir este como representante
                representatives_needed.add(gen_name)
                print(f"  -> Grupo {group_key}: Representante elegido = {gen_name}")
            # Mapear este generador a su representante (sea él mismo o uno anterior)
            temp_gen_to_rep_map[gen_name] = representatives_chosen[group_key]
        else: # Tipo 'OTHER'
            representatives_needed.add(gen_name) # Se procesa individualmente
            temp_gen_to_rep_map[gen_name] = gen_name # Es su propio representante
            print(f"  -> Generador {gen_name} (Tipo: {gen_type}): Se procesará individualmente.")

    generators_to_process = sorted(list(representatives_needed))
    print(f"Se generarán perfiles sintéticos para {len(generators_to_process)} generadores (representantes y 'OTHER').")
    if not generators_to_process:
        print("Advertencia: No se seleccionó ningún generador representativo o 'OTHER' para procesar.")
        return {}, {}

    # 4. Generar perfiles SÓLO para los generadores en generators_to_process
    print(f"\nGenerando perfiles sintéticos para los {len(generators_to_process)} generadores seleccionados...")
    generadores_procesados_count = 0
    for generador_rep in generators_to_process:
        print(f"  Procesando representante/individual: {generador_rep}")
        perfiles_sinteticos_representantes[generador_rep] = {}
        data_meses_base = valid_generators_for_year.get(generador_rep) # Usar datos del año validados
        if not data_meses_base:
             print(f"    Error Interno: No se encontraron datos base para {generador_rep} aunque debería existir. Saltando.")
             continue

        generadores_procesados_count += 1
        last_valid_profile_info = None # Para rellenar meses faltantes

        for month in range(1, 13):
            month_data = data_meses_base.get(month)
            perfil_base_mes = None
            tipo_generador = None
            load_zone_rep = None # Zona del representante

            if month_data and isinstance(month_data, dict) and 'profile' in month_data and 'type' in month_data:
                perfil_base_mes = month_data['profile']
                tipo_generador = month_data['type']
                load_zone_rep = month_data.get('load_zone', 'UNKNOWN_ZONE')
                last_valid_profile_info = month_data # Guardar por si el siguiente mes falta
            else:
                # Usar datos del último mes válido si existen
                if last_valid_profile_info:
                    # print(f"    Advertencia: Faltan datos base para {generador_rep}, Mes {month}. Usando perfil del mes anterior.")
                    perfil_base_mes = last_valid_profile_info['profile']
                    tipo_generador = last_valid_profile_info['type']
                    load_zone_rep = last_valid_profile_info.get('load_zone', 'UNKNOWN_ZONE')
                else:
                    # Si no hay datos ni anteriores, usar ceros y tipo 'OTHER'
                    # print(f"    Advertencia: Faltan datos base para {generador_rep}, Mes {month} (y sin datos previos). Usando perfil de ceros.")
                    perfil_base_mes = [0.0] * 24
                    # Intentar obtener el tipo del primer mes válido si es posible, sino 'OTHER'
                    first_month_info = next((data_meses_base[m] for m in range(1,13) if m in data_meses_base), None)
                    tipo_generador = first_month_info['type'] if first_month_info else 'OTHER'
                    load_zone_rep = first_month_info['load_zone'] if first_month_info else 'UNKNOWN_ZONE'


            try:
                dias_del_mes = monthrange(year, month)[1]
            except ValueError:
                print(f"    Error: Mes inválido ({month}) para {generador_rep}, {year}. Saltando mes.")
                continue

            # Generar perfiles sintéticos para el mes usando la cópula
            # print(f"      -> Generando {dias_del_mes} perfiles sintéticos ({tipo_generador}) para Mes {month}/{year}...")
            perfiles_sinteticos_mes = generar_perfiles_sinteticos_con_copula(
                perfil_base_mes, tipo_generador, dias_del_mes, N_SAMPLES_COPULA
            )

            # Validar y almacenar los perfiles diarios generados
            if isinstance(perfiles_sinteticos_mes, list) and len(perfiles_sinteticos_mes) == dias_del_mes:
                 # is_not_all_zeros = any(any(abs(val) > 1e-6 for val in profile) for profile in perfiles_sinteticos_mes)
                 # if is_not_all_zeros:
                 #      print(f"        -> OK: Generados {len(perfiles_sinteticos_mes)} perfiles ({tipo_generador}).")
                 # else:
                 #      print(f"        -> OK: Generados {len(perfiles_sinteticos_mes)} perfiles ({tipo_generador}), pero son nulos/constantes.")

                 for day_index in range(dias_del_mes):
                    try:
                        current_date = date(year, month, day_index + 1)
                        daily_profile = perfiles_sinteticos_mes[day_index]
                        if isinstance(daily_profile, list) and len(daily_profile) == 24:
                            perfiles_sinteticos_representantes[generador_rep][current_date] = daily_profile
                        else:
                            print(f"    Error: Perfil diario inválido generado ({tipo_generador}) para {current_date} (Gen {generador_rep}). Usando ceros.")
                            perfiles_sinteticos_representantes[generador_rep][current_date] = [0.0] * 24
                    except ValueError:
                        # Esto no debería ocurrir si monthrange funcionó
                        print(f"    Error: Fecha inválida {year}-{month}-{day_index + 1} para {generador_rep}.")
            else:
                # Si la generación falló (ya imprimió error interno), asignar ceros
                print(f"    Error: Falló la generación ({tipo_generador}) Mes {month}/{year} (Gen {generador_rep}). Asignando ceros para {dias_del_mes} días.")
                for day_index in range(dias_del_mes):
                    try:
                        current_date = date(year, month, day_index + 1)
                        perfiles_sinteticos_representantes[generador_rep][current_date] = [0.0] * 24
                    except ValueError:
                         print(f"    Error: Fecha inválida {year}-{month}-{day_index + 1} para {generador_rep} (ceros).")

    print(f"Generación de perfiles sintéticos completada para {generadores_procesados_count} generador(es) representantes/individuales.")

    # 5. Construir el mapeo final de TODOS los generadores válidos a su representante
    print("Construyendo mapeo final generador -> representante...")
    final_generator_to_representative_map = {}
    representatives_used = set()
    groups_mapped = {} # (load_zone, type) -> representative_gen_name

    for gen_name in available_gen_names: # Iterar sobre todos los generadores válidos originales
        gen_year_data = valid_generators_for_year.get(gen_name)
        if not gen_year_data: continue
        first_valid_month = next((m for m in range(1, 13) if m in gen_year_data), None)
        if first_valid_month is None: continue

        gen_info_month = gen_year_data[first_valid_month]
        gen_type = gen_info_month.get('type', 'OTHER')
        load_zone = gen_info_month.get('load_zone', 'UNKNOWN_ZONE')

        if gen_type in ['PV', 'WIND']:
            group_key = (load_zone, gen_type)
            # Encontrar el representante que SÍ fue procesado (debería estar en representatives_chosen)
            representative_gen = representatives_chosen.get(group_key)
            if representative_gen and representative_gen in perfiles_sinteticos_representantes:
                 final_generator_to_representative_map[gen_name] = representative_gen
                 representatives_used.add(representative_gen)
                 if group_key not in groups_mapped:
                      # print(f"  Mapeando Grupo {group_key} -> Representante {representative_gen}")
                      groups_mapped[group_key] = representative_gen
            # else:
                 # print(f"Advertencia: No se encontró representante procesado para el grupo {group_key} del generador {gen_name}. No se mapeará.")
        else: # Tipo 'OTHER'
             # Solo mapear si fue procesado
             if gen_name in perfiles_sinteticos_representantes:
                  final_generator_to_representative_map[gen_name] = gen_name
                  representatives_used.add(gen_name)
             # else:
                  # Esto podría pasar si era 'OTHER' pero no estaba en la selección inicial (e.g., modo SPECIFIC)
                  # print(f"Advertencia: Generador 'OTHER' {gen_name} no fue procesado (probablemente fuera de selección). No se mapeará.")

    print(f"Mapeo final construido. {len(final_generator_to_representative_map)} generadores mapeados a {len(representatives_used)} representantes con perfiles generados.")

    if not perfiles_sinteticos_representantes:
         print("Advertencia: No se generaron perfiles sintéticos para ningún representante.")
         # return None, None # Podríamos detenernos aquí si es crítico

    return perfiles_sinteticos_representantes, final_generator_to_representative_map
# ====== FIN FUNCIÓN MODIFICADA ======


# ====== FUNCIÓN MODIFICADA ======
def asignar_perfiles_capacidad_a_archivos(perfiles_sinteticos_representantes, generator_to_representative_map, base_path, year, prefix_to_exclude=None):
    """
    Asigna los perfiles sintéticos (usando el mapeo de representantes) a los
    archivos CSV diarios 'variable_capacity_factors.csv'.
    """
    print(f"\nIniciando asignación de perfiles sintéticos (vía representantes) a los archivos para el año {year}...")
    if prefix_to_exclude:
        print(f"Se saltarán las filas de generadores que comiencen con: '{prefix_to_exclude}' durante la asignación.")
    if not perfiles_sinteticos_representantes:
        print("Advertencia: No hay perfiles sintéticos de representantes generados para asignar.")
        return
    if not generator_to_representative_map:
        print("Advertencia: El mapeo generador -> representante está vacío. No se puede asignar.")
        return

    representantes_con_perfiles = list(perfiles_sinteticos_representantes.keys())
    print(f"Se usarán perfiles de {len(representantes_con_perfiles)} representante(s): {', '.join(sorted(representantes_con_perfiles))[:200]}...")
    print(f"Se intentará asignar perfiles a {len(generator_to_representative_map)} generadores mapeados.")

    num_days_in_year = 366 if monthrange(year, 2)[1] == 29 else 365
    archivos_procesados = 0
    archivos_no_encontrados = 0
    total_filas_actualizadas = 0
    total_filas_leidas = 0
    total_filas_excluidas_prefijo = 0
    total_errores_parseo = 0
    total_perfiles_no_encontrados_rep = 0 # Perfil del representante no encontrado para la fecha
    total_generadores_no_mapeados = 0 # Generadores en archivo sin representante mapeado
    updates_por_generador_final = {} # Contará las actualizaciones por generador final

    for day_folder_index in range(num_days_in_year):
        # Construir la ruta al archivo diario
        # Asegurarse que el índice de la carpeta coincida con la convención (0 a 364/365)
        # Nota: Si las carpetas se llaman 1 a 365/366, ajustar el str(day_folder_index + 1)
        archivo_ruta = os.path.join(base_path, f"inputs_{year}", str(day_folder_index), "inputs_dispatch", "variable_capacity_factors.csv")

        if not os.path.exists(archivo_ruta):
            archivos_no_encontrados += 1
            # print(f"  Archivo no encontrado: {archivo_ruta}") # Opcional: imprimir cada archivo faltante
            continue

        try:
            df_dia = pd.read_csv(archivo_ruta)
            # Validar columnas esenciales del archivo diario
            required_daily_cols = ['GENERATION_PROJECT', 'timepoint', 'gen_max_capacity_factor']
            if not all(col in df_dia.columns for col in required_daily_cols):
                 print(f"  Error: Faltan columnas {required_daily_cols} en {archivo_ruta}. Saltando archivo.")
                 continue

            df_dia['timepoint'] = df_dia['timepoint'].astype(str) # Asegurar que timepoint es string
            archivos_procesados += 1
        except Exception as e:
            print(f"  Error al leer {archivo_ruta}: {e}. Saltando archivo.")
            continue

        # Añadir columna temporal para nuevos valores
        df_dia['nueva_capacidad'] = np.nan
        updates_count_file = 0
        parse_errors_file = 0
        profile_not_found_rep_file = 0
        excluded_prefix_file = 0
        not_mapped_file = 0

        # Iterar por las filas del archivo diario
        for index, row in df_dia.iterrows():
            generador_fila = row['GENERATION_PROJECT']
            timepoint_str = row['timepoint']
            total_filas_leidas += 1

            # 1. Aplicar exclusión por prefijo (si aplica)
            if prefix_to_exclude and generador_fila.startswith(prefix_to_exclude):
                excluded_prefix_file += 1
                continue

            # 2. Encontrar el representante para este generador
            representative_gen = generator_to_representative_map.get(generador_fila)

            if representative_gen is None:
                # Este generador no estaba en el mapeo (quizás no tenía datos base, o fue excluido antes)
                not_mapped_file += 1
                continue # No podemos asignarle perfil

            # 3. Parsear el timepoint para obtener fecha y hora
            actual_date, target_hour = parse_timepoint(timepoint_str)
            if actual_date is None or target_hour is None:
                parse_errors_file += 1
                # print(f"    Error parseando timepoint '{timepoint_str}' para generador {generador_fila} en {archivo_ruta}")
                continue # Saltar esta fila si el timepoint es inválido

            # 4. Obtener el perfil sintético del REPRESENTANTE para esa fecha
            perfiles_representante_actual = perfiles_sinteticos_representantes.get(representative_gen, {})
            perfil_correcto_rep = perfiles_representante_actual.get(actual_date)

            # 5. Asignar el valor si el perfil del representante existe y es válido
            if perfil_correcto_rep and isinstance(perfil_correcto_rep, list) and len(perfil_correcto_rep) == 24:
                try:
                    valor_correcto = perfil_correcto_rep[target_hour]
                    # Asignar a la columna temporal
                    df_dia.loc[index, 'nueva_capacidad'] = valor_correcto
                    updates_count_file += 1
                    # Contar actualización para el generador FINAL
                    updates_por_generador_final[generador_fila] = updates_por_generador_final.get(generador_fila, 0) + 1
                except IndexError:
                     print(f"    Error de índice: Hora {target_hour} fuera de rango para perfil de {representative_gen} en fecha {actual_date}. Fila saltada.")
                     parse_errors_file += 1 # Considerarlo un error de datos/parseo
            else:
                # El perfil del representante para esta fecha específica no se encontró o era inválido
                profile_not_found_rep_file += 1
                # print(f"    Perfil sintético no encontrado/inválido para representante {representative_gen} en fecha {actual_date} (requerido por {generador_fila}).")

        # 6. Actualizar la columna original 'gen_max_capacity_factor' con los valores de 'nueva_capacidad' donde no son NaN
        mask_actualizar = df_dia['nueva_capacidad'].notna()
        df_dia['gen_max_capacity_factor'] = df_dia['nueva_capacidad'].where(mask_actualizar, df_dia['gen_max_capacity_factor'])

        # Actualizar contadores globales
        total_filas_actualizadas += updates_count_file
        total_filas_excluidas_prefijo += excluded_prefix_file
        total_errores_parseo += parse_errors_file
        total_perfiles_no_encontrados_rep += profile_not_found_rep_file
        total_generadores_no_mapeados += not_mapped_file

        # 7. Guardar el DataFrame modificado (sin la columna temporal)
        try:
            df_dia_guardar = df_dia.drop(columns=['nueva_capacidad'], errors='ignore')
            df_dia_guardar.to_csv(archivo_ruta, index=False)
        except Exception as e:
            print(f"  Error Crítico al guardar {archivo_ruta}: {e}")
            # Considerar qué hacer aquí, ¿detener el proceso?

    # Imprimir resumen final de la asignación
    print("\n" + "-" * 30)
    print("Resumen de la asignación de capacidad (por representantes):")
    print(f"  Archivos diarios procesados: {archivos_procesados}")
    print(f"  Archivos diarios no encontrados/saltados: {archivos_no_encontrados}")
    print(f"  Total filas leídas en archivos procesados: {total_filas_leidas}")
    if prefix_to_exclude:
        print(f"  Total filas saltadas (prefijo '{prefix_to_exclude}'): {total_filas_excluidas_prefijo}")
    print(f"  Total filas de generadores no mapeados a un representante: {total_generadores_no_mapeados}")
    print(f"  Total errores de parseo timepoint: {total_errores_parseo}")
    print(f"  Total perfiles de representante no encontrados/inválidos para fecha/hora: {total_perfiles_no_encontrados_rep}")
    print(f"  Total filas actualizadas con éxito: {total_filas_actualizadas}")
    print("  Actualizaciones por generador final:")
    gens_actualizados_count = 0
    # Ordenar por nombre de generador para la salida
    for gen, count in sorted(updates_por_generador_final.items()):
        if count > 0:
            # Opcional: mostrar el representante usado
            # rep = generator_to_representative_map.get(gen, "N/A")
            # print(f"    - {gen} (Rep: {rep}): {count}")
            print(f"    - {gen}: {count}")
            gens_actualizados_count += 1
    if gens_actualizados_count == 0:
        print("    - Ningún generador fue actualizado.")
    else:
         print(f"  ({gens_actualizados_count} generadores finales recibieron actualizaciones)")
    print("-" * 30)
    print("Asignación de perfiles de capacidad completada.")

# ====== FIN FUNCIÓN MODIFICADA ======


# ====== FUNCIÓN MODIFICADA ======
def ejecutar_proceso_capacidad(year, base_path, capacity_factor_input_file, gen_info_input_file, selection_mode, specific_generator=None, prefix_to_exclude=None):
    """Orquesta la ejecución completa del proceso optimizado."""
    print("=" * 50)
    print(f"Iniciando proceso OPTIMIZADO de generación de perfiles de CAPACIDAD para el año {year}")
    print(f"Modo de selección de generador: {selection_mode}")
    if selection_mode == "SPECIFIC":
        print(f"Generador específico objetivo: {specific_generator if specific_generator else 'NO ESPECIFICADO'}")
    if prefix_to_exclude:
        print(f"Prefijo de exclusión: '{prefix_to_exclude}'")
    print("=" * 50)

    # 1. Cargar y preparar datos base (ahora incluye tipo y zona)
    base_profiles_capacity = cargar_y_preparar_datos_capacidad(
        capacity_factor_input_file, gen_info_input_file, prefix_to_exclude
    )
    if base_profiles_capacity is None:
        print("\nProceso detenido: Error en la carga y preparación de datos base.")
        return

    # 2. Generar perfiles sintéticos (solo para representantes) y obtener mapeo
    perfiles_sinteticos_representantes, generator_to_representative_map = generar_todos_perfiles_capacidad_sinteticos(
        base_profiles_capacity, year, selection_mode, specific_generator, prefix_to_exclude
    )

    if perfiles_sinteticos_representantes is None or generator_to_representative_map is None:
        print("\nProceso detenido: Error durante la generación de perfiles sintéticos o mapeo.")
        return
    if not perfiles_sinteticos_representantes:
         print("\nAdvertencia: No se generaron perfiles sintéticos para ningún representante. La asignación no se ejecutará.")
         # Decidir si continuar o no. Por ahora, terminamos.
         print("=" * 50); print(f"Proceso de CAPACIDAD para el año {year} (Modo: {selection_mode}) finalizado (sin asignación)."); print("=" * 50)
         return
    if not generator_to_representative_map:
         print("\nAdvertencia: No se creó el mapeo generador -> representante. La asignación no se ejecutará.")
         print("=" * 50); print(f"Proceso de CAPACIDAD para el año {year} (Modo: {selection_mode}) finalizado (sin asignación)."); print("=" * 50)
         return


    # 3. Asignar perfiles a archivos usando el mapeo
    asignar_perfiles_capacidad_a_archivos(
        perfiles_sinteticos_representantes, generator_to_representative_map, base_path, year, prefix_to_exclude
    )

    print("\n" + "=" * 50)
    print(f"Proceso OPTIMIZADO de CAPACIDAD para el año {year} (Modo: {selection_mode}) finalizado.")
    print("=" * 50)
# ====== FIN FUNCIÓN MODIFICADA ======


# --- Punto de Entrada ---
if __name__ == "__main__":
    # Configurar warnings para ignorar los comunes en pandas y numpy/copulas
    warnings.simplefilter(action='ignore', category=FutureWarning)
    warnings.simplefilter(action='ignore', category=pd.errors.SettingWithCopyWarning)
    warnings.simplefilter(action='ignore', category=RuntimeWarning) # Ignorar RuntimeWarnings generales (pueden venir de cópulas)
    warnings.simplefilter(action='ignore', category=UserWarning) # Ignorar UserWarnings (pueden venir de cópulas)


    # Leer configuración global
    target_year_run = TARGET_YEAR
    base_path_run = BASE_PATH
    capacity_factor_file_run = CAPACITY_FACTOR_INPUT_FILE
    gen_info_file_run = GEN_INFO_INPUT_FILE
    modo_ejecucion = GENERATOR_SELECTION_MODE
    generador_especifico_run = SPECIFIC_GENERATOR_NAME if modo_ejecucion == "SPECIFIC" else None
    prefijo_a_excluir_run = PREFIX_TO_EXCLUDE

    # Validación básica de configuración
    error_config = False
    if modo_ejecucion not in ["ALL", "FIRST", "SPECIFIC"]:
        print(f"ERROR CONFIG: Modo de selección '{modo_ejecucion}' inválido. Use 'ALL', 'FIRST' o 'SPECIFIC'.")
        error_config = True
    elif modo_ejecucion == "SPECIFIC":
        if not generador_especifico_run:
            print("ERROR CONFIG: Modo 'SPECIFIC' seleccionado pero 'SPECIFIC_GENERATOR_NAME' está vacío.")
            error_config = True
        # La validación de si el generador específico es excluido por prefijo se hará dentro de la lógica principal

    # Ejecutar el proceso si la configuración es válida
    if not error_config:
        ejecutar_proceso_capacidad(
            target_year_run,
            base_path_run,
            capacity_factor_file_run,
            gen_info_file_run,
            modo_ejecucion,
            generador_especifico_run, # Pasa None si no es SPECIFIC
            prefijo_a_excluir_run
        )
    else:
        print("\nProceso no ejecutado debido a errores de configuración.")
