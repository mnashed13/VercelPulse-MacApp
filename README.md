# VercelPulse

VercelPulse is a lightweight, native macOS Menu Bar application styled with **macOS Liquid Glass** that provides a real-time overview of your Vercel projects, recent deployments, and resource usage statistics.

## 📦 Download Latest Release
Download the latest version (`.dmg` or `.zip`) directly from the **[GitHub Releases](https://github.com/mnashed13/VercelPulse-MacApp/releases/latest)** tab!

Every merged Pull Request to `main` automatically builds, tests, versions, and publishes a new macOS release via GitHub Actions.

1. Download **`VercelPulse-vX.Y.Z-macOS.dmg`** (or `VercelPulse.zip`) from the [Releases page](https://github.com/mnashed13/VercelPulse-MacApp/releases).
2. Drag `VercelPulse.app` into your `/Applications` folder.
3. Launch **VercelPulse** and click the **Vercel logo** in your macOS menu bar.

## Features
- **Official Vercel Menu Bar Icon:** Crisp vector template icon of the official Vercel mark in the macOS menu bar.
- **macOS Liquid Glass UI:** Translucent glass surfaces, interactive `.glassEffect` controls, and adaptive dark/light vibrancy.
- **Real-time Deployments:** View deployment statuses (Ready, Building, Queued, Error) across Production and Preview environments with adaptive 10s build polling.
- **Resource Usage:** Quick glances at your current workspace usage metrics.
- **Secure Authentication:** Safely stores your Vercel OAuth 2.0 session or Personal Access Token inside the native macOS Keychain.

## Setup & Local Development
1. Clone the repository and open `VercelPulse.xcodeproj` in Xcode (requires Xcode 26+ and macOS 26.5+).
2. Build and run the `VercelPulse` scheme.
3. Click the Vercel triangle icon in your menu bar.
4. Click the gear icon to open Settings and connect via OAuth or enter your Vercel Personal Access Token (and optional Team ID).
5. Click **Save Settings**.

## Automated Releases
Releases are automated via [.github/workflows/release.yml](.github/workflows/release.yml):
- Merging a PR to `main` automatically computes the next semantic version (`vX.Y.Z`) from PR labels (`major`, `minor`, `patch`) or Conventional Commit prefixes (`feat:`, `fix:`, `BREAKING CHANGE`).
- Builds `VercelPulse.app` in Release mode, runs tests, packages `.dmg` + `.zip` + `SHA256SUMS.txt`, and publishes a GitHub Release.
