import logging
import os
import re
import traceback
import numpy as np
import pandas as pd
import fastf1
from fastf1 import utils
from fastf1.exceptions import DataNotLoadedError
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

logger = logging.getLogger("slipstream")
fastf1.set_log_level("WARNING")

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 1. Włączamy lokalny Cache dla FastF1 (ścieżka bezwzględna względem main.py)
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CACHE_DIR = os.path.join(BASE_DIR, "cache")
os.makedirs(CACHE_DIR, exist_ok=True)
fastf1.Cache.enable_cache(CACHE_DIR)

# Opcjonalny token F1 TV (od października 2026 livetiming.formula1.com/static wymaga autoryzacji)
if os.environ.get("F1TV_TOKEN"):
    fastf1._api.headers["Authorization"] = f"Bearer {os.environ['F1TV_TOKEN']}"

OPENF1_BASE_URL = "https://api.openf1.org/v1"

OPENF1_SESSION_NAMES = {
    "FP1": "Practice 1",
    "FP2": "Practice 2",
    "FP3": "Practice 3",
    "Q": "Qualifying",
    "SQ": "Sprint Qualifying",
    "S": "Sprint",
    "R": "Race",
}

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


TEAM_COLOR_FALLBACKS = {
    "ferrari": "#E80020",
    "mclaren": "#FF8000",
    "red bull": "#3671C6",
    "mercedes": "#27F4D2",
    "aston martin": "#229971",
    "alpine": "#0093CC",
    "williams": "#64C4FF",
    "rb": "#6692FF",
    "racing bulls": "#6692FF",
    "alphatauri": "#5E8FAA",
    "haas": "#B6BABD",
    "sauber": "#52E252",
    "kick sauber": "#52E252",
    "alfa romeo": "#C92D4B",
    "renault": "#FFF500",
    "racing point": "#F596C8",
    "toro rosso": "#469BFF",
    "audi": "#52E252",
    "cadillac": "#1E3D59",
}


def clean_team_color(raw_color, team_name: str = "") -> str:
    """Zwraca zawsze poprawny kod HEX z '#' na początku (z fallbackiem po nazwie zespołu)."""
    if not (pd.isna(raw_color) or not str(raw_color).strip() or str(raw_color).lower() == 'nan'):
        c = str(raw_color).strip()
        return f"#{c}" if not c.startswith('#') else c
    t_lower = str(team_name or "").lower()
    for key, hex_col in TEAM_COLOR_FALLBACKS.items():
        if key in t_lower:
            return hex_col
    return "#FFFFFF"


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
        _load_session_with_fallback(session, year, norm_session, need_laps=False, need_telemetry=False)

        drivers_list = []
        for _, row in session.results.iterrows():
            pos_val = row.get('Position')
            position = 0 if pd.isna(pos_val) else int(pos_val)
            team_name = str(row.get('TeamName', ''))

            drivers_list.append({
                "position": position,
                "driver_number": str(row.get('DriverNumber', '')),
                "full_name": str(row.get('FullName', '')),
                "broadcast_name": str(row.get('BroadcastName', '')),
                "abbreviation": str(row.get('Abbreviation', '')),
                "team_name": team_name,
                "team_color": clean_team_color(row.get('TeamColor'), team_name)
            })

        return drivers_list

    except Exception as e:
        return {"error": str(e)}


def resolve_driver_in_session(session, driver_str: str):
    """Wyszukuje kierowcę w wynikach sesji po skrócie (np. LEC) lub numerze (np. 16)."""
    clean = str(driver_str).strip().upper()
    info = session.results[
        (session.results['Abbreviation'] == clean) |
        (session.results['DriverNumber'] == clean)
    ]
    if info.empty:
        return None
    return info.iloc[0]


def _has_cached_fastf1_laps(session) -> bool:
    """Sprawdza, czy sesja ma już pobrane dane okrążeń w lokalnym cache FastF1 (.ff1pkl)."""
    if os.environ.get("F1TV_TOKEN"):
        return True
    rel_path = session.api_path[8:].lstrip("/\\")
    pkl_path = os.path.join(CACHE_DIR, rel_path, "_extended_timing_data.ff1pkl")
    return os.path.isfile(pkl_path)


def _load_session_with_fallback(session, year: int, norm_session: str, need_laps: bool, need_telemetry: bool) -> bool:
    """
    Ładuje sesję z lokalnego cache FastF1 (.ff1pkl), a jeśli sesja nie jest w cache (i brak F1TV_TOKEN),
    pomija zablokowane endpointy livetiming.formula1.com (HTTP 401) i ładuje listę kierowców z Ergast lub OpenF1.
    Zwraca True, jeśli załadowano okrążenia FastF1.
    """
    use_fastf1 = _has_cached_fastf1_laps(session)
    if use_fastf1:
        session.load(laps=need_laps, telemetry=need_telemetry, weather=False, messages=False)
        return getattr(session, "_laps", None) is not None

    # Pomijamy martwe zapytania do livetiming.formula1.com (401) i ładujemy wyniki z Ergast/Jolpica
    session.f1_api_support = False
    session._load_drivers_results()

    # Dla treningów (FP1-FP3) lub Sprint Qualifying Ergast może nie zwracać listy kierowców -> fallback do OpenF1 /drivers
    if session.results is None or session.results.empty:
        session_key = _find_openf1_session_key(session, year, norm_session)
        if session_key:
            r = fastf1.req.Cache.requests_get(
                f"{OPENF1_BASE_URL}/drivers",
                params={"session_key": session_key},
            )
            if r.status_code == 200 and isinstance(r.json(), list) and r.json():
                rows = []
                for idx, d in enumerate(r.json(), start=1):
                    rows.append({
                        "DriverNumber": str(d.get("driver_number", "")),
                        "BroadcastName": str(d.get("broadcast_name", "")),
                        "Abbreviation": str(d.get("name_acronym", "")),
                        "TeamName": str(d.get("team_name", "")),
                        "TeamColor": str(d.get("team_colour", "")),
                        "FirstName": str(d.get("first_name", "")),
                        "LastName": str(d.get("last_name", "")),
                        "FullName": str(d.get("full_name", "")),
                        "Position": float(idx),
                    })
                df = pd.DataFrame(rows)
                df.index = df["DriverNumber"]
                session._results = fastf1.core.SessionResults(df, _force_default_cols=True)
    return False


def _find_openf1_session_key(session, year: int, norm_session: str):
    """Znajduje klucz sesji (session_key) w OpenF1 API na podstawie roku, nazwy sesji i daty."""
    target_name = OPENF1_SESSION_NAMES.get(norm_session, norm_session)
    r = fastf1.req.Cache.requests_get(
        f"{OPENF1_BASE_URL}/sessions",
        params={"year": year},
    )
    if r.status_code != 200:
        return None
    sessions = r.json()
    if not isinstance(sessions, list) or not sessions:
        return None

    # Dopasowanie nazwy sesji (uwzględniając Sprint Shootout w 2023)
    valid_names = {target_name.lower()}
    if norm_session == "SQ":
        valid_names.update({"sprint qualifying", "sprint shootout"})

    candidates = [
        s for s in sessions
        if str(s.get("session_name", "")).lower() in valid_names
    ]
    if not candidates:
        return None

    # Najbliższa sesja względem daty z harmonogramu FastF1
    target_date = pd.to_datetime(session.date).tz_localize(None)
    best = min(
        candidates,
        key=lambda s: abs(
            (pd.to_datetime(s["date_start"]).tz_localize(None) - target_date).total_seconds()
        ),
    )
    return best.get("session_key")


def _openf1_get_driver_laps(session_key: int, driver_number: int) -> list:
    r = fastf1.req.Cache.requests_get(
        f"{OPENF1_BASE_URL}/laps",
        params={"session_key": session_key, "driver_number": driver_number},
    )
    if r.status_code != 200:
        return []
    data = r.json()
    return data if isinstance(data, list) else []


def _openf1_get_driver_stints(session_key: int, driver_number: int) -> list:
    r = fastf1.req.Cache.requests_get(
        f"{OPENF1_BASE_URL}/stints",
        params={"session_key": session_key, "driver_number": driver_number},
    )
    if r.status_code != 200:
        return []
    data = r.json()
    return data if isinstance(data, list) else []


def _openf1_get_lap_telemetry(session_key: int, driver_number: int, lap: dict) -> pd.DataFrame:
    """Pobiera surowe dane czujników z OpenF1 dla pojedynczego okrążenia i wylicza dystans (Distance) oraz czas względny (RelTime)."""
    start_dt = pd.to_datetime(lap["date_start"])
    duration = float(lap["lap_duration"])
    end_dt = start_dt + pd.to_timedelta(duration, unit="s")
    start_iso = start_dt.strftime("%Y-%m-%dT%H:%M:%S.%f")
    end_iso = end_dt.strftime("%Y-%m-%dT%H:%M:%S.%f")

    url = (
        f"{OPENF1_BASE_URL}/car_data"
        f"?session_key={session_key}&driver_number={driver_number}"
        f"&date>={start_iso}&date<={end_iso}"
    )
    r = fastf1.req.Cache.requests_get(url)
    if r.status_code != 200:
        return pd.DataFrame()
    records = r.json()
    if not isinstance(records, list) or not records:
        return pd.DataFrame()

    df = pd.DataFrame(records)
    df["dt_obj"] = pd.to_datetime(df["date"])
    df = df.sort_values("dt_obj").reset_index(drop=True)

    t0 = df["dt_obj"].iloc[0]
    rel_time = (df["dt_obj"] - t0).dt.total_seconds().to_numpy()
    dt = np.diff(rel_time, prepend=0.0)
    speeds_ms = df["speed"].astype(float).to_numpy() / 3.6
    distances = np.cumsum(speeds_ms * dt)

    df["RelTime"] = rel_time
    df["Distance"] = distances
    return df


@app.get("/api/telemetry")
def get_telemetry(year: int, location: str, session_type: str, driver: str):
    try:
        norm_session = normalize_session_type(session_type)
        loc_query = int(location) if location.isdigit() else location.title()

        session = fastf1.get_session(year, loc_query, norm_session)
        need_telemetry = norm_session != 'R'
        use_fastf1_laps = _load_session_with_fallback(
            session, year, norm_session, need_laps=True, need_telemetry=need_telemetry
        )

        row = resolve_driver_in_session(session, driver)
        if row is None:
            return {"error": f"Kierowca '{driver}' nie brał udziału w tej sesji."}

        abbr = str(row['Abbreviation'])
        driver_num_str = str(row.get('DriverNumber', '')).strip()
        pos_val = row.get('Position')
        position = 0 if pd.isna(pos_val) else int(pos_val)
        team_name = str(row.get('TeamName', ''))

        response_data = {
            "driver_number": driver_num_str,
            "full_name": str(row.get('FullName', '')),
            "abbreviation": abbr,
            "team_name": team_name,
            "team_color": clean_team_color(row.get('TeamColor'), team_name),
            "position": position,
            "session_type": norm_session,
        }

        # ŚCIEŻKA A: Dane okrążeń dostępne w FastF1 (z lokalnego cache lub z tokenem F1 TV)
        if use_fastf1_laps and getattr(session, "_laps", None) is not None:
            driver_laps = session.laps.pick_drivers(abbr)
            if driver_laps.empty:
                return {"error": "Brak zarejestrowanych okrążeń dla tego kierowcy."}

            fastest_lap = driver_laps.pick_fastest()
            response_data["fastest_lap_time"] = format_lap_time(fastest_lap['LapTime']) if fastest_lap is not None else "N/A"
            response_data["fastest_lap_number"] = int(fastest_lap['LapNumber']) if fastest_lap is not None and not pd.isna(fastest_lap.get('LapNumber')) else 0

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
            else:
                if fastest_lap is None or pd.isna(fastest_lap.get('LapTime')):
                    return {"error": "Kierowca nie ustanowił czasu okrążenia w tej sesji."}

                car_data = fastest_lap.get_car_data().add_distance()
                telemetry_sampled = car_data.iloc[::4]

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

        # ŚCIEŻKA B: Fallback do OpenF1 API (gdy F1 LiveTiming zwraca HTTP 401 dla niezcachowanej sesji)
        session_key = _find_openf1_session_key(session, year, norm_session)
        if not session_key or not driver_num_str.isdigit():
            return {"error": "Brak danych telemetrii dla tej sesji w cache oraz w OpenF1 API."}

        driver_num = int(driver_num_str)
        of1_laps = _openf1_get_driver_laps(session_key, driver_num)
        valid_laps = [l for l in of1_laps if l.get("lap_duration") is not None and l.get("date_start")]
        if not valid_laps:
            return {"error": "Brak zarejestrowanych okrążeń dla tego kierowcy."}

        fastest_of1 = min(valid_laps, key=lambda l: float(l["lap_duration"]))
        fastest_td = pd.to_timedelta(float(fastest_of1["lap_duration"]), unit="s")
        response_data["fastest_lap_time"] = format_lap_time(fastest_td)
        response_data["fastest_lap_number"] = int(fastest_of1.get("lap_number", 0))

        if norm_session == 'R':
            stints = _openf1_get_driver_stints(session_key, driver_num)
            pit_in_laps = {int(s["lap_end"]) for s in stints if s.get("lap_end") is not None}

            def resolve_compound(lap_num: int) -> str:
                for s in stints:
                    l_start = s.get("lap_start") or 0
                    l_end = s.get("lap_end") or 999
                    if l_start <= lap_num <= l_end:
                        return str(s.get("compound") or "UNKNOWN")
                return "UNKNOWN"

            laps_data = []
            for lap in sorted(valid_laps, key=lambda l: int(l.get("lap_number", 0))):
                sec = float(lap["lap_duration"])
                lap_num = int(lap.get("lap_number", 0))
                if sec < 250:
                    td = pd.to_timedelta(sec, unit="s")
                    laps_data.append({
                        "lap_number": lap_num,
                        "lap_time_s": round(sec, 3),
                        "lap_time_str": format_lap_time(td),
                        "compound": resolve_compound(lap_num),
                        "is_pit": bool(lap.get("is_pit_out_lap")) or (lap_num in pit_in_laps and lap_num < len(of1_laps)),
                    })

            response_data["mode"] = "RACE"
            response_data["laps"] = laps_data
            return response_data
        else:
            car_df = _openf1_get_lap_telemetry(session_key, driver_num, fastest_of1)
            if car_df.empty:
                return {"error": "Brak danych z czujników (car_data) dla najszybszego okrążenia."}

            telemetry_sampled = car_df.iloc[::4]
            points = []
            for _, pt in telemetry_sampled.iterrows():
                points.append({
                    "d": round(float(pt["Distance"]), 1),
                    "s": int(pt["speed"]),
                    "t": int(pt["throttle"]),
                    "b": 100 if pt["brake"] else 0,
                    "g": int(pt["n_gear"]),
                })

            response_data["mode"] = "TELEMETRY"
            response_data["telemetry"] = points
            return response_data

    except DataNotLoadedError as e:
        logger.error("DataNotLoadedError w /api/telemetry (%s %s %s): %s", year, location, session_type, e)
        return {
            "error": (
                "Nie udało się załadować danych okrążeń/telemetrii dla tej sesji."
            ),
            "details": str(e),
        }
    except Exception as e:
        logger.exception("Błąd w /api/telemetry")
        return {
            "error": str(e),
            "trace": traceback.format_exc()
        }


@app.get("/api/compare")
def compare_drivers(year: int, location: str, session_type: str, driver1: str, driver2: str):
    """
    Porównuje dwóch kierowców (Head-to-Head) i wylicza krzywą Time Delta (zysk/strata czasu na torze).
    """
    try:
        norm_session = normalize_session_type(session_type)
        loc_query = int(location) if location.isdigit() else location.title()

        session = fastf1.get_session(year, loc_query, norm_session)
        use_fastf1_laps = _load_session_with_fallback(
            session, year, norm_session, need_laps=True, need_telemetry=True
        )

        row1 = resolve_driver_in_session(session, driver1)
        row2 = resolve_driver_in_session(session, driver2)

        if row1 is None or row2 is None:
            return {"error": "Nie znaleziono jednego z kierowców w tej sesji."}

        abbr1 = str(row1['Abbreviation'])
        abbr2 = str(row2['Abbreviation'])
        team1 = str(row1.get('TeamName', ''))
        team2 = str(row2.get('TeamName', ''))

        # ŚCIEŻKA A: FastF1 (gdy dane są w cache lub dostępny jest token F1 TV)
        if use_fastf1_laps and getattr(session, "_laps", None) is not None:
            laps1 = session.laps.pick_drivers(abbr1)
            laps2 = session.laps.pick_drivers(abbr2)

            lap1 = laps1.pick_fastest()
            lap2 = laps2.pick_fastest()

            if lap1 is None or lap2 is None or pd.isna(lap1.get('LapTime')) or pd.isna(lap2.get('LapTime')):
                return {"error": "Brak ważnego najszybszego okrążenia dla jednego z kierowców."}

            delta_time, ref_tel, compare_tel = utils.delta_time(lap1, lap2)

            step = 4
            delta_points = []
            for idx in range(0, len(ref_tel), step):
                d_val = float(delta_time.iloc[idx]) if not pd.isna(delta_time.iloc[idx]) else 0.0
                delta_points.append({
                    "d": round(float(ref_tel['Distance'].iloc[idx]), 1),
                    "s1": int(ref_tel['Speed'].iloc[idx]),
                    "s2": int(compare_tel['Speed'].iloc[idx]),
                    "delta": round(d_val, 3)
                })

            return {
                "driver1": {
                    "abbreviation": abbr1,
                    "full_name": str(row1.get('FullName', '')),
                    "team_color": clean_team_color(row1.get('TeamColor'), team1),
                    "lap_time": format_lap_time(lap1['LapTime'])
                },
                "driver2": {
                    "abbreviation": abbr2,
                    "full_name": str(row2.get('FullName', '')),
                    "team_color": clean_team_color(row2.get('TeamColor'), team2),
                    "lap_time": format_lap_time(lap2['LapTime'])
                },
                "comparison": delta_points
            }

        # ŚCIEŻKA B: Fallback do OpenF1 API
        session_key = _find_openf1_session_key(session, year, norm_session)
        num1_str = str(row1.get("DriverNumber", "")).strip()
        num2_str = str(row2.get("DriverNumber", "")).strip()
        if not session_key or not num1_str.isdigit() or not num2_str.isdigit():
            return {"error": "Brak danych telemetrii do porównania w cache oraz w OpenF1 API."}

        laps1_of1 = [
            l for l in _openf1_get_driver_laps(session_key, int(num1_str))
            if l.get("lap_duration") is not None and l.get("date_start")
        ]
        laps2_of1 = [
            l for l in _openf1_get_driver_laps(session_key, int(num2_str))
            if l.get("lap_duration") is not None and l.get("date_start")
        ]
        if not laps1_of1 or not laps2_of1:
            return {"error": "Brak ważnego najszybszego okrążenia dla jednego z kierowców."}

        fast1 = min(laps1_of1, key=lambda l: float(l["lap_duration"]))
        fast2 = min(laps2_of1, key=lambda l: float(l["lap_duration"]))

        tel1 = _openf1_get_lap_telemetry(session_key, int(num1_str), fast1)
        tel2 = _openf1_get_lap_telemetry(session_key, int(num2_str), fast2)
        if tel1.empty or tel2.empty:
            return {"error": "Brak danych telemetrii dla jednego z kierowców."}

        ref_dist = tel1["Distance"].to_numpy()
        ref_speed = tel1["speed"].to_numpy()
        ref_time = tel1["RelTime"].to_numpy()

        comp_dist = tel2["Distance"].to_numpy()
        comp_speed = np.interp(ref_dist, comp_dist, tel2["speed"].to_numpy())
        comp_time = np.interp(ref_dist, comp_dist, tel2["RelTime"].to_numpy())
        delta_arr = comp_time - ref_time

        step = 4
        delta_points = []
        for idx in range(0, len(tel1), step):
            delta_points.append({
                "d": round(float(ref_dist[idx]), 1),
                "s1": int(ref_speed[idx]),
                "s2": int(round(comp_speed[idx])),
                "delta": round(float(delta_arr[idx]), 3),
            })

        return {
            "driver1": {
                "abbreviation": abbr1,
                "full_name": str(row1.get('FullName', '')),
                "team_color": clean_team_color(row1.get('TeamColor'), team1),
                "lap_time": format_lap_time(pd.to_timedelta(float(fast1["lap_duration"]), unit="s")),
            },
            "driver2": {
                "abbreviation": abbr2,
                "full_name": str(row2.get('FullName', '')),
                "team_color": clean_team_color(row2.get('TeamColor'), team2),
                "lap_time": format_lap_time(pd.to_timedelta(float(fast2["lap_duration"]), unit="s")),
            },
            "comparison": delta_points,
        }

    except DataNotLoadedError as e:
        logger.error("DataNotLoadedError w /api/compare (%s %s %s): %s", year, location, session_type, e)
        return {
            "error": "Nie udało się załadować danych okrążeń/telemetrii dla tej sesji.",
            "details": str(e),
        }
    except Exception as e:
        logger.exception("Błąd w /api/compare")
        return {
            "error": str(e),
            "trace": traceback.format_exc()
        }