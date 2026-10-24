import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { AuthProvider } from '@/auth/AuthProvider';
import { initTheme } from '@/lib/theme';
import { lang } from '@/i18n';
import App from '@/App';
import '@/index.css';

initTheme();
document.documentElement.lang = lang === 'en' ? 'en' : 'pt-PT';

const rootEl = document.getElementById('root');
if (!rootEl) throw new Error('Root element #root not found');

createRoot(rootEl).render(
  <StrictMode>
    <AuthProvider>
      <App />
    </AuthProvider>
  </StrictMode>,
);
