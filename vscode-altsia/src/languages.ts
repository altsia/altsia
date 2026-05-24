
export const DISPLAY_LANGUAGE_STATE_KEY = 'altsia.displayLanguage';

interface DisplayLanguageOption {
  label: string;
  value: string;
}

export const DISPLAY_LANGUAGE_OPTIONS: readonly DisplayLanguageOption[] = [
  { label: 'English (en)', value: 'en' },
  { label: 'English (en-US)', value: 'en-US' },
  { label: '简体中文 (zh-CN)', value: 'zh-CN' },
  { label: '繁體中文 (zh-TW)', value: 'zh-TW' },
  { label: '日本語 (ja)', value: 'ja' },
  { label: '한국어 (ko)', value: 'ko' },
  { label: 'Français (fr)', value: 'fr' },
  { label: 'Deutsch (de)', value: 'de' },
  { label: 'Español (es)', value: 'es' },
  { label: 'Español (Latinoamérica) (es-419)', value: 'es-419' },
  { label: 'Italiano (it)', value: 'it' },
  { label: 'Português (pt-PT)', value: 'pt-PT' },
  { label: 'Português (Brasil) (pt-BR)', value: 'pt-BR' },
  { label: 'Русский (ru)', value: 'ru' },
  { label: 'Українська (uk)', value: 'uk' },
  { label: 'Polski (pl)', value: 'pl' },
  { label: 'Čeština (cs)', value: 'cs' },
  { label: 'Magyar (hu)', value: 'hu' },
  { label: 'Română (ro)', value: 'ro' },
  { label: 'Türkçe (tr)', value: 'tr' },
  { label: 'Nederlands (nl)', value: 'nl' },
  { label: 'Svenska (sv)', value: 'sv' },
  { label: 'Dansk (da)', value: 'da' },
  { label: 'Norsk Bokmål (nb)', value: 'nb' },
  { label: 'Suomi (fi)', value: 'fi' },
  { label: 'Ελληνικά (el)', value: 'el' },
  { label: 'العربية (ar)', value: 'ar' },
  { label: 'עברית (he)', value: 'he' },
  { label: 'हिन्दी (hi)', value: 'hi' },
  { label: 'ไทย (th)', value: 'th' },
  { label: 'Tiếng Việt (vi)', value: 'vi' },
  { label: 'Bahasa Indonesia (id)', value: 'id' },
  { label: 'Bahasa Melayu (ms)', value: 'ms' },
];
