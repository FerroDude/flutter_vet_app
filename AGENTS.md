# Project notes

Only app: `apps/web-react` (solo-vet model: one vet, her clients). Feature list: `apps/web-react/FEATURES.md`.
The old Flutter app (and its Cloud Functions) is archived on the `archive/mobile-flutter` branch.

## Conventions
- UI text goes through `t()` from `src/i18n` (pt + en dictionaries in `src/i18n/pt.ts` / `en.ts`; en is type-checked for missing keys). Language is per device (localStorage) and switching reloads.
- Shared helpers: `lib/format.ts` (dates, labels, `errorMessage`), `components/ui/Confirm.tsx` (`useConfirm`),
  `components/ui/Menu.tsx`, `components/ui/MonthGrid.tsx`. Use them instead of `window.confirm` or new formatters.
- Data hooks: `useClients`, `useRooms`, `useRequests`, `useVetAppointments`.

## Verification
- Typecheck: `npm run typecheck --workspace @vetplus/web`
- Unit tests: `npm test` (root, all workspaces)
- Build: `npm run build`
- Firestore rules tests (needs Java + firebase-tools):
  `firebase emulators:exec --only firestore --project demo-vetplus "npm run test:rules"`
- `npm run lint` is broken (eslint not installed).

## Workflow preference
- Commit messages: no "Generated with Devin" line and no "Co-Authored-By: Devin" trailer.
- The user tests on the live site: after every finished change, commit, push to `main` and run
  `npm run deploy` (plus `firebase deploy --only firestore|storage` when rules/indexes change)
  without asking.

## Deploy
- GitHub Pages: `npm run deploy` builds with `--mode ghpages` (base `/flutter_vet_app/`, Firebase config
  from `apps/web-react/.env.local`) and pushes `dist` to the `gh-pages` branch.
- Live URL: https://ferrodude.github.io/flutter_vet_app/
- Router uses `basename={import.meta.env.BASE_URL}`; never hardcode `/` for asset or SW paths.

## Accounts
- No in-app sign-up. Rules forbid self-created profiles.
- Vets: `GOOGLE_CLOUD_PROJECT=vetplus-digital npm run create-vet -- <email> "<name>"`. Uses the
  gcloud Application Default Credentials (`gcloud auth application-default login` once, with the
  project owner's Google account). No service-account key file needed.
- Clients: added by the vet in the app (`clientService.addClientByEmail`).
