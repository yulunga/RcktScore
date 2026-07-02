# Mobile Signing

## Purpose

This document is reserved for iOS code signing and distribution setup.

## Planned Topics

- Apple Developer team setup
- bundle identifiers
- provisioning profiles
- development vs distribution signing
- TestFlight distribution process
- certificate rotation and ownership notes

## Current State

The native iOS target has been committed at
`mobile/ios/RcktScoreMobile/RcktScoreMobile.xcodeproj`.

TestFlight-style device builds have already been generated from this repo for
live testing, but the project still does not have a documented end-to-end
archive/sign/distribute runbook in version control.

Observed project values:

- bundle identifier: `rcktScore.RcktScoreMobile`
- display name: `Hit n Score`
- deployment target: iOS `17.6`

Signing and distribution ownership still need to be finalised before TestFlight
or App Store distribution.
