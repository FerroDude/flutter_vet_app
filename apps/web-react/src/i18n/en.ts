// English resource bundle. English-only for now; add a `pt-PT` bundle later for
// bilingual support. Keep ALL user-facing strings here — no hard-coded JSX text.
export const en = {
  common: {
    appName: 'Vet+',
    loading: 'Loading…',
    save: 'Save',
    cancel: 'Cancel',
    retry: 'Retry',
    signOut: 'Sign out',
    continue: 'Continue',
    back: 'Back',
  },
  auth: {
    login: 'Log in',
    register: 'Create account',
    email: 'Email',
    password: 'Password',
    confirmPassword: 'Confirm password',
    fullName: 'Full name',
    forgotPassword: 'Forgot password?',

    welcomeBack: 'Welcome back',
    loginSubtitle: 'Sign in to your Vet+ account.',
    createYourAccount: 'Create your account',
    registerSubtitle: 'Your pet’s health companion.',
    signIn: 'Sign in',
    signUp: 'Sign up',
    noAccount: 'Don’t have an account?',
    haveAccount: 'Already have an account?',

    accountCreated:
      'Account created. Check your email for a verification link.',

    verifyEmailTitle: 'Verify your email',
    verifyEmailBody: 'Check your inbox for a verification link, then refresh.',
    verifySentTo: 'We sent a verification link to',
    verifyInstructions:
      'Open the link in your inbox to verify your email. Once verified, you’ll be signed in automatically.',
    iVerified: 'I’ve verified my email',
    checking: 'Checking verification status…',
    resendEmail: 'Resend email',
    emailResent: 'Verification email sent. Check your inbox.',
    signOutDifferent: 'Sign out and use a different email',
    stillNotVerified: 'Email not verified yet. Open the link, then try again.',

    resetTitle: 'Reset password',
    resetSubtitle:
      'Enter your email and we’ll send you a link to reset your password.',
    sendResetLink: 'Send reset link',
    resetSentTitle: 'Check your email',
    resetSentBody:
      'We sent a password reset link. Follow the instructions in your inbox.',
    backToSignIn: 'Back to sign in',
    resend: 'Didn’t get it? Resend',

    displayNameTitle: 'Set your display name',
    displayNameSubtitle: 'Choose how your name appears to others.',
    displayName: 'Display name',
    displayNamePlaceholder: 'Enter your name',
    displayNameSaved: 'Display name saved.',

    settingUpProfile: 'Setting up your profile…',
  },
  clinic: {
    selectTitle: 'Connect to a clinic',
    selectSubtitle:
      'Find your veterinary clinic to sync appointments and chats. You can skip and do this later.',
    searchPlaceholder: 'Search clinics by name',
    search: 'Search',
    connect: 'Connect',
    skip: 'Skip for now',
    noResults: 'No clinics found. Try a different name.',
    connected: 'Connected to clinic.',
  },
  nav: {
    dashboard: 'Dashboard',
    pets: 'Pets',
    calendar: 'Calendar',
    chat: 'Chat',
    appointments: 'Appointments',
    clinic: 'Clinic',
    staff: 'Staff',
    profile: 'Profile',
    settings: 'Settings',
  },
  validation: {
    emailRequired: 'Please enter your email.',
    emailInvalid: 'Please enter a valid email.',
    passwordRequired: 'Please enter your password.',
    passwordMin: 'Password must be at least 6 characters.',
    confirmRequired: 'Please confirm your password.',
    passwordsMismatch: 'Passwords do not match.',
    nameRequired: 'Please enter your full name.',
    nameMin: 'Name must be at least 2 characters.',
  },
  errors: {
    'auth/invalid-email': 'The email address is not valid.',
    'auth/user-disabled': 'This account has been disabled.',
    'auth/user-not-found': 'No account found for this email.',
    'auth/wrong-password': 'Incorrect email or password.',
    'auth/invalid-credential': 'Incorrect email or password.',
    'auth/email-already-in-use': 'An account already exists for this email.',
    'auth/weak-password': 'The password is too weak.',
    'auth/too-many-requests': 'Too many attempts. Try again later.',
    'auth/operation-not-allowed': 'Email/password sign-in is not enabled.',
    'auth/requires-recent-login':
      'Please sign in again to complete this action.',
    generic: 'Something went wrong. Please try again.',
  },
  placeholder: {
    comingSoon: 'Coming soon',
    phase: 'This screen will be built in a later phase.',
  },
} as const;

export type Resources = typeof en;
