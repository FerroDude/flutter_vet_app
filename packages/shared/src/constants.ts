// App-owner emails are hard-coded in the client (parity with the Flutter app's
// UserProvider._isAppOwnerEmail). Keep this list in sync with mobile.
export const APP_OWNER_EMAILS = [
  'pedroferrodude@hotmail.com',
  'ines.breia@gmail.com',
] as const;

/** Whether an email belongs to an app owner (case-insensitive). */
export function isAppOwnerEmail(email: string | null | undefined): boolean {
  if (!email) return false;
  return (APP_OWNER_EMAILS as readonly string[]).includes(
    email.trim().toLowerCase(),
  );
}
