// Finder-contact validation for pet-tag found reports. Pure regexes — kept in
// their own module so tests don't pull in Firebase init.
// Mirrors the foundReports create rule in firestore.rules.

export const PHONE_RE = /^\+?([ ().-]*[0-9]){6,}[ ().-]*$/;
export const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export const isValidContact = (s: string): boolean => {
  const v = s.trim();
  return v.length <= 200 && (PHONE_RE.test(v) || EMAIL_RE.test(v));
};
