# VercelPulse

VercelPulse is a lightweight, native macOS Menu Bar application that provides a real-time overview of your Vercel projects, recent deployments, and resource usage statistics. 

## 📦 Download
You can download the pre-compiled, ready-to-use macOS application here:
👉 **[Download VercelPulse.app (v1.0.0)](https://github.com/mnashed13/VercelPulse-MacApp/releases/download/v1.0.0/VercelPulse.zip)**

Once downloaded, unzip the file and drag `VercelPulse.app` to your `/Applications` folder!

## Features
- **Native macOS Experience:** Built using SwiftUI and AppKit, designed exclusively as a menu bar app (`LSUIElement`).
- **Real-time Deployments:** View deployment statuses (Ready, Building, Error) across all your projects.
- **Resource Usage:** Quick glances at your current usage metrics.
- **Secure Authentication:** Safely stores your Vercel Personal Access Token inside the native macOS Keychain.

## Setup & Installation
1. Clone the repository and open `VercelPulse.xcodeproj` in Xcode (requires Xcode 14+ and macOS 13.0+).
2. Build and run the project.
3. Once running, click the `triangle.fill` icon in your menu bar.
4. Click the gear icon to open Settings.
5. Enter your Vercel Personal Access Token (and an optional Team ID if you want to scope resources).
6. Click Save.

To build it for production, simply choose **Product > Archive** in Xcode, and export it as an Application to your `/Applications` folder!
