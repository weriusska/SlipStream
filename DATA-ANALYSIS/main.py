import os
import re
import numpy as np
import pandas as pd
import fastf1
from fastf1 import utils
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 1. Włączamy lokalny Cache dla FastF1
os.makedirs('cache', exist_ok=True)
fastf1.Cache.enable_cache('cache')

LOCATION_FIXES = {
    "Monte Carlo": "Monaco",
    "Yas Island": "Yas Marina",
    "Singapore": "Marina Bay",
    "Miami Gardens": "Miami",
}


def create_slug(location_name: str) -> str:
    """
    Generuje nazwy dokładnie pod przygotowaną listę assetów:
    - São Paulo -> sao_paulo
    - Portimão -> portimao
    - Nürburgring -> nurburgring
    - Montréal -> montr_al
    """
    slug = location_name.lower()
    slug = slug.replace("ã", "a").replace("ó", "o").replace("ü", "u")
    slug = re.sub(r'[^a-z0-9]+', '_', slug).strip('_')
    return slug


def normalize_session_type(session_str: str) -> str:
    """Tłumaczy dowolną nazwę sesji z Fluttera na kod rozumiany przez FastF1."""
    s = session_str.strip().lower()
    if s in ['fp1', 'practice 1']:
        return 'FP1'
    if s in ['fp2', 'practice 2']:
        return 'FP2'
    if s in ['fp3', 'practice 3']:
        return 'FP3'
    if s in ['sq', 'ss', 'sprint qualifying', 'sprint shootout']:
        return 'SQ'
    if s in ['s', 'sprint']:
        return 'S'
    if s in ['q', 'qualifying', 'qualifications']:
        return 'Q'
    if s in ['r', 'race']:
        return 'R'
    return session_str


def format_lap_time(td) -> str:
    """Zamienia obiekt Timedelta z Pandas na czytelny string np. '1:21.345'."""
    if td is None or pd.isna(td):
        return "N/A"
    try:
        total_seconds = td.total_seconds()
        if np.isnan(total_seconds):
            return "N/A"
        minutes = int(total_seconds // 60)
        seconds = total_seconds % 60
        return f"{minutes}:{seconds:06.3f}"
    except Exception:
        return "N/A"


def clean_team_color(raw_color) -> str:
    """Zwraca zawsze poprawny kod HEX z '#' na początku."""
    if pd.isna(raw_color) or not str(raw_color).strip() or str(raw_color).lower() == 'nan':
        return "#FFFFFF"
    c = str(raw_color).strip()
    return f"#{c}" if not c.startswith('#') else c


@app.get("/api/races")
def get_races(year: int):
    try:
        schedule = fastf1.get_event_schedule(year)
        races_df = schedule[schedule['RoundNumber'] > 0]
        results = []

        for _, row in races_df.iterrows():
            raw_location = str(row['Location'])
            location = LOCATION_FIXES.get(raw_location, raw_location)
            slug = create_slug(location)

            sessions = []
            for i in range(1, 6):
                session_name = row.get(f'Session{i}')
                if not pd.isna(session_name) and str(session_name).strip().lower() not in ['nan', 'none', 'nat', '']:
                    sessions.append(str(session_name))

            results.append({
                "id": int(row['RoundNumber']),
                "name": location.upper(),
                "image_slug": slug,
                "sessions": sessions
            })

        return results

    except Exception as e:
        return {"error": str(e)}


@app.get("/api/drivers")
def get_drivers(year: int, location: str, session_type: str):
    try:
        norm_session = normalize_session_type(session_type)
        # Jeśli location to liczba (RoundNumber), konwertujemy na int, inaczej czyścimy string
        loc_query = int(location) if location.isdigit() else location.title()

        session = fastf1.get_session(year, loc_query, norm_session)
        session.load(telemetry=False, laps=False, weather=False)

        drivers_list = []
        for _, row in session.results.iterrows():
            pos_val = row.get('Position')
            position = 0 if pd.isna(pos_val) else int(pos_val)

            drivers_list.append({
                "position": position,
                "driver_number": str(row.get('DriverNumber', '')),
                "full_name": str(row.get('FullName', '')),
                "broadcast_name": str(row.get('BroadcastName', '')),
                "abbreviation": str(row.get('Abbreviation', '')),
                "team_name": str(row.get('TeamName', '')),
                "team_color": clean_team_color(row.get('TeamColor'))
            })

        return drivers_list

    except Exception as e:
        return {"error": str(e)}


@app.get("/api/telemetry")
def get_telemetry(year: int, location: str, session_type: str, driver: str):
    try:
        norm_session = normalize_session_type(session_type)
        loc_query = int(location) if location.isdigit() else location.title()

        session = fastf1.get_session(year, loc_query, norm_session)
        session.load(telemetry=True, laps=True, weather=False, messages=False)

        driver_clean = str(driver).strip().upper()
        driver_info = session.results[
            (session.results['Abbreviation'] == driver_clean) |
            (session.results['DriverNumber'] == driver_clean)
        ]

        if driver_info.empty:
            return {"error": f"Kierowca '{driver}' nie brał udziału w tej sesji."}

        row = driver_info.iloc[0]
        abbr = str(row['Abbreviation'])
        pos_val = row.get('Position')
        position = 0 if pd.isna(pos_val) else int(pos_val)

        driver_laps = session.laps.pick_drivers(abbr)
        if driver_laps.empty:
            return {"error": "Brak zarejestrowanych okrążeń dla tego kierowcy."}

        fastest_lap = driver_laps.pick_fastest()

        response_data = {
            "driver_number": str(row.get('DriverNumber', '')),
            "full_name": str(row.get('FullName', '')),
            "abbreviation": abbr,
            "team_name": str(row.get('TeamName', '')),
            "team_color": clean_team_color(row.get('TeamColor')),
            "position": position,
            "session_type": norm_session,
            "fastest_lap_time": format_lap_time(fastest_lap['LapTime']) if fastest_lap is not None else "N/A",
            "fastest_lap_number": int(fastest_lap['LapNumber']) if fastest_lap is not None and not pd.isna(fastest_lap.get('LapNumber')) else 0,
        }

        # TRYB 1: WYŚCIG ('R') -> Historia okrążeń i mieszanki opon
        if norm_session == 'R':
            laps_data = []
            for _, lap in driver_laps.iterrows():
                lap_time_td = lap.get('LapTime')
                if not pd.isna(lap_time_td):
                    sec = lap_time_td.total_seconds()
                    if not np.isnan(sec) and sec < 250:
                        laps_data.append({
                            "lap_number": int(lap['LapNumber']),
                            "lap_time_s": round(sec, 3),
                            "lap_time_str": format_lap_time(lap_time_td),
                            "compound": str(lap.get('Compound', 'UNKNOWN')),
                            "is_pit": bool(not pd.isna(lap.get('PitInTime')) or not pd.isna(lap.get('PitOutTime')))
                        })
            response_data["mode"] = "RACE"
            response_data["laps"] = laps_data
            return response_data

        # TRYB 2: KWALIFIKACJE / TRENINGI / SPRINT -> Telemetria najszybszego okrążenia
        else:
            if fastest_lap is None or pd.isna(fastest_lap.get('LapTime')):
                return {"error": "Kierowca nie ustanowił czasu okrążenia w tej sesji."}

            telemetry = fastest_lap.get_car_data().add_distance()
            telemetry_sampled = telemetry.iloc[::4]

            points = []
            for _, pt in telemetry_sampled.iterrows():
                points.append({
                    "d": round(float(pt['Distance']), 1),
                    "s": int(pt['Speed']),
                    "t": int(pt['Throttle']),
                    "b": 100 if pt['Brake'] else 0,
                    "g": int(pt['nGear'])
                })

            response_data["mode"] = "TELEMETRY"
            response_data["telemetry"] = points
            return response_data

    except Exception as e:
        return {"error": str(e)}


@app.get("/api/compare")
def compare_drivers(year: int, location: str, session_type: str, driver1: str, driver2: str):
    """
    Porównuje dwóch kierowców (Head-to-Head) i wylicza krzywą Time Delta (zysk/strata czasu na torze).
    """
    try:
        norm_session = normalize_session_type(session_type)
        loc_query = int(location) if location.isdigit() else location.title()

        session = fastf1.get_session(year, loc_query, norm_session)
        session.load(telemetry=True, laps=True, weather=False, messages=False)

        def resolve_driver(d_str: str):
            clean = str(d_str).strip().upper()
            info = session.results[
                (session.results['Abbreviation'] == clean) |
                (session.results['DriverNumber'] == clean)
            ]
            if info.empty:
                return None, None
            r = info.iloc[0]
            abbr = str(r['Abbreviation'])
            laps = session.laps.pick_drivers(abbr)
            return r, laps

        row1, laps1 = resolve_driver(driver1)
        row2, laps2 = resolve_driver(driver2)

        if row1 is None or row2 is None:
            return {"error": "Nie znaleziono jednego z kierowców w tej sesji."}

        lap1 = laps1.pick_fastest()
        lap2 = laps2.pick_fastest()

        if lap1 is None or lap2 is None or pd.isna(lap1.get('LapTime')) or pd.isna(lap2.get('LapTime')):
            return {"error": "Brak ważnego najszybszego okrążenia dla jednego z kierowców."}

        # Obliczamy różnicę czasu (Time Delta) między okrążeniem 1 (baza) a okrążeniem 2 (rywal)
        delta_time, ref_tel, compare_tel = utils.delta_time(lap1, lap2)

        # Downsampling co 4. punkt dla płynności 60 FPS we Flutterze
        step = 4
        delta_points = []
        for idx in range(0, len(ref_tel), step):
            d_val = float(delta_time.iloc[idx]) if not pd.isna(delta_time.iloc[idx]) else 0.0
            delta_points.append({
                "d": round(float(ref_tel['Distance'].iloc[idx]), 1),
                "s1": int(ref_tel['Speed'].iloc[idx]),
                "s2": int(compare_tel['Speed'].iloc[idx]),
                "delta": round(d_val, 3)  # Wartość > 0 oznacza, że driver2 jest wolniejszy; < 0 że szybszy
            })

        return {
            "driver1": {
                "abbreviation": str(row1['Abbreviation']),
                "full_name": str(row1.get('FullName', '')),
                "team_color": clean_team_color(row1.get('TeamColor')),
                "lap_time": format_lap_time(lap1['LapTime'])
            },
            "driver2": {
                "abbreviation": str(row2['Abbreviation']),
                "full_name": str(row2.get('FullName', '')),
                "team_color": clean_team_color(row2.get('TeamColor')),
                "lap_time": format_lap_time(lap2['LapTime'])
            },
            "comparison": delta_points
        }

    except Exception as e:
        return {"error": str(e)}