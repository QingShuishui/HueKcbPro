import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const css = readFileSync(resolve('css/style.css'), 'utf8');
const html = readFileSync(resolve('index.html'), 'utf8');
const js = readFileSync(resolve('js/app.js'), 'utf8');
const readme = readFileSync(resolve('content/readme.md'), 'utf8');
const readmeZh = readFileSync(resolve('content/readme.zh-CN.md'), 'utf8');

function rule(selector) {
  const escaped = selector.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const match = css.match(new RegExp(`${escaped}\\s*\\{([\\s\\S]*?)\\}`));
  assert.ok(match, `Missing CSS rule for ${selector}`);
  return match[1];
}

function assertDecl(block, property, value) {
  assert.match(block, new RegExp(`${property}\\s*:\\s*${value}(?:;|\\n)`), `${property}: ${value}`);
}

const universal = rule('*,\n*::before,\n*::after');
assertDecl(universal, 'box-sizing', 'border-box');
assertDecl(universal, '-webkit-user-select', 'none');
assertDecl(universal, '-moz-user-select', 'none');
assertDecl(universal, '-ms-user-select', 'none');
assertDecl(universal, 'user-select', 'none');

const inputSelection = rule('input,\ntextarea');
assertDecl(inputSelection, '-webkit-user-select', 'auto');
assertDecl(inputSelection, 'user-select', 'auto');

const htmlRule = rule('html');
assertDecl(htmlRule, 'width', '100%');
assertDecl(htmlRule, 'height', '100%');
assertDecl(htmlRule, 'overscroll-behavior', 'none');

const bodyRule = rule('body');
assertDecl(bodyRule, 'position', 'fixed');
assertDecl(bodyRule, 'width', '100%');
assertDecl(bodyRule, 'height', '100%');
assertDecl(bodyRule, 'overflow', 'hidden');

const mainRule = rule('#main');
assertDecl(mainRule, 'height', 'calc\\(100dvh - 64px\\)');
assertDecl(mainRule, 'overflow-y', 'auto');
assertDecl(mainRule, 'overscroll-behavior', 'contain');

const titleGlow = rule('.hero__title-layer--glow');
assertDecl(titleGlow, 'filter', 'blur\\(10px\\)');
assertDecl(titleGlow, 'animation', 'hero-title-breath 2s alternate infinite');
assert.match(css, /@keyframes\s+hero-title-breath\s*\{\s*0%\s*\{\s*opacity:\s*0\s*;\s*\}\s*to\s*\{\s*opacity:\s*1\s*;\s*\}/);
assert.match(css, /\.hero__title-layer\s*\{[\s\S]*?font-size:\s*77px;[\s\S]*?letter-spacing:\s*0\.04em;/);
assert.match(css, /@media\s*\(min-width:\s*1801px\)[\s\S]*?\.hero__title-layer\s*\{[\s\S]*?font-size:\s*110px;/);
assert.match(css, /@media\s*\(max-width:\s*1068px\)[\s\S]*?\.hero__title-layer\s*\{[\s\S]*?font-size:\s*57px;/);

const cta = rule('.hero__cta');
assertDecl(cta, 'width', '480px');
assertDecl(cta, 'height', '100px');
assertDecl(cta, 'font-size', '45px');
assertDecl(cta, 'border-radius', '50px');
assertDecl(cta, 'backdrop-filter', 'blur\\(25px\\)');

const ctaHover = rule('.hero__cta:hover');
assertDecl(ctaHover, 'transform', 'scale\\(1\\.05\\)');

assert.match(css, /@media\s*\(max-width:\s*1800px\)[\s\S]*?\.hero__cta\s*\{[\s\S]*?width:\s*384px;[\s\S]*?height:\s*80px;[\s\S]*?font-size:\s*36px;[\s\S]*?border-radius:\s*40px;/);
assert.match(css, /@media\s*\(max-width:\s*1068px\)[\s\S]*?\.hero__cta\s*\{[\s\S]*?width:\s*312px;[\s\S]*?height:\s*65px;[\s\S]*?font-size:\s*29px;[\s\S]*?border-radius:\s*32\.5px;/);
assert.match(css, /@media\s*\(max-width:\s*480px\)[\s\S]*?\.hero__cta\s*\{[\s\S]*?min-width:\s*240px;[\s\S]*?height:\s*50px;[\s\S]*?font-size:\s*22\.5px;[\s\S]*?border-radius:\s*25px;/);

const nav = rule('.nav');
assertDecl(nav, 'height', '64px');
assertDecl(nav, 'padding', '0 10px 0 24px');
assertDecl(nav, 'background', '#ffffff');
assertDecl(nav, 'backdrop-filter', 'blur\\(50px\\)');
assertDecl(nav, 'overflow', 'visible');
assertDecl(nav, '-webkit-user-select', 'none');
assertDecl(nav, 'user-select', 'none');

const navNoSelect = rule('.nav,\n.mobile-header,\n.mobile-menu');
assertDecl(navNoSelect, '-webkit-user-select', 'none');
assertDecl(navNoSelect, 'user-select', 'none');

const navDrag = rule('.nav a,\n.nav button,\n.nav img,\n.nav svg,\n.mobile-header a,\n.mobile-header button,\n.mobile-header img,\n.mobile-menu a,\n.mobile-menu button,\n.mobile-menu img');
assertDecl(navDrag, '-webkit-user-drag', 'none');

const navLeftSpacer = rule('.nav__spacer--left');
assertDecl(navLeftSpacer, 'width', '48px');

const navMenuSpacer = rule('.nav__spacer--menu');
assertDecl(navMenuSpacer, 'width', '100px');

const navEnglishMenuSpacer = rule('html[lang="en"] .nav__spacer--menu');
assertDecl(navEnglishMenuSpacer, 'width', '56px');

const navEnglishLinksItem = rule('html[lang="en"] .nav__links li');
assertDecl(navEnglishLinksItem, 'flex-basis', '148px');

const navEnglishDownloadItem = rule('html[lang="en"] #nav-download-item');
assertDecl(navEnglishDownloadItem, 'flex-basis', '180px');

const navLinks = rule('.nav__links');
assertDecl(navLinks, 'height', '100%');
assert.match(css, /\.nav__links\s*>\s*\*\s*\+\s*\*\s*\{[\s\S]*?margin-left:\s*10px;/);

const navLinksItem = rule('.nav__links li');
assertDecl(navLinksItem, 'flex', '0 0 120px');

const navLinksAnchor = rule('.nav__links > li > a');
assertDecl(navLinksAnchor, 'height', '64px');
assertDecl(navLinksAnchor, 'display', 'grid');
assertDecl(navLinksAnchor, 'place-items', 'center');
assert.doesNotMatch(css, /\.nav__links a\s*\{/);

const navDropdownTrigger = rule('.nav__dropdown-trigger');
assertDecl(navDropdownTrigger, 'height', '64px');
assertDecl(navDropdownTrigger, 'display', 'inline-flex');
assertDecl(navDropdownTrigger, 'align-items', 'center');
assertDecl(navDropdownTrigger, 'justify-content', 'center');
assertDecl(navDropdownTrigger, 'white-space', 'nowrap');

const navDropdownTriggerLabel = rule('.nav__dropdown-trigger-label');
assertDecl(navDropdownTriggerLabel, 'white-space', 'nowrap');
assertDecl(navDropdownTriggerLabel, 'flex', '0 0 auto');

const navDropdownTriggerArrow = rule('.nav__dropdown-trigger-arrow');
assertDecl(navDropdownTriggerArrow, 'width', '14px');
assertDecl(navDropdownTriggerArrow, 'height', '14px');
assertDecl(navDropdownTriggerArrow, 'flex', '0 0 14px');
assertDecl(navDropdownTriggerArrow, 'transition', 'transform 0\\.2s ease');

const navDropdown = rule('.nav__dropdown');
assertDecl(navDropdown, 'position', 'fixed');
assertDecl(navDropdown, 'top', '64px');
assertDecl(navDropdown, 'border-radius', '0 0 8px 8px');
assertDecl(navDropdown, 'box-shadow', '0 8px 16px rgba\\(0, 0, 0, 0\\.14\\)');
assertDecl(navDropdown, 'backdrop-filter', 'blur\\(16px\\)');
assertDecl(navDropdown, 'opacity', '0');
assertDecl(navDropdown, 'visibility', 'hidden');
assertDecl(navDropdown, 'filter', 'blur\\(3px\\)');
assertDecl(navDropdown, 'width', '180px');
assertDecl(navDropdown, 'padding', '6px');
assert.match(css, /\.nav__item--dropdown\.is-open \.nav__dropdown\s*\{/);

const navDropdownDetailVisible = rule('.nav__dropdown.is-detail-visible');
assertDecl(navDropdownDetailVisible, 'width', '480px');
assert.doesNotMatch(css, /nav__dropdown:has\(\.nav__dropdown-platform:hover\)/);
assert.doesNotMatch(css, /nav__dropdown:has\(\.nav__dropdown-details:hover\)/);

const navDropdownContent = rule('.nav__dropdown-content');
assertDecl(navDropdownContent, 'display', 'grid');
assertDecl(navDropdownContent, 'grid-template-columns', '168px minmax\\(0, 1fr\\)');

const navDropdownPlatform = rule('.nav__dropdown-platform');
assertDecl(navDropdownPlatform, 'height', '42px');
assertDecl(navDropdownPlatform, 'gap', '10px');
assertDecl(navDropdownPlatform, 'padding', '0 12px');
assertDecl(navDropdownPlatform, 'white-space', 'nowrap');

const navDropdownPlatformIcon = rule('.nav__dropdown-platform-icon');
assertDecl(navDropdownPlatformIcon, 'width', '24px');
assertDecl(navDropdownPlatformIcon, 'height', '24px');

const navDropdownPlatformText = rule('.nav__dropdown-platform > span:not(.nav__dropdown-platform-icon)');
assertDecl(navDropdownPlatformText, 'white-space', 'nowrap');
assertDecl(navDropdownPlatformText, 'text-overflow', 'ellipsis');

const navDropdownDetails = rule('.nav__dropdown-details');
assertDecl(navDropdownDetails, 'position', 'relative');
assertDecl(navDropdownDetails, 'min-height', '126px');
assertDecl(navDropdownDetails, 'opacity', '0');
assertDecl(navDropdownDetails, 'display', 'grid');
assertDecl(navDropdownDetails, 'place-items', 'center');

const navDropdownDetail = rule('.nav__dropdown-detail');
assertDecl(navDropdownDetail, 'position', 'absolute');
assertDecl(navDropdownDetail, 'opacity', '0');
assertDecl(navDropdownDetail, 'text-align', 'center');
assertDecl(navDropdownDetail, 'visibility', 'hidden');
assertDecl(navDropdownDetail, 'z-index', '0');

const activeNavDropdownDetail = rule('.nav__dropdown-content.is-detail-android .nav__dropdown-detail--android,\n.nav__dropdown-content.is-detail-ios .nav__dropdown-detail--ios,\n.nav__dropdown-content.is-detail-web .nav__dropdown-detail--web');
assertDecl(activeNavDropdownDetail, 'visibility', 'visible');
assertDecl(activeNavDropdownDetail, 'z-index', '1');
assert.doesNotMatch(css, /nav__dropdown-content:has\(\.nav__dropdown-platform--ios:hover\) \.nav__dropdown-detail--ios/);
assert.doesNotMatch(css, /nav__dropdown-content:has\(\.nav__dropdown-platform--web:hover\) \.nav__dropdown-detail--web/);

const navDropdownDetailTitle = rule('.nav__dropdown-detail h3');
assertDecl(navDropdownDetailTitle, 'font-size', '24px');
assertDecl(navDropdownDetailTitle, 'white-space', 'nowrap');

const navEnglishDropdownDetailTitle = rule('html[lang="en"] .nav__dropdown-detail h3');
assertDecl(navEnglishDropdownDetailTitle, 'font-size', '19px');

const navDropdownDetailLink = rule('.nav__dropdown-detail a');
assertDecl(navDropdownDetailLink, 'min-height', '44px');
assertDecl(navDropdownDetailLink, 'padding', '9px 18px 9px 10px');
assertDecl(navDropdownDetailLink, 'font-size', '16px');
assertDecl(navDropdownDetailLink, 'justify-content', 'center');
assertDecl(navDropdownDetailLink, 'max-width', '100%');

const navDropdownDetailLinkIcon = rule('.nav__dropdown-detail-link-icon');
assertDecl(navDropdownDetailLinkIcon, 'width', '44px');
assertDecl(navDropdownDetailLinkIcon, 'height', '44px');
assertDecl(navDropdownDetailLinkIcon, 'border-radius', '999px');

const navDropdownDetailLinkText = rule('.nav__dropdown-detail-link-text');
assertDecl(navDropdownDetailLinkText, 'display', 'grid');
assertDecl(navDropdownDetailLinkText, 'overflow', 'hidden');

const navDropdownDetailLinkMain = rule('.nav__dropdown-detail-link-main');
assertDecl(navDropdownDetailLinkMain, 'overflow', 'hidden');
assertDecl(navDropdownDetailLinkMain, 'text-overflow', 'ellipsis');

const navDropdownDetailLinkNote = rule('.nav__dropdown-detail-link-note');
assertDecl(navDropdownDetailLinkNote, 'font-size', '13px');
assertDecl(navDropdownDetailLinkNote, 'overflow', 'hidden');
assertDecl(navDropdownDetailLinkNote, 'text-overflow', 'ellipsis');

assert.match(css, /\.nav__dropdown-content\.is-detail-ios \.nav__dropdown-detail--ios/);
assert.match(css, /\.nav__dropdown-content\.is-detail-web \.nav__dropdown-detail--web/);

const navDropdownDefaultDetail = rule('.nav__dropdown-detail--android');
assert.doesNotMatch(navDropdownDefaultDetail, /opacity\s*:\s*1(?:;|\n)/);

const navMenuMask = rule('.nav-menu-mask');
assertDecl(navMenuMask, 'position', 'fixed');
assertDecl(navMenuMask, 'top', '64px');
assertDecl(navMenuMask, '--blur', '0px');
assertDecl(navMenuMask, 'background', 'rgba\\(0, 21, 83, 0\\.06\\)');
assertDecl(navMenuMask, 'backdrop-filter', 'blur\\(var\\(--blur, 0px\\)\\)');
assert.match(css, /transition:\s*opacity 0\.3s ease,\s*visibility 0\.3s ease,\s*backdrop-filter 0\.3s ease,\s*-webkit-backdrop-filter 0\.3s ease;/);
assert.match(css, /body\.nav-menu-open\s+\.nav-menu-mask\s*\{[\s\S]*?--blur:\s*2px;/);

const mobileHeader = rule('.mobile-header');
assertDecl(mobileHeader, 'height', '64px');
assertDecl(mobileHeader, 'padding', '0 14px 0 24px');
assertDecl(mobileHeader, 'background', '#ffffff');

const mobileHeaderLogo = rule('.mobile-header__logo');
assertDecl(mobileHeaderLogo, 'width', '35px');
assertDecl(mobileHeaderLogo, 'height', '35px');

const mobileMenu = rule('.mobile-menu');
assertDecl(mobileMenu, 'position', 'fixed');
assertDecl(mobileMenu, 'inset', '0');
assertDecl(mobileMenu, 'background', '#ffffff');

const mobileMenuHeader = rule('.mobile-menu__header');
assertDecl(mobileMenuHeader, 'height', '64px');
assertDecl(mobileMenuHeader, 'border-bottom', '1px solid rgba\\(0, 0, 0, 0\\.08\\)');

const mobileMenuBrand = rule('.mobile-menu__brand');
assertDecl(mobileMenuBrand, 'display', 'flex');
assertDecl(mobileMenuBrand, 'align-items', 'center');

const mobileMenuClose = rule('.mobile-menu__close');
assertDecl(mobileMenuClose, 'width', '44px');
assertDecl(mobileMenuClose, 'height', '44px');

const mobileMenuContainer = rule('.mobile-menu__container');
assertDecl(mobileMenuContainer, 'padding', '28px 48px 0');
assertDecl(mobileMenuContainer, 'text-align', 'left');

const mobileMenuItem = rule('.mobile-menu__item');
assertDecl(mobileMenuItem, 'padding', '28px 0');
assertDecl(mobileMenuItem, 'border-bottom', '1px solid rgba\\(0, 0, 0, 0\\.1\\)');

const mobileMenuPrimary = rule('.mobile-menu__primary');
assertDecl(mobileMenuPrimary, 'justify-content', 'flex-start');
assertDecl(mobileMenuPrimary, 'padding', '0');
assertDecl(mobileMenuPrimary, 'text-align', 'left');

const mobileMenuPrimaryText = rule('.mobile-menu__primary-text');
assertDecl(mobileMenuPrimaryText, 'font-size', '18px');
assertDecl(mobileMenuPrimaryText, 'line-height', '30px');

const mobileMenuArrow = rule('.mobile-menu__arrow');
assertDecl(mobileMenuArrow, 'margin-left', 'auto');

const mobileMenuSecondaryContainer = rule('.mobile-menu__secondary-container');
assertDecl(mobileMenuSecondaryContainer, 'max-height', '0');
assertDecl(mobileMenuSecondaryContainer, 'opacity', '0');
assert.match(mobileMenuSecondaryContainer, /transition:[\s\S]*max-height 0\.28s ease[\s\S]*opacity 0\.2s ease[\s\S]*transform 0\.28s ease/);

const mobileMenuExpandedSecondaryContainer = rule('.mobile-menu__item--expanded .mobile-menu__secondary-container');
assertDecl(mobileMenuExpandedSecondaryContainer, 'max-height', '320px');
assertDecl(mobileMenuExpandedSecondaryContainer, 'opacity', '1');

const mobileMenuSecondary = rule('.mobile-menu__secondary');
assertDecl(mobileMenuSecondary, 'justify-content', 'flex-start');

const mobileMenuSecondaryText = rule('.mobile-menu__secondary-text');
assertDecl(mobileMenuSecondaryText, 'font-size', '18px');
assertDecl(mobileMenuSecondaryText, 'line-height', '30px');

const aboutMarkdown = rule('#about .about-markdown');
assertDecl(aboutMarkdown, 'max-width', '900px');
assertDecl(aboutMarkdown, 'border', '1px solid var\\(--color-line\\)');

const markdownHeading = rule('#about .markdown-body h2');
assertDecl(markdownHeading, 'border-bottom', '1px solid var\\(--color-line\\)');

const markdownPre = rule('#about .markdown-body pre');
assertDecl(markdownPre, 'overflow-x', 'auto');

const platforms = rule('.hero__platforms');
assertDecl(platforms, 'top', '80%');
assertDecl(platforms, 'left', '50%');
assertDecl(platforms, 'transform', 'translate\\(-50%\\)');
assert.match(css, /\.hero__platforms li:not\(:last-child\)\s*\{[\s\S]*?margin-right:\s*56px;/);

const platformChip = rule('.platform-chip');
assertDecl(platformChip, 'opacity', '\\.5');
assertDecl(platformChip, 'font-size', '20px');
assertDecl(platformChip, 'color', 'rgba\\(0, 0, 0, \\.8\\)');

const platformChipLink = rule('.platform-chip[href]');
assertDecl(platformChipLink, 'cursor', 'pointer');
assert.match(css, /\.platform-chip\[href\]:hover/);

const platformIcon = rule('.platform-chip__icon');
assertDecl(platformIcon, 'width', '28px');
assertDecl(platformIcon, 'height', '28px');

const cursorGlow = rule('.cursor-glow');
assertDecl(cursorGlow, 'mix-blend-mode', 'overlay');
assertDecl(cursorGlow, 'will-change', 'transform, opacity, width, height, filter');

const trailParticle = rule('.trail-particle');
assertDecl(trailParticle, 'width', '120px');
assertDecl(trailParticle, 'height', '120px');
assertDecl(trailParticle, 'filter', 'blur\\(50px\\)');
assertDecl(trailParticle, 'mix-blend-mode', 'overlay');

const rasterOverlay = rule('.raster-overlay');
assertDecl(rasterOverlay, '--raster-strip-width', '36px');

const rasterStrip = rule('.raster-strip');
assertDecl(rasterStrip, 'flex', '0 0 var\\(--raster-strip-width\\)');
assertDecl(rasterStrip, 'width', 'var\\(--raster-strip-width\\)');
assert.match(css, /@media\s*\(max-width:\s*733px\)[\s\S]*?\.raster-overlay\s*\{[\s\S]*?--raster-strip-width:\s*22px;/);

assert.match(js, /glowSize:\s*\[280,\s*280\]/);
assert.match(js, /blurRadius:\s*80/);
assert.match(js, /glow\.style\.width\s*=\s*active\s*\?\s*`\$\{width\}px`\s*:\s*'80px'/);
assert.match(js, /glow\.style\.filter\s*=\s*active\s*\?\s*`blur\(\$\{glowConfig\.blurRadius\}px\)`\s*:\s*'blur\(100px\)'/);
assert.match(js, /class\s+TrailParticle/);
assert.match(js, /document\.addEventListener\('mousemove',\s*move\)/);
assert.match(js, /function\s+setupPageNavigation\(\)/);
assert.match(js, /event\.preventDefault\(\)/);
assert.match(js, /page-section--active/);
assert.match(js, /function\s+syncDownloadMenuTarget\(\)/);
assert.match(js, /function\s+setupNavMenus\(\)/);
assert.match(js, /nav-menu-open/);
assert.match(js, /--download-menu-left/);
assert.match(js, /downloadTrigger\.addEventListener\('click'/);
assert.match(js, /const\s+closeDelayMs\s*=\s*220/);
assert.match(js, /const\s+safeZonePadding\s*=\s*18/);
assert.match(js, /const\s+detailHoverDelayMs\s*=\s*120/);
assert.match(js, /const\s+isPointerMovingTowardDetails\s*=\s*\(\)\s*=>/);
assert.match(js, /const\s+scheduleActiveDownloadDetail\s*=/);
assert.match(js, /clearDetailHoverTimer\(\)/);
assert.match(js, /const\s+isPointerNearMenu\s*=\s*\(\)\s*=>/);
assert.match(js, /const\s+scheduleCloseDownloadMenu\s*=\s*\(\)\s*=>/);
assert.match(js, /const\s+left\s*=\s*Math\.round\(rect\.left\)/);
assert.doesNotMatch(js, /const\s+menuWidth\s*=\s*downloadMenu\?\.offsetWidth/);
assert.doesNotMatch(js, /openDownloadMenu[\s\S]*?setActiveDownloadDetail\(activeDownloadDetail\)/);
assert.match(js, /pointermove/);
assert.match(js, /pointerenter/);
assert.match(js, /pointerleave/);
assert.match(js, /nav__links > li:not\(#nav-download-item\)/);
assert.match(js, /nav__actions/);
assert.match(js, /const\s+toggleDownloadMenu\s*=/);
assert.match(js, /const\s+setActiveDownloadDetail\s*=/);
assert.match(js, /downloadMenu\?\.querySelectorAll\('\.nav__dropdown-platform\[data-download-platform\]'\)/);
assert.match(js, /platform\.addEventListener\('pointerenter'/);
assert.doesNotMatch(js, /platform\.addEventListener\('pointerenter',\s*\(\)\s*=>\s*setActiveDownloadDetail/);
assert.match(js, /platform\.addEventListener\('focus'/);
assert.match(js, /mobile-menu--open/);
assert.match(js, /mobile-menu-close/);
assert.match(js, /data-download-platform/);
assert.match(js, /const\s+CROWDFUNDING_URL\s*=\s*'https:\/\/afdian\.com\/a\/MinePixel'/);
assert.match(js, /function\s+detectDevicePlatform\(/);
assert.match(js, /function\s+heroTargetForPlatform\(/);
assert.match(js, /android:\s*\{[\s\S]*?labelKey:\s*'hero\.ctaAndroid'/);
assert.match(js, /desktop:\s*\{[\s\S]*?labelKey:\s*'hero\.ctaWeb'/);
assert.match(js, /ios:\s*\{[\s\S]*?labelKey:\s*'hero\.ctaIos'/);
assert.match(js, /CROWDFUNDING_URL/);
assert.match(js, /const\s+WEB_ONLINE_URL\s*=\s*'https:\/\/kcb\.mc91\.cn\/'/);
assert.match(js, /const\s+detailLinks\s*=\s*Array\.from\(document\.querySelectorAll\('\[data-download-detail-platform\]'\)\)/);
assert.match(js, /const\s+syncLink\s*=\s*\(link,\s*kind\)\s*=>/);
assert.match(js, /detailLinks\.forEach\(\(link\)\s*=>/);
assert.match(js, /link\.classList\.contains\('nav__dropdown-platform'\)/);
assert.match(js, /link\.classList\.contains\('platform-chip'\)/);
assert.match(js, /function\s+renderMarkdown\(/);
assert.match(js, /function\s+setupReadmeMarkdown\(/);
assert.match(js, /const\s+README_SOURCES\s*=\s*\{[\s\S]*?'zh-CN':\s*'\/content\/readme\.zh-CN\.md'[\s\S]*?'en-US':\s*'\/content\/readme\.md'/);
assert.match(js, /fetch\(source,\s*\{\s*cache:\s*'no-store'\s*\}\)/);
assert.match(js, /document\.addEventListener\('localechange',\s*setupReadmeMarkdown\)/);
assert.match(js, /normalizeMarkdownHref/);
assert.match(js, /getComputedStyle\(overlay\)\.getPropertyValue\('--raster-strip-width'\)/);

assert.match(html, /<span class="nav__title" data-i18n="brand\.short">HUE课程表<\/span>/);
assert.match(html, /\/css\/style\.css\?v=20260515-readme-only/);
assert.match(html, /\/js\/app\.js\?v=20260515-readme-only/);
assert.match(html, /class="mobile-header"/);
assert.match(html, /class="mobile-menu"/);
assert.match(html, /class="mobile-menu__header"/);
assert.match(html, /class="mobile-menu__brand"/);
assert.match(html, /id="mobile-menu-close"/);
assert.match(html, /aria-label="移动端导航" data-i18n-attr="aria-label:nav\.mobileAria"/);
assert.match(html, /class="mobile-header__logo-link"[\s\S]*?data-i18n-attr="aria-label:meta\.title"/);
assert.match(html, /id="mobile-menu-toggle"[\s\S]*?data-i18n-attr="aria-label:nav\.openMenuAria"/);
assert.match(html, /id="mobile-menu-close"[\s\S]*?data-i18n-attr="aria-label:nav\.closeMenuAria"/);
assert.doesNotMatch(html, /href="#home" data-page-link="home">\s*<span class="mobile-menu__primary-text" data-i18n="nav\.home">首页<\/span>\s*<span class="mobile-menu__arrow"/);
assert.doesNotMatch(html, /href="#about" data-page-link="about">\s*<span class="mobile-menu__primary-text" data-i18n="nav\.features">产品介绍<\/span>\s*<span class="mobile-menu__arrow"/);
assert.match(html, /id="mobile-download-toggle"[\s\S]*?<span class="mobile-menu__arrow" aria-hidden="true"><\/span>/);
assert.match(html, /data-i18n="platforms\.android">Android<\/span>/);
assert.match(html, /data-i18n="platforms\.ios">iOS<\/span>/);
assert.match(html, /data-i18n="platforms\.web">Web<\/span>/);
assert.match(html, /class="platform-chip platform-chip--active" id="platform-android" data-download-platform="android" href="https:\/\/github\.com\/QingShuishui\/HueKcbPro\/releases\/latest" target="_blank" rel="noopener"/);
assert.match(html, /class="platform-chip platform-chip--planned" data-download-platform="ios" href="https:\/\/afdian\.com\/a\/MinePixel" target="_blank" rel="noopener"/);
assert.match(html, /class="platform-chip platform-chip--planned" data-download-platform="web" href="https:\/\/kcb\.mc91\.cn\/" target="_blank" rel="noopener"/);
assert.match(html, /data-download-platform="web" href="https:\/\/kcb\.mc91\.cn\/" target="_blank" rel="noopener"/);
assert.match(html, /class="nav__dropdown-detail-link" data-download-detail-platform="web" href="https:\/\/kcb\.mc91\.cn\/" target="_blank" rel="noopener"/);
assert.doesNotMatch(html, /data-i18n="platforms\.macos">macOS<\/span>/);
assert.doesNotMatch(html, /data-i18n="platforms\.windows">Windows<\/span>/);
assert.doesNotMatch(html, /data-i18n="platforms\.linux">Linux<\/span>/);
assert.doesNotMatch(html, /data-i18n="platforms\.harmonyos">HarmonyOS<\/span>/);
assert.match(html, /class="nav-menu-mask"/);
assert.match(html, /<nav class="nav" aria-label="主导航" data-i18n-attr="aria-label:nav\.mainAria">/);
assert.match(html, /class="nav__brand"[\s\S]*?data-i18n-attr="aria-label:meta\.title"/);
assert.match(html, /class="nav__spacer nav__spacer--left"/);
assert.match(html, /class="nav__spacer nav__spacer--menu"/);
assert.doesNotMatch(html, /class="nav__dropdown-trigger"[^>]*data-page-link="download"/);
assert.match(html, /data-page-link="about"/);
assert.match(html, /data-page-section="download"/);
assert.match(html, /<section class="section page-section" id="about" data-page-section="about">\s*<div class="about-markdown markdown-body" id="readme-markdown">/);
assert.doesNotMatch(html, /data-markdown-src/);
assert.match(html, /data-i18n="hero\.tagline">HUE课程表<\/span>/);
assert.match(html, /nav__dropdown-trigger/);
assert.match(html, /nav__dropdown-trigger-label/);
assert.match(html, /nav__dropdown-trigger-arrow/);
assert.match(html, /nav__dropdown-platform--active/);
assert.doesNotMatch(html, /id="nav-download-primary"/);
assert.doesNotMatch(html, /class="nav__dropdown-main"/);
assert.match(html, /class="nav__dropdown-content"/);
assert.match(html, /class="nav__dropdown-details"/);
assert.match(html, /nav__dropdown-detail nav__dropdown-detail--android/);
assert.match(html, /nav__dropdown-detail nav__dropdown-detail--ios/);
assert.match(html, /nav__dropdown-detail nav__dropdown-detail--web/);
assert.match(html, /class="nav__dropdown-platform-icon"/);
assert.match(html, /data-i18n="downloadMenu\.androidTitle">下载Android版<\/h3>/);
assert.match(html, /data-download-detail-platform="android" href="https:\/\/github\.com\/QingShuishui\/HueKcbPro\/releases\/latest"/);
assert.match(html, /class="nav__dropdown-detail-link-icon"/);
assert.match(html, /class="nav__dropdown-detail-link-main" data-i18n="downloadMenu\.androidMain">64 位版本下载<\/span>/);
assert.match(html, /class="nav__dropdown-detail-link-note" data-i18n="downloadMenu\.androidNote">适合安卓大部分手机设备<\/span>/);
assert.match(html, /data-i18n="downloadMenu\.iosTitle">iOS 待上架<\/h3>/);
assert.match(html, /data-download-detail-platform="ios" href="https:\/\/afdian\.com\/a\/MinePixel"/);
assert.match(html, /data-i18n="downloadMenu\.iosMain">众筹链接<\/span>/);
assert.match(html, /data-i18n="downloadMenu\.webMain">Web 版本链接<\/span>/);
assert.doesNotMatch(html, /about-extra/);
assert.doesNotMatch(html, /id="screenshots"/);
assert.doesNotMatch(html, /id="tech"/);
assert.doesNotMatch(html, /id="faq"/);
assert.match(html, /class="hero__title-layer hero__title-layer--glow"/);
assert.match(html, /class="hero__title-layer hero__title-layer--front"/);
assert.match(html, /<\/div>\s*<ul class="hero__platforms" aria-label="Supported platforms">/);

const strings = readFileSync(resolve('js/strings.js'), 'utf8');
assert.match(readme, /^# HueKcbPro/m);
assert.match(readme, /## Tech Stack/);
assert.match(readme, /```bash\nflutter pub get\nflutter run\n```/);
assert.doesNotMatch(readme, /\[English\]\(\.\/README\.md\)/);
assert.match(readme, /Real-time refresh for the latest timetable data/);
assert.match(readmeZh, /^# HueKcbPro/m);
assert.match(readmeZh, /## 技术栈/);
assert.match(readmeZh, /```bash\nflutter pub get\nflutter run\n```/);
assert.doesNotMatch(readmeZh, /\[English\]\(\.\/README\.md\)/);
assert.match(readmeZh, /支持实时刷新获取最新课程表/);
assert.match(strings, /'hero\.ctaAndroid':\s*'Android版下载'/);
assert.match(strings, /'features\.markdownLoading':\s*'正在加载项目 README\.\.\.'/);
assert.match(strings, /'features\.markdownError':\s*'README 暂时加载失败，请稍后刷新重试。'/);
assert.match(strings, /'hero\.ctaWeb':\s*'Web在线版本'/);
assert.match(strings, /'hero\.ctaIos':\s*'待众筹上线'/);
assert.match(strings, /'hero\.ctaAndroid':\s*'Download for Android'/);
assert.match(strings, /'hero\.ctaWeb':\s*'Web Online'/);
assert.match(strings, /'hero\.ctaIos':\s*'Crowdfunding for iOS'/);
assert.match(strings, /'brand\.short':\s*'HUE Schedule'/);
assert.match(strings, /'nav\.mainAria':\s*'Main navigation'/);
assert.match(strings, /'downloadMenu\.androidTitle':\s*'Download for Android'/);
assert.match(strings, /'downloadMenu\.androidMain':\s*'64-bit download'/);
assert.match(strings, /'downloadMenu\.androidNote':\s*'For most Android phones'/);
