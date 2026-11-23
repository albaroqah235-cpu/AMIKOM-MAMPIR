/**
 * MAMPIR Web - Standard Indonesian Text Provider
 * Disederhanakan untuk bahasa Indonesia default (tanpa multi-bahasa).
 */

const I18nService = {
  currentLang: 'id',
  init() {},
  applyDOMTranslations() {},
  onLanguageChange() {},
  getLanguage() {
    return 'id';
  },
  setLanguage() {},
  t(key, fallback = '') {
    return fallback || key;
  },
  translateCategory(cat) {
    return cat || '';
  },
  translateFacility(fac) {
    return fac || '';
  }
};

window.t = function(key, fallback = '', params = {}) {
  let text = fallback || key;
  if (params && typeof params === 'object') {
    Object.keys(params).forEach(k => {
      text = text.replace(new RegExp(`\\{${k}\\}`, 'g'), params[k]);
    });
  }
  return text;
};
