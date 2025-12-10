# handa

Seamless storage and collaboration for music creators. Think "GitHub for music files" or "Figma for audio collaboration."

## The Problem

Sending one song currently takes 6+ apps: export from your DAW, ZIP the files, upload to Dropbox (no preview), re-upload to WeTransfer for the paywall, re-upload to DISCO or Baton for streaming protection, then manually track who downloaded what. It's chaos.

handa consolidates this into one place. Drag a file in and it auto-extracts stems, creates previews, adds analytics, and lets you share however you want.

## Features

- **Library** — Grid view of audio projects (.als, .logicx, .wav) with folder organization and pagination
- **Sent/Received** — Track files you've shared and files shared with you
- **Real-time notifications** — Activity feed for downloads, file additions, collaboration invites, and access attempts
- **Advanced search** — Filter by name, BPM, collaborators, genre, instrument, key, DAW, or file type
- **Flexible sharing** — Create share links, payment links, collaborate, set passwords, all from a right-click menu
- **Upload with progress** — Drag-and-drop with visual progress indicator
- **Security alerts** — Get notified when unauthorized emails attempt access (e.g., "Someone with an Island Records email tried to access 'The Violet Gospel.wav'")

## Tech Stack

- **Backend**: Ruby on Rails with Active Storage
- **Frontend**: Stimulus + Tailwind CSS
- **Database**: PostgreSQL
- **Storage**: AWS S3 / GCP
- **Realtime**: ActionCable (Rails WebSockets)
- **Payments**: Stripe API

## Background

Built from 8+ years of music production experience — gold/silver certifications, 100M+ streams, and work with Interscope, Universal, RCA, and EMI. This solves a real industry problem, not a theoretical one.

## Status

In development.
