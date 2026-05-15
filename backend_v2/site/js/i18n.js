import { strings, supportedLocales, defaultLocale } from './strings.js?v=20260515-qqnav';

const STORAGE_KEY = 'kcb_locale';

function detectInitialLocale() {
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (saved && supportedLocales.includes(saved)) {
      return saved;
    }
  } catch {}
  const navLocale = (navigator.language || '').toLowerCase();
  if (navLocale.startsWith('en')) return 'en-US';
  return defaultLocale;
}

let currentLocale = detectInitialLocale();

export function getLocale() {
  return currentLocale;
}

export function t(key, params = {}) {
  const dict = strings[currentLocale] || strings[defaultLocale];
  const raw = dict[key];
  if (raw == null) return key;
  return raw.replace(/\{(\w+)\}/g, (_, k) => params[k] ?? '');
}

function applyTranslations() {
  document.documentElement.lang = currentLocale === 'en-US' ? 'en' : 'zh-CN';

  document.querySelectorAll('[data-i18n]').forEach((el) => {
    const key = el.getAttribute('data-i18n');
    const value = t(key);
    el.textContent = value;
  });

  document.querySelectorAll('[data-i18n-html]').forEach((el) => {
    const key = el.getAttribute('data-i18n-html');
    el.innerHTML = t(key);
  });

  document.querySelectorAll('[data-i18n-attr]').forEach((el) => {
    const spec = el.getAttribute('data-i18n-attr');
    spec.split(',').forEach((pair) => {
      const [attr, key] = pair.split(':').map((s) => s.trim());
      if (attr && key) {
        el.setAttribute(attr, t(key));
      }
    });
  });

  const titleEl = document.querySelector('title[data-i18n]');
  if (titleEl) {
    document.title = t(titleEl.getAttribute('data-i18n'));
  }
}

export function setLocale(locale) {
  if (!supportedLocales.includes(locale)) return;
  currentLocale = locale;
  try {
    localStorage.setItem(STORAGE_KEY, locale);
  } catch {}
  applyTranslations();
  document.dispatchEvent(new CustomEvent('localechange', { detail: { locale } }));
}

export function toggleLocale() {
  setLocale(currentLocale === 'zh-CN' ? 'en-US' : 'zh-CN');
}

export function initI18n() {
  applyTranslations();

  const switchBtn = document.getElementById('lang-switch');
  const switchLabel = document.getElementById('lang-current');
  if (switchBtn && switchLabel) {
    const updateLabel = () => {
      switchLabel.textContent = currentLocale === 'zh-CN' ? 'EN' : '中';
    };
    updateLabel();
    switchBtn.addEventListener('click', () => {
      toggleLocale();
      updateLabel();
    });
  }
}
