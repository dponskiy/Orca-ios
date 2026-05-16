# Orca — iOS App Codebase Guide

## What This Is

**Orca** is a native iOS app (Swift/SwiftUI) for personal memory and task management. Users capture voice, text, and photos; AI auto-categorizes them into "Echoes" (topic buckets); smart reminders ("Pings") surface items at the right time. Backend is Supabase (PostgreSQL + auth + sync).

Bundle ID: `com.dponskiy.Orca` | Website: `orcadrop.app`

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift (100%) |
| UI | SwiftUI |
| Local persistence | SwiftData |
| Backend/Auth | Supabase Swift SDK 2.41.1 |
| Analytics | Mixpanel 5.2.0 |
| Crypto | Swift Crypto 4.2.0 |
| iOS min target | iOS 17+ |

**Apple frameworks in use**: AVFoundation, CoreLocation, CoreSpotlight, WeatherKit, UserNotifications, AuthenticationServices, NaturalLanguage, AppIntents.

---

## Project Structure

```
Orca/
├── App/
│   ├── OrcaApp.swift          # @main entry point, ModelContainer setup, auth routing
│   └── ContentView.swift      # Root 4-tab UI + floating Drop FAB
│
├── Models/                    # SwiftData models
│   ├── Memory.swift           # Core capture unit (voice/photo/text)
│   ├── Echo.swift             # Category bucket
│   ├── Ping.swift             # Reminder with recurrence
│   ├── SubTask.swift          # Checklist items inside a Memory
│   └── GroceryList.swift      # Recipe/shopping list
│
├── Services/                  # Business logic singletons
│   ├── AuthService.swift      # Apple Sign In + Supabase session
│   ├── SupabaseManager.swift  # Supabase client init
│   ├── SupabaseSyncServices.swift  # Bidirectional cloud sync
│   ├── SonarEngine.swift      # NLP auto-categorization + date extraction
│   ├── AudioService.swift     # Voice recording + transcription
│   ├── NotifcationService.swift    # Local/push notification scheduling
│   ├── LocationService.swift  # Geolocation
│   ├── WeatherService.swift   # WeatherKit integration
│   ├── FinanceService.swift   # Stock price alerts
│   ├── ESPNService.swift      # Sports scores/schedules
│   ├── RecipeExtractor.swift  # Recipe URL parsing
│   ├── TravelConfirmationParser.swift  # Flight/hotel email parsing
│   ├── OrcaShortcuts.swift    # Siri App Intents
│   ├── SpotLightService.swift # Core Spotlight indexing
│   └── AnalyticsService.swift # Mixpanel wrapper
│
├── Views/
│   ├── Dashboard/             # Home feed — EchoBubbles + upcoming cards
│   ├── Drop/                  # Capture UI — voice, text, photo, recipe
│   ├── Today/                 # Daily task view
│   ├── Calendar/              # Monthly/weekly calendar
│   ├── Shared/                # MemoryDetailView, MemoryEditView, domain blocks
│   ├── Search/                # Full-text search + browse all
│   ├── Auth/                  # AuthView (Apple Sign In)
│   ├── Settings/              # SettingsView, ManageEchosView
│   └── Onboarding/            # OnboardingFlow
│
├── Components/                # Reusable UI (PingCard, EchoBadge, DropButton)
│
├── People/                    # Contact + gift tracking feature
│   ├── Person.swift / GiftItem.swift  # SwiftData models
│   └── PeopleView, PersonProfileView, AddPersonView, AddGiftItemView
│
├── AI/
│   └── AppleIntelligenceService.swift  # Placeholder for Apple Intelligence
│
├── Resources/
│   ├── Config.swift           # Supabase URL/key, Mixpanel token, app URLs
│   ├── Colors.swift           # Custom color palette
│   └── Assets.xcassets/       # Icons, images, color sets
│
└── Orca.xcodeproj/
```

---

## Data Models

### Memory (core unit)
Fields: `id`, `text`, `echoId`, `tags`, `captureType` (voice/screenshot/typed), `detectedDate`, `endDate`, `createdAt`, `updatedAt`, `imageData`, `actionable`, `completed`, `completedAt`, `recurringCompletedDates`, `location` (name/address/lat/lng), `estimatedMinutes`, `url`, `isChecklist`

### Echo (category)
Fields: `id`, `name`, `emoji`, `sortOrder`, `isDefault`, `learnedKeywords`

23 default categories: Health, Kids, Birthday, Gifts, Travel, Cooking, Dining, Sports, Events, Shopping, Home, School, Work, Pets, Finance, Holidays, To-Do, Games, Movies, Books, Clothes, Workout, Notes

### Ping (reminder)
Fields: `id`, `memoryId`, `fireDate`, `fireTime`, `recurrence` (none/daily/weekly/monthly/yearly), `active`, `lastFired`, `followUpScheduled`

### Person (contact)
Fields: `id`, `name`, `relationship`, `birthday`, linked memory IDs, custom occasions with dates/budgets, `colorIndex`

### SubTask / GiftItem / WatchlistItem — supporting models

---

## Architecture

**Pattern**: MVVM-adjacent with service singletons
- **Models**: SwiftData `@Model` classes
- **Views**: SwiftUI, state via `@State`, `@Query`, `@Environment`
- **Services**: `@Observable` singletons (AuthService, SonarEngine, SupabaseSyncService, etc.)
- **Cross-view comms**: `NotificationCenter`

**Data flow**:
1. User captures → AudioService / TypeCapture / PhotoCapture
2. SonarEngine extracts: echo, dates, location, tags from text
3. Memory + Echo + Ping saved locally via SwiftData
4. SupabaseSyncService pushes to cloud; syncs inbound on launch

---

## Key Services

| Service | Role |
|---|---|
| `SonarEngine` | NLP keyword matching to auto-assign Echoes and extract dates/tags |
| `SupabaseSyncService` | Bidirectional sync — local SwiftData ↔ Supabase PostgreSQL |
| `AuthService` | Apple Sign In + Supabase JWT session management |
| `AudioService` | AVFoundation recording + on-device transcription |
| `NotificationService` | Local push scheduling for Pings |
| `SpotLightService` | CoreSpotlight indexing for system-level search |
| `ESPNService` | Sports data from ESPN API |
| `FinanceService` | Stock watchlist + price alert polling |
| `RecipeExtractor` | Parses recipe URLs into structured grocery data |

---

## App Entry & Navigation

**Startup** (`OrcaApp.swift`): Sets up SwiftData `ModelContainer`, then routes to:
- `OnboardingFlow` — first launch
- `AuthView` — unauthenticated (Apple Sign In)
- `ContentView` — authenticated

**ContentView** 4-tab layout:
1. Today — daily tasks
2. Dashboard — Echo bubbles + upcoming
3. People — contacts + gifts
4. Calendar — monthly view

Floating **Drop FAB** opens `CaptureDrawerView` (voice / text / photo / recipe).

---

## Configuration

`Resources/Config.swift` holds:
- Supabase URL + anon key
- Mixpanel token (`47abe570a284d9500c848fce71569951`)
- `privacyURL` / `termsURL` (`orcadrop.app`)

`Orca.entitlements`: Apple Sign In, WeatherKit

Deep link scheme: `orca://`

---

## Building & Running

```bash
# Open in Xcode
open Orca.xcodeproj

# CLI build
xcodebuild -scheme Orca -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 15'

# Run tests
xcodebuild -scheme Orca test \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

Requires: Xcode 16.3+, iOS 17+ simulator/device, Apple developer account.

Tests are minimal — `OrcaTests` (Swift Testing) and `OrcaUITests` (XCUITest) are placeholder stubs.

---

## Design System

**Colors** (defined in `Colors.swift` + `Assets.xcassets`):
`oceanTeal`, `deepNavy`, `seafoam`, `mist`, `pearl`, `coral`

**Fonts** (embedded TTF):
DM Sans, DM Mono, Instrument Sans
