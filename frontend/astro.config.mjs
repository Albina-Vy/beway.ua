import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';

// SITE треба замінити на реальний домен перед продакшн-деплоєм.
// Від нього залежать canonical, Open Graph і sitemap.xml.
const SITE = process.env.PUBLIC_SITE_URL ?? 'https://beway.netlify.app';

export default defineConfig({
  site: SITE,
  output: 'static',
  trailingSlash: 'always',
  integrations: [sitemap({
    i18n: { defaultLocale: 'uk', locales: { uk: 'uk-UA' } },
  })],
  build: { inlineStylesheets: 'auto', assets: 'static' },
});
