# AI Drive Metrics

An AI-powered smart driving safety monitor built with Flutter. The app pairs with a physical IoT black box device installed in a vehicle to record trip data in real time, syncs it to a cloud backend, and gives drivers a detailed safety score with per-trip breakdowns, route maps, harsh event logs, and downloadable PDF reports.

---

## Table of Contents

- [Related Repositories](#related-repositories)
- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Scoring System](#scoring-system)
- [Screens](#screens)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [Environment Setup](#environment-setup)
- [Database Schema](#database-schema)
- [Key Design Decisions](#key-design-decisions)

---

## Related Repositories

| Repository | Description |
|---|---|
| **This repo** | Flutter mobile app (on-device scoring, UI, PDF reports) |
| [Drive-Metrices-AI](https://github.com/Muhammad-Miqdad-Ahmad/Drive-Metrices-AI) | STM32 firmware for the IoT black box hardware device |
| [DriveMetricsAI-Models](https://github.com/maheen-zahid-26/DriveMetrcisAI-Models) | ML models for driving behaviour classification |

---

## Overview

AI Drive Metrics addresses a real problem: drivers have no real-time feedback on how safely they are driving, making it hard to identify and correct dangerous habits. The app connects to an IoT hardware device (via a unique device token) that continuously monitors acceleration, braking, and turning forces using an IMU sensor. Sensor data flows through ThingSpeak into a Supabase cloud database, where the app fetches it, computes driving scores entirely on-device, and presents it in a clean mobile UI.

---

## Features

### Dashboard
- Overall safety score gauge (0–100, graded A+ to F)
- Weekly score trend bar chart
- Quick stat cards: total trips, total distance, harsh event count
- Summary of recent trips
- Live connection status to the paired device

### Trip History
- Full list of all trips grouped by month
- Per-trip card showing score, grade, distance, duration, and worst harsh event severity badge
- Filter trips by score tier (Good / Average / Poor) and sort by date or score
- Month-level summary banner with average score and trip count

### Trip Detail
- Three tabs: Overview, Events, Route
- **Overview**: Score breakdown (braking, cornering, acceleration, smoothness), speed profile chart, key stats
- **Events**: Full log of every detected harsh event with timestamp, g-force reading, severity label (Low / Mild / Moderate / Severe), score impact breakdown
- **Route**: Full trip route rendered on an interactive map with color-coded markers (start, end, harsh event locations)

### Reports
- List of all trips with a downloadable safety report per trip
- In-app card showing score, metrics, and event summary chips
- Full PDF report generation including: score breakdown, event log with g-force data, per-event score impact, driving tips tailored to weak sub-scores, route summary
- Download to device and share via system share sheet

### Vehicle Health
- Health bars for key vehicle systems (engine, brakes, tyres, battery, suspension)
- Color-coded scores per system

### Profile
- View and edit display name and email
- Change password
- Update paired device ID
- Account-wide stats: total trips, total distance, average score

### Device Pairing
- Link the app to a hardware device using a device token
- Token is stored locally and used to filter all Supabase queries

### Authentication
- Email/password sign-in and registration via Supabase Auth
- Session persistence across app restarts

---

## Architecture

```
IoT Device (IMU Sensor)
        │
        ▼
  ThingSpeak (IoT data ingestion)
        │
        ▼
  Supabase (PostgreSQL + Auth)
        │
        ▼
  Flutter App (on-device score computation)
        │
   ┌────┴────────────────────────┐
   │                             │
SupabaseService           LocalStorageService
(data fetching)           (device token, prefs)
   │
   ▼
DrivingScoreCalculator
(on-device, from trip events)
   │
   ▼
UI Screens (flutter_riverpod state)
```

**All driving scores are computed on the mobile device** from raw trip event data fetched from Supabase. The `driver_scores` database table is intentionally not used — scores are always fresh and reflect the latest scoring algorithm.

Every Supabase query is filtered by `device_token`, so each user only sees data from their own paired hardware device.

---

## Scoring System

The scoring engine lives in `lib/core/utils/driving_score_calculator.dart`.

### Gravity Baseline Correction

The IMU sensor reports a *resultant* g-force magnitude (`√(ax² + ay² + az²)`), which always includes ~1.0g of gravity even when the car is stationary. Raw readings from the sensor are therefore in the **1.x g range**, not 0.x g.

The calculator subtracts a gravity baseline (default: **1.0g**) from every raw reading before classifying it:

```
dynamic_g = raw_g_worst − baseline   (minimum 0)
```

If no calibrated baseline is provided, the calculator estimates it automatically from the lowest 25% of g-force readings in the trip (a proxy for "at rest" moments).

### Severity Tiers (dynamic g, after baseline subtraction)

| Tier     | Dynamic g range | Score penalty |
|----------|-----------------|---------------|
| Low      | < 0.10 g        | 0 pts         |
| Mild     | 0.10 – 0.29 g   | −3 pts        |
| Moderate | 0.30 – 0.59 g   | −8 pts        |
| Severe   | ≥ 0.60 g        | −18 pts       |

### Sub-scores and Weights

Each sub-score starts at 100 and is reduced by harsh events of the relevant type:

| Sub-score    | Affected by                        | Weight |
|--------------|------------------------------------|--------|
| Braking      | Harsh braking events               | 35%    |
| Cornering    | Sharp left/right turns             | 25%    |
| Acceleration | Hard acceleration events           | 25%    |
| Smoothness   | All harsh events (×0.4–0.5 secondary penalty) | 15% |

**Overall score** = Braking × 0.35 + Cornering × 0.25 + Acceleration × 0.25 + Smoothness × 0.15

### Grade Scale

| Grade | Score range |
|-------|-------------|
| A+    | ≥ 90        |
| A     | 80 – 89     |
| B     | 70 – 79     |
| C     | 60 – 69     |
| D     | 50 – 59     |
| F     | < 50        |

---

## Screens

| Screen          | Route           | Description                              |
|-----------------|-----------------|------------------------------------------|
| Splash          | `/`             | Animated logo + loading                  |
| Login           | `/login`        | Email/password sign-in                   |
| Register        | `/register`     | New account creation                     |
| Dashboard       | `/dashboard`    | Home screen with score & stats           |
| Trip History    | `/trips`        | All trips with filters                   |
| Trip Detail     | `/trips/:id`    | Per-trip breakdown, events, map          |
| Reports         | `/reports`      | PDF report generation per trip           |
| Vehicle Health  | `/vehicle-health` | System health bars                     |
| Profile         | `/profile`      | User settings and account info           |
| Device Pairing  | `/pairing`      | Link hardware device                     |

Navigation is handled by `go_router` with a bottom navigation shell wrapping the four main tabs (Dashboard, Trips, Reports, Profile).

---

## Tech Stack

| Package              | Version   | Purpose                          |
|----------------------|-----------|----------------------------------|
| `flutter`            | SDK       | UI framework                     |
| `supabase_flutter`   | ^2.14.1   | Backend (auth + database)        |
| `flutter_map`        | ^8.3.0    | Interactive route map            |
| `latlong2`           | ^0.9.1    | Lat/lng coordinate types         |
| `go_router`          | ^13.0.0   | Declarative navigation           |
| `flutter_riverpod`   | ^2.5.1    | State management                 |
| `fl_chart`           | ^0.68.0   | Bar/line charts                  |
| `pdf`                | ^3.11.0   | PDF document generation          |
| `printing`           | ^5.13.0   | PDF sharing and download         |
| `shared_preferences` | ^2.2.3    | Local key-value storage          |
| `dio`                | ^5.4.3    | HTTP client                      |
| `intl`               | ^0.19.0   | Date/time formatting             |
| `flutter_screenutil` | ^5.9.3    | Responsive UI scaling            |
| `path_provider`      | ^2.1.5    | File system paths                |

---

## Project Structure

```
lib/
├── app.dart                              # ScreenUtilInit + MaterialApp.router
├── app_router.dart                       # go_router route definitions
│
├── core/
│   ├── constants/
│   │   ├── app_colors.dart               # Color palette + score color helpers
│   │   ├── app_text_styles.dart          # Typography (getter-based, .sp scaled)
│   │   ├── app_strings.dart              # String constants
│   │   └── app_theme.dart               # MaterialTheme config
│   ├── services/
│   │   ├── supabase_service.dart         # All Supabase queries
│   │   └── mock_data_service.dart        # Mock data for vehicle health
│   └── utils/
│       ├── driving_score_calculator.dart # On-device scoring engine
│       └── date_formatter.dart           # Date/time display helpers
│
├── models/
│   └── models.dart                       # All data models (User, Trip, Event, Score…)
│
├── screens/
│   ├── splash/
│   ├── auth/                             # login_screen, register_screen
│   ├── dashboard/
│   ├── trips/                            # trip_history_screen, trip_detail_screen
│   ├── reports/
│   ├── vehicle_health/
│   ├── profile/
│   └── device_pairing/
│
└── widgets/
    ├── common/
    │   ├── app_shell.dart                # Bottom nav scaffold wrapper
    │   ├── stat_card_widget.dart         # StatCard, EventBadge, HealthBar
    │   └── score_gauge_widget.dart       # Animated circular score gauge
    └── trip/
        └── trip_card_widget.dart         # Trip list item card
```

---

## Getting Started

### Prerequisites

- Flutter SDK `>=3.0.0`
- Dart SDK `>=3.0.0`
- A Supabase project (free tier is sufficient)
- Android Studio or Xcode for device deployment

### Installation

```bash
# Clone the repository
git clone <repo-url>
cd ai_drive_metrices

# Install dependencies
flutter pub get

# Run on a connected device or emulator
flutter run
```

---

## Environment Setup

Create a file at `lib/core/constants/supabase_config.dart` (do not commit this file) with your Supabase project credentials:

```dart
const supabaseUrl = 'https://your-project.supabase.co';
const supabaseAnonKey = 'your-anon-key';
```

Then initialize Supabase in `main.dart`:

```dart
await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
```

---

## Database Schema

The app reads from four Supabase tables, all filtered by `device_token`:

### `trips`
| Column         | Type        | Description                          |
|----------------|-------------|--------------------------------------|
| `id`           | uuid        | Primary key                          |
| `device_token` | text        | Links trip to the hardware device    |
| `start_time`   | timestamptz | Trip start timestamp                 |
| `end_time`     | timestamptz | Trip end timestamp (nullable)        |
| `distance_km`  | float       | Total distance travelled             |
| `max_speed_kmh`| float       | Peak speed during trip               |
| `avg_speed_kmh`| float       | Average speed during trip            |

### `trip_events`
| Column       | Type        | Description                                                           |
|--------------|-------------|-----------------------------------------------------------------------|
| `id`         | uuid        | Primary key                                                           |
| `trip_id`    | uuid        | Foreign key → trips                                                   |
| `event_type` | text        | `harshBraking`, `hardAccel`, `leftTurn`, `rightTurn`, `idle`, `normalDriving` |
| `timestamp`  | timestamptz | When the event occurred                                               |
| `g_worst`    | float       | Raw IMU resultant g-force magnitude (1.x g range, includes gravity)   |
| `accel_x`    | float       | X-axis acceleration                                                   |
| `accel_y`    | float       | Y-axis acceleration                                                   |
| `accel_z`    | float       | Z-axis acceleration                                                   |
| `speed_kmh`  | float       | Vehicle speed at time of event                                        |
| `latitude`   | float       | GPS latitude                                                          |
| `longitude`  | float       | GPS longitude                                                         |
| `confidence` | float       | Detection confidence (0–100)                                          |

### `route_points`
| Column      | Type        | Description            |
|-------------|-------------|------------------------|
| `trip_id`   | uuid        | Foreign key → trips    |
| `latitude`  | float       | GPS latitude           |
| `longitude` | float       | GPS longitude          |
| `timestamp` | timestamptz | Point timestamp        |

### `device_readings`
| Column         | Type        | Description                              |
|----------------|-------------|------------------------------------------|
| `device_token` | text        | Device identifier                        |
| `timestamp`    | timestamptz | Reading timestamp                        |
| *(sensor cols)*| float       | Raw sensor values synced from ThingSpeak |

---

## Key Design Decisions

### On-Device Score Computation
Scores are never stored in the database and always computed fresh on the mobile device from raw `trip_events`. This means the scoring algorithm can be updated without any backend migration or re-processing of historical data — just ship a new app version.

### Gravity Baseline Correction
The IMU sensor reports raw resultant g-force that includes the Earth's gravity component (~1.0g). Without correction, every reading would be classified as "Severe" since 1.x > 0.6. The calculator subtracts a 1.0g baseline before applying severity tiers. All display code (`harshnessLabel`, `harshnessColor`, severity badges in trip history, trip detail, and PDF reports) applies the same correction to stay consistent.

### Responsive UI
All dimensions use `flutter_screenutil` with a 390×844 reference design (iPhone 14). Font sizes use `.sp`, heights use `.h`, widths use `.w`, and radii/icon sizes use `.r`. This ensures the UI scales correctly from compact phones (360px wide) to large phones (430px wide) without clipping or overflow.

### PDF Generation
PDF reports are generated entirely on-device using the `pdf` package with physical A4 point units. The PDF widget tree uses `pw.` prefixed types (`pw.Column`, `pw.Text`, etc.) and is kept completely separate from the Flutter widget tree. Mixing Flutter `Widget` types into a `pw.Column` children list causes silent runtime failures, so all PDF code is isolated in dedicated builder methods within `reports_screen.dart`.
