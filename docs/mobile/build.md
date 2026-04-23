# Mobile Build

## Purpose

This document tracks how the native mobile app should be built locally and in
CI.

## Current Project

The iOS project exists at:

- `mobile/ios/RcktScoreMobile/RcktScoreMobile.xcodeproj`

Current scheme:

- `RcktScoreMobile`

Current app target:

- `RcktScoreMobile`

## Local Build Notes

Open the project in Xcode and select the `RcktScoreMobile` scheme.

Recommended local checks:

1. build for an iPhone simulator
2. run the app and confirm organisation login
3. confirm dashboard lists active, scheduled, and recent matches
4. open an active match and verify score actions call the shared v2 backend

The project currently reads runtime API configuration through app configuration
keys handled by `AppConfig.swift`, with a fallback to the deployed backend URL.

## Current State

The native app is scaffolded and implements the main scoring workflow. There is
not yet a documented CI build, archive workflow, or release build-number policy.
