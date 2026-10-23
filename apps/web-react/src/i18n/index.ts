import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import { en } from './en';

void i18n.use(initReactI18next).init({
  resources: {
    'pt-PT': { translation: en },
  },
  lng: 'pt-PT',
  fallbackLng: 'pt-PT',
  interpolation: { escapeValue: false },
});

export default i18n;
