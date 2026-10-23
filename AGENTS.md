# Project notes

Main app: `apps/web-react` (solo-vet model: one vet, her clients). `apps/mobile-flutter` is dead code.

## Verification
- Typecheck: `npm run typecheck --workspace @vetplus/web`
- Unit tests: `npm test` (root, all workspaces)
- Build: `npm run build`
- Firestore rules tests (needs Java + firebase-tools):
  `firebase emulators:exec --only firestore --project demo-vetplus "npm run test:rules"`
- `npm run lint` is broken (eslint not installed).

## Deploy
- GitHub Pages: `npm run deploy` builds with `--mode ghpages` (base `/flutter_vet_app/`, Firebase config
  from `apps/web-react/.env.local`) and pushes `dist` to the `gh-pages` branch.
- Live URL: https://ferrodude.github.io/flutter_vet_app/
- Router uses `basename={import.meta.env.BASE_URL}`; never hardcode `/` for asset or SW paths.

## Accounts
- No in-app sign-up. Rules forbid self-created profiles.
- Vets: `GOOGLE_APPLICATION_CREDENTIALS=<service-account.json> npm run create-vet -- <email> "<name>"`
- Clients: added by the vet in the app (`clientService.addClientByEmail`).
