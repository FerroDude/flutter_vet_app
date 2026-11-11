/** Where Firebase's reset-password page sends users afterwards — the app's
 *  root route, which renders the login screen when signed out. */
export function appLoginUrl(email?: string): string {
  const url = new URL(import.meta.env.BASE_URL, window.location.origin);
  if (email) url.searchParams.set('email', email);
  return url.toString();
}
