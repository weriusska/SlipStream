import fastf1
import re


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


def main():
    print("Pobieram kalendarze z fastf1 (od 2018 do 2026). To może chwilę potrwać...\n")

    unique_tracks = set()

    for year in range(2018, 2027):
        try:
            schedule = fastf1.get_event_schedule(year)
            races = schedule[schedule['RoundNumber'] > 0]

            for index, row in races.iterrows():
                location = row['Location']
                slug = create_slug(location)
                unique_tracks.add((location, slug))

        except Exception as e:
            print(f"⚠️ Nie udało się pobrać danych dla roku {year}: {e}")

    sorted_tracks = sorted(list(unique_tracks), key=lambda x: x[1])

    # ===== ZAPIS DO PLIKU =====
    filename = "lista_torow.txt"

    # Otwieramy plik w trybie do zapisu ("w") z kodowaniem UTF-8 (dla polskich/zagranicznych znaków)
    with open(filename, "w", encoding="utf-8") as file:
        file.write("=== GOTOWA LISTA ASSETÓW DO POBRANIA ===\n")
        file.write(f"Liczba unikalnych torów: {len(sorted_tracks)}\n\n")

        for original_name, slug in sorted_tracks:
            # Formatujemy linię tak samo jak wcześniej, ale z dodanym znakiem nowej linii (\n) na końcu
            line = f"Plik: {slug}.png".ljust(30) + f" (Lokalizacja wg F1: {original_name})\n"
            file.write(line)

    print(f"✅ Gotowe! Zapisano wszystkie tory do pliku: {filename}")


if __name__ == "__main__":
    main()