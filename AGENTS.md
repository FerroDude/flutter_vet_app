# Project notes

Only app: `apps/web-react` (multi-clinic model: VetTempo platform, clinics with owner/vet members and linked clients; active clinic in `ClinicProvider` + localStorage `vettempo-clinic`). Feature list: `apps/web-react/FEATURES.md`.
The old Flutter app (and its Cloud Functions) is archived on the `archive/mobile-flutter` branch.

## Conventions
- UI text goes through `t()` from `src/i18n` (pt + en dictionaries in `src/i18n/pt.ts` / `en.ts`; en is type-checked for missing keys). Language is per device (localStorage) and switching reloads.
- Shared helpers: `lib/format.ts` (dates, labels, `errorMessage`), `components/ui/Confirm.tsx` (`useConfirm`),
  `components/ui/Menu.tsx`, `components/ui/MonthGrid.tsx`. Use them instead of `window.confirm` or new formatters.
- UX rules for every action: async buttons show `loading`, disable their siblings, and guard
  re-entry (one click = one call = one toast). Never switch context (active clinic, page, tab)
  as a side effect of an action; add the result and point to it with an anchored hint
  (`@radix-ui/react-popover`, see `ClinicSwitcher` `ClinicHint`). Tooltips are hover/focus-only
  labels and never carry information the user needs on touch.
- Data hooks: `useClinic`, `useClinicMembers`, `useClinicClients`, `useClinicRooms`, `useClinicRequests`, `useClients` (wrapper), `useRooms`, `useRequests`, `useVetAppointments` (clinic-scoped).

## Verification
- Typecheck: `npm run typecheck --workspace @vetplus/web`
- Unit tests: `npm test` (root, all workspaces)
- Build: `npm run build`
- Firestore rules tests (needs Java + firebase-tools):
  `firebase emulators:exec --only firestore --project demo-vetplus "npm run test:rules"`
- Cloud Functions (`functions/`, standalone package, not in workspaces):
  `npm --prefix functions run build`, `npm --prefix functions test`
- Deploy functions: `firebase deploy --only functions`. One-time setup:
  `firebase functions:secrets:set GOOGLE_OAUTH_CLIENT_SECRET` and
  `GOOGLE_OAUTH_CLIENT_ID` in `functions/.env.vetplus-digital`.
- `npm run lint` is broken (eslint not installed).
- Storage rules call `firestore.get()` (clinic branding uploads). That needs the Storage service agent
  `service-997739068545@gcp-sa-firebasestorage.iam.gserviceaccount.com` to have
  `roles/firebaserules.firestoreServiceAgent` (granted 2026-11-27); without it uploads fail with
  `storage/unauthorized`.

## Workflow preference
- Commit messages: no "Generated with Devin" line and no "Co-Authored-By: Devin" trailer.
- The user tests on the live site: after every finished change, commit, push to `main` and run
  `npm run deploy` (plus `firebase deploy --only firestore|storage` when rules/indexes change)
  without asking.

## Deploy
- GitHub Pages: `npm run deploy` builds with `--mode ghpages` (base `/flutter_vet_app/`, Firebase config
  from `apps/web-react/.env.local`) and pushes `dist` to the `gh-pages` branch.
- Live URL: https://ferrodude.github.io/flutter_vet_app/
- Future domain: yoshivetcare.com (owned by the vet; landing page lives at https://yoshivetcare.com/en/).
  Moving the app there means updating: Vite base, OAuth JS origins + authorized domains, Firebase Auth
  authorized domains, `APP_URL` in `functions/src/gcal/sync.ts`, the privacy-page link on the consent
  screen, and keeping the old GitHub Pages URL redirecting so already-printed QR tags (`/t/:petId`) still work.
- Router uses `basename={import.meta.env.BASE_URL}`; never hardcode `/` for asset or SW paths.

## Accounts
- No in-app sign-up. Rules forbid self-created profiles.
- Vets: `GOOGLE_CLOUD_PROJECT=vetplus-digital npm run create-vet -- <email> "<name>"` creates the
  staff user but does NOT attach a clinic — membership is added by a clinic owner via the
  `createClinicVet` callable. Uses the gcloud Application Default Credentials
  (`gcloud auth application-default login` once, with the project owner's Google account).
  No service-account key file needed.
- Clients: added by clinic staff in the app (`clinicService.addClinicClient` callable).
