from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import fastf1
import re

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

LOCATION_FIXES = {
    "Monte Carlo": "Monaco",
    "Yas Island": "Yas Marina",
    "Singapore": "Marina Bay",
    "Miami Gardens": "Miami",
    # Jeśli w przyszłości znajdziesz inne "dziwne" nazwy,
    # po prostu dopisz je tutaj w ten sam sposób! np.:
    # "Sakhir": "Bahrain"
}


def create_slug(location_name: str) -> str:
    """
    Zamienia nazwę lokacji (np. 'São Paulo', 'Spa-Francorchamps') 
    na prosty string do nazwy pliku (np. 'sao_paulo', 'spa_francorchamps').
    """
    # Zamiana znaków specjalnych/spacji na podłogę i małe litery
    slug = location_name.lower()
    slug = slug.replace("ã", "a").replace("ó", "o")  # ręczna korekta najczęstszych akcentów
    slug = re.sub(r'[^a-z0-9]+', '_', slug).strip('_')
    return slug


@app.get("/api/races")
def get_races(year: int):
    try:
        # Pobieramy harmonogram dla danego roku z fastf1
        schedule = fastf1.get_event_schedule(year)

        # Odrzucamy testy przedsezonowe (testy mają zazwyczaj RoundNumber = 0)
        races_df = schedule[schedule['RoundNumber'] > 0]

        results = []

        # POPRAWKA 1: iterujemy po races_df
        # Iterujemy po wierszach z pandas DataFrame
        for index, row in races_df.iterrows():
            raw_location = row['Location']
            location = LOCATION_FIXES.get(raw_location, raw_location)
            slug = create_slug(location)

            # ===== NOWOŚĆ: WYCIĄGAMY DYNAMICZNE SESJE =====
            sessions = []
            for i in range(1, 6):
                session_name = str(row.get(f'Session{i}', ''))
                # Zabezpieczenie przed pustymi polami lub wartościami 'NaT'/'NaN'
                if session_name and session_name.lower() not in ['nan', 'none', 'nat']:
                    sessions.append(session_name)

            results.append({
                "id": int(row['RoundNumber']),
                "name": location.upper(),
                "image_slug": slug,
                "sessions": sessions  # Wysyłamy gotową listę do Fluttera!
            })


        return results

    except Exception as e:
        # Zabezpieczenie na wypadek, gdyby podano np. rok z przyszłości, którego nie ma jeszcze w bazie
        return {"error": str(e)}


@app.get("/api/drivers")
def get_drivers(year: int, location: str, session_type: str):
    """
    Zwraca listę kierowców dla podanej sesji.
    Przykład użycia: http://127.0.0.1:5000/api/drivers?year=2024&location=Monza&session_type=FP1
    Ważne: session_type w fastf1 to zazwyczaj: 'FP1', 'FP2', 'FP3', 'Q', 'S', 'SQ', 'R'
    """
    try:
        # Pobieramy sesję na podstawie danych z parametru
        session = fastf1.get_session(year, location, session_type)

        # SEKRET OPTYMALIZACJI: Wyłączamy ładowanie ciężkiej telemetrii!
        # Dzięki temu API odpowie w ułamek sekundy zamiast w kilkanaście.
        session.load(telemetry=False, laps=False, weather=False)

        drivers_list = []

        # Przeszukujemy tabelę z wynikami (results)
        for index, row in session.results.iterrows():

            # fastf1 często zwraca kolor jako czysty string, np. "00D2BE" bez hash'a.
            raw_color = str(row.get('TeamColor', ''))

            # Zabezpieczenie: jeśli nie ma koloru, dajemy biały, w przeciwnym razie formatujemy na poprawny HEX
            if raw_color.lower() == 'nan' or not raw_color:
                team_color_hex = "#FFFFFF"
            else:
                team_color_hex = f"#{raw_color}" if not raw_color.startswith('#') else raw_color

            drivers_list.append({
                "position": int(row.get('Position', 0)),
                "driver_number": str(row.get('DriverNumber', '')),
                "full_name": str(row.get('FullName', '')),  # np. "Max Verstappen"
                "broadcast_name": str(row.get('BroadcastName', '')),  # np. "M VERSTAPPEN"
                "abbreviation": str(row.get('Abbreviation', '')),  # np. "VER"
                "team_name": str(row.get('TeamName', '')),  # np. "Red Bull Racing"
                "team_color": team_color_hex  # np. "#3671C6"
            })

        return drivers_list

    except Exception as e:
        return {"error": str(e)}