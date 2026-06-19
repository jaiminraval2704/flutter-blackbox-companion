# Flutter BlackBox Companion 💻

A live remote web dashboard for the [flutter_blackbox](https://pub.dev/packages/flutter_blackbox) package. This web application allows you to monitor and debug your Flutter app wirelessly from your computer's browser.

## 🚀 Features

- **Live Streaming**: Connects instantly to your mobile app using a secure 6-digit session PIN.
- **Network Inspector**: View all HTTP/Dio requests in real-time, including headers, request/response bodies, and timing. 
- **Exporting**: Save individual requests as cURL, or export the entire session network log as a HAR 1.2 file for Postman or Chrome DevTools.
- **Live Logs**: Watch standard output and custom logs stream in perfectly formatted color.
- **Crash Tracking**: Receive native desktop browser push notifications the moment a crash or unhandled exception occurs in your app.
- **Performance HUD**: Monitor real-time device FPS and jank without taking up screen space on your phone.
- **Session Sharing**: Generate deep links (`?watch=123456`) to share your live debugging session instantly with your team.

## 🛠 Tech Stack

- **Framework**: Flutter Web (Wasm-ready)
- **State Management & UI**: Glassmorphic UI with Provider for state injection.
- **Backend & Sync**: Firebase Realtime Database (for ultra-low latency signaling and state syncing).
- **Hosting**: Firebase App Hosting

## 💻 How to Run Locally

If you'd like to develop or test the dashboard locally:

1. Clone the repository.
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run the Flutter web server:
   ```bash
   flutter run -d chrome
   ```

## 🔗 Live Version

The official production version is hosted at:  
👉 **[flutter-blackbox-companion.web.app](https://flutter-blackbox-companion.web.app)**

## 🤝 Open Source

The BlackBox Companion dashboard is fully open source. Contributions, bug reports, and pull requests are welcome!
