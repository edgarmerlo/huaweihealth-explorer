# Huawei Health Explorer 🏃🚴

A Flutter application designed to import, parse, visualize, and convert workout records from **Huawei Health** data archives into standardized **GPX 1.1**, **TCX**, and **FIT** formats.

Seamlessly bridge your Huawei Health activities to **Strava**, **Garmin Connect**, **Komoot**, and other fitness ecosystems without relying on restricted cloud APIs or enterprise developer accounts.

---

## ✨ Features

- **100% On-Device & Private**: Zero data sent to third-party servers. All decompression, reverse-engineered parsing, and format generation happen directly on your device.
- **Multiple Ingestion Formats**:
  - Direct Huawei Privacy Data export `.zip` archive.
  - Raw `motion path detail data.json` and summary records.
- **Supported Export Formats**:
  - **GPX 1.1**: Includes GPS trackpoints, timestamps, elevation, and Garmin TrackPoint extensions (`<gpxtpx:hr>`, `<gpxtpx:cad>`, `<gpxtpx:speed>`).
  - **TCX**: Full Garmin Training Center XML with laps, heart rate values, cadence, and distance.
  - **FIT**: Standard binary FIT protocol format with 14-byte header, activity/session/lap/record definitions, and 16-bit CRC checksum.
- **Interactive Visualizations**:
  - Interactive OpenStreetMap route view with start/finish pins.
  - Telemetry curves (Elevation profiles and Heart rate curves over time).
- **Batch Export**: Select multiple activities and export/share them all at once.

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.13+)
- Dart SDK

### Installation

```bash
# Clone the repository
git clone https://github.com/edgarmerlo/huaweihealth-explorer.git
cd huaweihealth-explorer

# Install dependencies
flutter pub get

# Run on Web (Chrome)
flutter run -d chrome

# Run on Android
flutter run
```

---

## 📱 How to Export Data from Huawei Health

1. In your browser, go to **[privacy.huawei.com](https://privacy.huawei.com/)** (or in the Huawei Health app under **Me > Account Center > Privacy Center**).
2. Click **Request Your Data**.
3. Select **HUAWEI Health** and submit.
4. Download the `.zip` file from the link Huawei sends to your email/SMS.
5. Open **Huawei Health Explorer**, tap **"Browse ZIP or JSON File"**, and select the downloaded archive.

---

## 🧪 Testing

Run automated tests for the parser and exporters:

```bash
flutter test
```

---

## 📄 License
MIT License
