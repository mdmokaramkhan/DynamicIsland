# DynamicIsland Architecture Migration Map

This document maps the current codebase into the target production structure so refactors stay incremental and low-risk.

## Application

- `App/DynamicIslandApp.swift` -> `Application/DynamicIslandApp.swift`
- `App/AppDelegate.swift` -> `Application/AppDelegate.swift`
- `App/SettingsWindowManager.swift` -> `Application/Settings/SettingsWindowManager.swift`

## Core

- `Model/KeystrokeToken.swift` -> `Core/Models/KeystrokeToken.swift`
- `Model/SpecialKeyIconMapper.swift` -> `Core/Input/SpecialKeyIconMapper.swift`
- `UI/IslandPanelBackground.swift` -> `Core/DesignSystem/IslandPanelBackground.swift`
- `Core/Persistence/AppSettings.swift` (new)
- `Core/Dependency/AppDependencies.swift` (new)

## Features

- `Overlay/DynamicIslandView.swift` -> `Features/Overlay/Presentation/DynamicIslandView.swift`
- `Overlay/IslandPanel.swift` -> `Features/Overlay/Presentation/IslandPanel.swift`
- `UI/IslandTabView.swift` -> `Features/Overlay/Presentation/IslandTabView.swift`
- `UI/IslandDashboardView.swift` -> `Features/Overlay/Presentation/IslandDashboardView.swift`
- `UI/IslandWelcomeView.swift` -> `Features/Overlay/Presentation/IslandWelcomeView.swift`

- `Media/MusicManager.swift` -> `Features/Media/Domain/MusicManager.swift`
- `Media/PlaybackState.swift` -> `Features/Media/Domain/PlaybackState.swift`
- `UI/IslandNowPlayingView.swift` -> `Features/Media/Presentation/IslandNowPlayingView.swift`
- `UI/MusicPlayerComponents.swift` -> `Features/Media/Presentation/MusicPlayerComponents.swift`
- `UI/NowPlayingSlider.swift` -> `Features/Media/Presentation/NowPlayingSlider.swift`

- `Model/FocusPandoraTimer.swift` -> `Features/Focus/Domain/FocusPandoraTimer.swift`
- `UI/IslandFocusTabView.swift` -> `Features/Focus/Presentation/IslandFocusTabView.swift`

- `UI/IslandTask.swift` -> `Features/Tasks/Domain/IslandTask.swift`
- `UI/IslandTasksTabView.swift` -> `Features/Tasks/Presentation/IslandTasksTabView.swift`

- `UI/IslandSettingsView.swift` -> `Features/Settings/Presentation/IslandSettingsView.swift`
- `App/PermissionOnboardingView.swift` -> `Features/Settings/Presentation/PermissionOnboardingView.swift`

## Infrastructure

- `Input/GlobalKeystrokeMonitor.swift` -> `Infrastructure/Input/GlobalKeystrokeMonitor.swift`
- `Input/KeyboardPermissionService.swift` -> `Infrastructure/Input/KeyboardPermissionService.swift`
- `App/PermissionManager.swift` -> `Infrastructure/Permissions/PermissionManager.swift`

- `Media/AppleMusicController.swift` -> `Infrastructure/Media/AppleMusicController.swift`
- `Media/SpotifyController.swift` -> `Infrastructure/Media/SpotifyController.swift`
- `Media/ControlCenterNowPlayingController.swift` -> `Infrastructure/Media/ControlCenterNowPlayingController.swift`
- `Media/MediaRemoteController.swift` -> `Infrastructure/Media/MediaRemoteController.swift`
- `Media/AppleScriptHelper.swift` -> `Infrastructure/Media/AppleScriptHelper.swift`

- `Audio/KeystrokeSoundPlayer.swift` -> `Infrastructure/Audio/KeystrokeSoundPlayer.swift`
- `Audio/ComboSoundPack.swift` -> `Infrastructure/Audio/ComboSoundPack.swift`

## Refactor Rules

- Move file paths first, then change internal behavior in follow-up commits.
- Keep singletons as adapters while introducing protocol-based injection.
- No direct `UserDefaults` calls from views.
- New features must be added under `Features/<FeatureName>/{Presentation,Domain,Data}`.
