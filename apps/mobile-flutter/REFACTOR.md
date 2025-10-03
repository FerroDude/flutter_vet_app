# Refactor Plan — Flutter App Modularization (Detailed)

Goal: Transform `apps/mobile-flutter` into a clean, feature‑oriented codebase. Primary focus: extract heavy UI from `lib/main.dart`, organize by feature, align imports, and keep functional parity at every step.

Status: In progress. Auth pages live under `core/auth/`. Shared widgets exist under `shared/widgets/`. Chat and admin pages exist in `lib/pages/`.

Important Working Agreements
- No functional changes during extraction steps (behavior parity).
- Small, verifiable steps; each step compiles and runs.
- Update imports atomically; avoid broken intermediate states.
- Prefer moves over rewrites to preserve `git blame`.

Target Structure (end state)
- `lib/main.dart` → very small entry (runApp only)
- `lib/app.dart` (App shell) and `core/navigation/` (shell + tabs)
- `core/auth/` (already extracted)
- `features/` by domain:
  - `features/dashboard/pages/dashboard_page.dart`
  - `features/pets/pages/{pets_page.dart,pet_form_page.dart,pet_details_page.dart}`
  - `features/events/pages/appointments_page.dart`
  - `features/events/widgets/{calendar_view.dart,event_forms.dart,simple_event_forms.dart}`
  - `features/chat/pages/{chat_page.dart,chat_room_page.dart}` (move from `pages/`)
  - `features/clinic/pages/{clinic_management_page.dart,clinic_admin_dashboard.dart,vet_management_page.dart}`
  - `features/admin/pages/{admin_dashboard.dart,app_owner_stats.dart}`
- `shared/widgets/` (quick_action, info_card, list_placeholder, theme_toggle)
- `providers/`, `services/`, `repositories/`, `models/`, `theme/` remain (optionally later: relocate providers under features)

Milestones & Step‑By‑Step Plan

Phase 0 — Baseline & Safety (no code moves)
1) Run analyzer and a debug build locally.
   - Commands: `flutter analyze`; `flutter build apk --debug`.
2) Snapshot current imports and symbols in `main.dart` to know dependencies.
   - Search: `grep/Select-String 'class .*Page|Widget|Provider'` in `lib/main.dart`.
3) Create a refactor TODO list in this file (checklist below) and update as we go.

Acceptance: Build succeeds; baseline warnings recorded (no new ones introduced).

Phase 1 — App Shell Extraction
1) Create `lib/app.dart` containing `MyApp` exactly as in `main.dart`.
2) Update `lib/main.dart` to only contain `main()` and `runApp(MyApp(...))`.
3) Ensure all providers remain wired in `MyApp` and `AuthWrapper` behavior is unchanged.

Acceptance: Hot reload works; authentication still gates the app; theming unchanged.

Phase 2 — Navigation Shell
1) Create `core/navigation/main_navigation.dart` with `MyHomePage` + bottom tabs.
2) Create `core/navigation/navigation_destinations.dart` defining tab metadata.
3) Move any inline nav helpers from `main.dart` to `core/navigation/`.
4) Replace references to `MyHomePage` in `auth_wrapper.dart` to import from new path.

Acceptance: Bottom navigation works; FAB on Pets tab still appears where expected.

Phase 3 — Dashboard Extraction
1) Move `DashboardPage` from `main.dart` → `features/dashboard/pages/dashboard_page.dart`.
2) Move any private dashboard widgets alongside as public widgets under `features/dashboard/widgets` (create if necessary).
3) Update imports in navigation to reference the new file.

Acceptance: Dashboard renders and interactive elements (expand/collapse, delete dialogs) work.

Phase 4 — Pets Feature Extraction
1) From `main.dart`, move:
   - `PetsPage` → `features/pets/pages/pets_page.dart`
   - `PetsPageContent` (and related) → same folder
   - If present: `PetFormPage`, `PetDetailsPage`, and reorderable list → corresponding files
2) Extract any inline item widgets (pet tiles/cards) into `features/pets/widgets/`.
3) Keep route/navigation to pet form/details local to the feature (simple `MaterialPageRoute` for now).

Acceptance: Pets tab works, including FAB navigation to `PetFormPage`.

Phase 5 — Events & Calendar Consolidation
1) Relocate:
   - `widgets/appointments_page.dart` → `features/events/pages/appointments_page.dart`
   - `widgets/calendar_view.dart` → `features/events/widgets/calendar_view.dart`
   - `widgets/event_forms.dart` → `features/events/widgets/event_forms.dart`
   - `widgets/simple_event_forms.dart` → `features/events/widgets/simple_event_forms.dart`
2) Update imports from `main.dart`/elsewhere to the new locations.
3) Keep APIs unchanged to avoid ripple changes.

Acceptance: Appointments tab loads; creating/editing events still functions.

Phase 6 — Chat Feature Relocation
1) Move `pages/chat_page.dart` → `features/chat/pages/chat_page.dart`.
2) Move `pages/chat_room_page.dart` → `features/chat/pages/chat_room_page.dart`.
3) Update imports in navigation and any deep links.

Acceptance: Chat list, room view, and sending messages continue to work; unread counts visible.

Phase 7 — Clinic/Admin Pages Consolidation
1) Move clinic/admin related pages:
   - `pages/clinic_management_page.dart`, `pages/clinic_admin_dashboard.dart`, `pages/vet_management_page.dart` → `features/clinic/pages/`.
   - `pages/admin_dashboard.dart`, `pages/app_owner_stats.dart` → `features/admin/pages/`.
2) Update references from `auth_wrapper.dart` (admin routing) to new paths.

Acceptance: Admin dashboard routes correctly for app owner; clinic admin pages still accessible.

Phase 8 — Shared Widgets Cleanup
1) Move `widgets/theme_toggle_widget.dart` → `shared/widgets/theme_toggle_widget.dart`.
2) Verify existing shared widgets are imported from `shared/widgets` across the app.

Acceptance: Theme toggle works; no duplicate definitions remain.

Phase 9 — Providers (optional relocation)
1) Keep `providers/` as‑is for this iteration to reduce scope.
2) Optionally, in a follow‑up, co‑locate feature‑specific providers under `features/<feature>/state/`.

Acceptance: No provider behavior change; app compiles.

Phase 10 — Code Hygiene & Perf Pass
1) Replace excessive `print` logs with a simple logger or guard with `kDebugMode`.
2) Validate `withOpacity/withValues` usage (target SDK); avoid deprecated APIs.
3) Ensure heavy computations (sort/filter) aren’t done in `build()` without memoization.
4) Add `const` where possible to reduce rebuilds.

Acceptance: Analyzer warnings reduced; no functional change.

Phase 11 — Caching (Enable Event Caching)
1) Re‑enable `CacheService.cacheEvents` to write only JSON with epoch millis (already produced by `toJson`).
2) Verify `CalendarEvent.fromJson` accepts ints (it does) and does not expect Firestore `Timestamp` objects.
3) Add versioning guard in cache payload to allow future migrations.

Acceptance: Cold app loads show events from cache; counts computed without network when valid.

Phase 12 — Documentation & Rules
1) Keep docs in sync (`docs/CODEBASE_OVERVIEW.md`, `SYSTEM_OVERVIEW.md`, `DEPLOYMENT_GUIDE.md`, `INTEGRATION_TEST_GUIDE.md`).
2) Maintain `apps/mobile-flutter/firestore.rules` alongside code changes that affect schema.

Acceptance: Docs describe actual structure and paths; rules deploy cleanly.

Checklists (update as we complete)
- [ ] Phase 0 Baseline
- [x] Phase 1 App Shell extraction
- [ ] Phase 2 Navigation shell
- [ ] Phase 3 Dashboard extraction
- [ ] Phase 4 Pets extraction
- [ ] Phase 5 Events & calendar consolidation
- [ ] Phase 6 Chat relocation
- [ ] Phase 7 Clinic/Admin consolidation
- [ ] Phase 8 Shared widgets cleanup
- [ ] Phase 9 Providers decision
- [ ] Phase 10 Hygiene & perf
- [ ] Phase 11 Caching enabled
- [ ] Phase 12 Docs & rules reviewed

File Move Matrix (reference)
- main.dart → retain only `main()`; move `MyApp` to `app.dart` and `MyHomePage` to `core/navigation/`.
- pages/chat_* → features/chat/pages/*
- pages/*admin* → features/admin/pages/*
- pages/clinic_* + vet_management → features/clinic/pages/*
- widgets/appointments_page.dart → features/events/pages/appointments_page.dart
- widgets/{calendar_view,event_forms,simple_event_forms}.dart → features/events/widgets/*
- widgets/theme_toggle_widget.dart → shared/widgets/theme_toggle_widget.dart

Verification Protocol (per phase)
1) `flutter analyze` → no new errors.
2) Run app: login, exercise the affected tab(s).
3) Smoke tests: create/edit/delete an event; send message; navigate tabs.
4) If a regression is found, revert the last move and re‑apply with fixes.

Risk & Rollback
- Moves are reversible; if a step breaks the app, revert that commit and split into smaller moves.
- Avoid changing public APIs during moves; if a rename is needed, do it in a dedicated step.

Appendix — Useful Searches
- Find classes in main: `Select-String -Path lib/main.dart -Pattern 'class\s+.*Page'`
- Find imports to update: `Select-String -Path lib/**/*.dart -Pattern 'widgets/appointments_page.dart'`
