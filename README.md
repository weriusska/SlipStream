# 🏎️ SlipStream — F1 Telemetry & NFC Collectibles Ecosystem

> **GitHub Repository Description (for the "About" section):**
> 🏎️ Phygital Formula 1 telemetry analysis app built with Flutter & FastAPI (FastF1). Tap custom-designed NFC driver cards to unlock high-resolution speed traces, tyre strategies, and Head-to-Head comparisons (2018–present).

## 📖 Overview

**SlipStream** is a full-stack engineering and design project that bridges the physical and digital worlds (*phygital*) for Formula 1 fans. It combines **custom-designed, luxury collectible NFC driver cards** with a **mobile telemetry analysis platform**.

By tapping a physical driver card to the back of a smartphone, the app intercepts a custom deep link (`slipstream://driver/{ID}`), pre-selects the driver, and enables a **Fast-Track UX flow** straight into granular session data powered by the official F1 timing stream via **FastF1**.

## ✨ Key Features

* **📡 NFC Fast-Track Integration:** Tap a physical collectible card (NTAG213/215) to automatically identify the driver and bypass manual driver selection menus.

* **📅 Historical Depth (2018–Present):** Dynamically fetches official F1 event schedules, vector track layouts (`.svg`), and session types (`FP1`, `FP2`, `FP3`, `Q`, `Sprint`, `Race`) from 2018 onwards.

* **📊 Context-Aware Telemetry Visualization:**

  * **Qualifying & Practice (`Q`, `FP1–3`, `SQ`):** Micro-telemetry of the fastest lap — high-frequency **Speed Profile** (km/h vs. distance), **Throttle & Brake** inputs, and **Gear Shifts**.

  * **Race & Sprint (`R`, `S`):** Macro-telemetry — **Lap Time Evolution** across the entire race distance and **Tyre Stint Analysis** (Soft, Medium, Hard, Intermediate, Wet).

* **⚔️ Head-to-Head (H2H) Comparisons:** Overlay telemetry traces of two drivers from the same session and analyze the **Time Delta (s)** curve across every meter of the circuit.

* **🎨 Dynamic Team Branding:** The UI automatically adapts its accent colors, borders, and chart lines to the official HEX color code of the driver's team for that specific season.

* **🔄 Smart Environment Detection:** Automatically switches between local emulator loopback (`10.0.2.2:5000`) and remote/ngrok tunneling when running on a physical device via USB debugging.

## 🏗️ System Architecture (Monorepo)

The repository is organized as a multi-disciplinary **Monorepo** combining the Flutter mobile client, the Python data processing backend, and all source design files (Affinity) for the physical NFC cards and branding:

```
📁 SlipStream/
│
├── 📁 APP/                       # Frontend: Flutter (Dart) cross-platform application
│    ├── 📁 lib/
│    │    ├── main.dart           # Entry point & Deep Link / NFC URI listener
│    │    └── 📁 screens/
│    │         ├── api_config.dart      # Dynamic device/emulator IP detector
│    │         ├── welcome.dart         # Animated NFC scan prompt
│    │         ├── pick_a_year.dart     # Season selector (2018 - current)
│    │         ├── pick_a_race.dart     # Grand Prix selector with SVG circuit maps
│    │         ├── pick_a_session.dart  # Dynamic session selector with NFC bypass logic
│    │         ├── pick_a_driver.dart   # Team-grouped driver grid with HEX styling
│    │         └── hero_screen.dart     # Telemetry dashboard & fl_chart visualizations
│    ├── 📁 assets/
│    │    ├── 📁 images/          # App logos & UI assets
│    │    └── 📁 tracks/          # 37 unique SVG circuit layouts
│    └── pubspec.yaml
│
├── 📁 DATA-ANALYSIS/             # Backend: Python + FastAPI + FastF1
│    ├── main.py                  # REST API endpoints (/api/races, /api/drivers, /api/telemetry)
│    ├── get_races.py             # Track slug generator & schedule utility
│    ├── lista_torow.txt          # Generated list of unique circuit assets
│    ├── telemetria.json          # Sample/fallback telemetry contract
│    └── 📁 cache/                # FastF1 local cache for sub-second repeat queries
│
├── 📁 CARDS/                     # Hardware Design: Collectible NFC Driver Cards (Affinity)
│    ├── 📁 logos/                # Driver personal logos & signatures
│    ├── 📁 png/                  # Exported print-ready card renders & cutouts
│    ├── blank.af                 # Master card template (Affinity)
│    ├── back.af                  # Reverse card design (NFC indicator & QR code)
│    └── *.af                     # Individual driver card source files (leclerc.af, ocon.af, etc.)
│
├── 📁 LOGO-AND-SHIT/             # Brand Identity & Source Assets
│    ├── logo.af                  # SlipStream master logotype source (Affinity)
│    └── logo.png                 # Exported brand logo
│
└── README.md
```

## 🃏 Physical NFC Collectible Cards

To prevent physical cards from becoming obsolete when drivers change teams between seasons, the cards are designed around **timeless personal branding**:

* **Front (Awers):** Carbon-fiber textured background, studio portrait with subtle backlighting, driver's permanent career number in metallic gold gradient, and personal signature/logo (designed in **Affinity**, stored in `CARDS/`).

* **Back (Rewers):** Embedded NFC antenna indicator (`NTAG213/215`) and a fallback QR code (`back.af`).

* **Payload:** Cards store a lightweight custom URI scheme:

  ```
  slipstream://driver/OCO
  ```

## 🚀 Getting Started

### Prerequisites

* **Python 3.10+**

* **Flutter SDK 3.x+**

* An Android device with NFC support (recommended for hardware testing) or an Android/iOS emulator.

### 1. Backend Setup (`DATA-ANALYSIS`)

1. Navigate to the backend directory:

   ```bash
   cd DATA-ANALYSIS
   ```

2. Create a virtual environment and install dependencies:

   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   pip install fastapi uvicorn fastf1 numpy pandas
   ```

3. Run the FastAPI server on port `5000`:

   ```bash
   uvicorn main:app --host 0.0.0.0 --port 5000 --reload
   ```

   *(Optional)* If testing on a physical phone over mobile data/Wi-Fi, expose port `5000` using **ngrok**:

   ```bash
   ngrok http 5000
   ```

   and update `baseUrl` in `APP/lib/screens/api_config.dart`.

### 2. Frontend Setup (`APP`)

1. Navigate to the Flutter application folder:

   ```bash
   cd APP
   ```

2. Fetch Flutter packages:

   ```bash
   flutter pub get
   ```

3. Run the app on your connected device or emulator:

   ```bash
   flutter run
   ```

## 🔌 API Endpoints Overview

| Method | Endpoint | Parameters | Description | 
| ----- | ----- | ----- | ----- | 
| `GET` | `/api/races` | `year` (int) | Returns all Grands Prix, circuit slugs, and available sessions for a given season. | 
| `GET` | `/api/drivers` | `year`, `location`, `session_type` | Quickly loads driver roster, numbers, abbreviations, and official team HEX colors (`telemetry=False`). | 
| `GET` | `/api/telemetry` | `year`, `location`, `session_type`, `driver` | Returns downsampled car telemetry (`Speed`, `Throttle`, `Brake`, `Gear`) for Qualifying/Practice or lap-by-lap pace & tyre compounds for Races. | 

## 👩‍💻 Author

**Weronika Michalska**

*Lead Developer & Product Designer*
