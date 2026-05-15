import { initI18n, getLocale, t } from './i18n.js?v=20260515-qqnav';

const UPDATE_API = '/api/v1/app/update/android';
const GITHUB_RELEASES = 'https://github.com/QingShuishui/HueKcbPro/releases';
const GITHUB_LATEST = 'https://github.com/QingShuishui/HueKcbPro/releases/latest';
const CROWDFUNDING_URL = 'https://afdian.com/a/MinePixel';
const WEB_ONLINE_URL = 'https://kcb.mc91.cn/';
const REPO_BLOB_URL = 'https://github.com/QingShuishui/HueKcbPro/blob/main/';
const README_SOURCES = {
  'zh-CN': '/content/readme.zh-CN.md',
  'en-US': '/content/readme.md',
};

let latestInfo = null;
let fetchError = false;

function formatDate(iso) {
  if (!iso) return '';
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return iso;
  const lang = getLocale();
  const locale = lang === 'en-US' ? 'en-US' : 'zh-CN';
  return date.toLocaleString(locale, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

function effectiveApkUrl(info) {
  const primary = (info?.primary_apk_url || '').trim();
  const fallback = (info?.fallback_apk_url || '').trim();
  return primary || fallback || GITHUB_LATEST;
}

function detectDevicePlatform() {
  const userAgent = navigator.userAgent || '';
  const platform = navigator.platform || '';
  const maxTouchPoints = navigator.maxTouchPoints || 0;
  const isIpadOs = /Macintosh/i.test(userAgent) && maxTouchPoints > 1;

  if (/Android/i.test(userAgent)) return 'android';
  if (/iPhone|iPad|iPod/i.test(userAgent) || isIpadOs) return 'ios';
  if (/Win/i.test(platform) || /Mac/i.test(platform)) return 'desktop';
  return 'desktop';
}

function heroTargetForPlatform(platform, info = latestInfo) {
  const targets = {
    android: {
      href: effectiveApkUrl(info),
      labelKey: 'hero.ctaAndroid',
    },
    desktop: {
      href: WEB_ONLINE_URL,
      labelKey: 'hero.ctaWeb',
    },
    ios: {
      href: CROWDFUNDING_URL,
      labelKey: 'hero.ctaIos',
    },
  };

  return targets[platform] || targets.desktop;
}

function syncDownloadMenuTarget() {
  const platform = detectDevicePlatform();
  const target = heroTargetForPlatform(platform);
  const primary = document.getElementById('nav-download-primary');
  const label = document.getElementById('nav-download-label');
  const platformLinks = Array.from(document.querySelectorAll('[data-download-platform]'));
  const detailLinks = Array.from(document.querySelectorAll('[data-download-detail-platform]'));

  if (primary) primary.href = target.href;
  if (label) label.textContent = t(target.labelKey);

  const syncLink = (link, kind) => {
    if (kind === 'android') {
      link.href = effectiveApkUrl(latestInfo);
    } else if (kind === 'ios') {
      link.href = CROWDFUNDING_URL;
    } else if (kind === 'web') {
      link.href = WEB_ONLINE_URL;
    }
  };

  platformLinks.forEach((link) => {
    const kind = link.dataset.downloadPlatform;
    const isActive = kind === platform;
    if (link.classList.contains('nav__dropdown-platform')) {
      link.classList.toggle('nav__dropdown-platform--active', isActive);
    } else if (link.classList.contains('platform-chip')) {
      link.classList.toggle('platform-chip--active', isActive);
    }
    syncLink(link, kind);
  });

  detailLinks.forEach((link) => {
    syncLink(link, link.dataset.downloadDetailPlatform);
  });
}

function applyHeroDeviceTarget() {
  const platform = detectDevicePlatform();
  const target = heroTargetForPlatform(platform);
  const heroDownload = document.getElementById('hero-download');
  if (heroDownload) {
    heroDownload.href = target.href;
    heroDownload.classList.toggle('hero__cta--error', fetchError && platform === 'android');
  }

  const ctaText = document.getElementById('hero-cta-text');
  if (ctaText) ctaText.textContent = t(target.labelKey);
}

function renderLoaded() {
  if (!latestInfo) return;

  applyHeroDeviceTarget();
  syncDownloadMenuTarget();

  const versionMeta = document.getElementById('hero-version-meta');
  if (versionMeta) {
    versionMeta.classList.remove('hero__version--error');
    versionMeta.textContent = t('hero.versionReady', {
      version: latestInfo.version,
      build: latestInfo.build_number ?? '—',
      published: formatDate(latestInfo.published_at),
    });
  }

  const versionBadge = document.getElementById('download-version');
  if (versionBadge) versionBadge.textContent = `v${latestInfo.version}`;

  const downloadMeta = document.getElementById('download-meta');
  if (downloadMeta) {
    downloadMeta.classList.remove('download-card__meta--error');
    downloadMeta.textContent = t('download.metaReady', {
      published: formatDate(latestInfo.published_at),
    });
  }

  const buildEl = document.getElementById('download-build');
  if (buildEl) buildEl.textContent = latestInfo.build_number ?? '—';

  const publishedEl = document.getElementById('download-published');
  if (publishedEl) publishedEl.textContent = formatDate(latestInfo.published_at) || '—';

  const shaEl = document.getElementById('download-sha');
  if (shaEl) shaEl.textContent = latestInfo.sha256 || '—';

  const notesEl = document.getElementById('download-notes');
  if (notesEl) {
    const notes = (latestInfo.notes || '').trim();
    notesEl.textContent = notes || t('download.notesEmpty');
  }

  const primaryBtn = document.getElementById('download-primary');
  if (primaryBtn) primaryBtn.href = effectiveApkUrl(latestInfo);

  const fallbackBtn = document.getElementById('download-fallback');
  if (fallbackBtn) fallbackBtn.href = GITHUB_RELEASES;
}

function renderError() {
  applyHeroDeviceTarget();
  syncDownloadMenuTarget();

  const versionMeta = document.getElementById('hero-version-meta');
  if (versionMeta) {
    versionMeta.classList.add('hero__version--error');
    versionMeta.textContent = t('hero.versionError');
  }

  const downloadMeta = document.getElementById('download-meta');
  if (downloadMeta) {
    downloadMeta.classList.add('download-card__meta--error');
    downloadMeta.textContent = t('download.metaError');
  }

  const primaryBtn = document.getElementById('download-primary');
  if (primaryBtn) primaryBtn.href = GITHUB_LATEST;

  const notesEl = document.getElementById('download-notes');
  if (notesEl) notesEl.textContent = t('download.notesEmpty');
}

async function loadLatestUpdate() {
  try {
    const res = await fetch(UPDATE_API, { headers: { Accept: 'application/json' } });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    if (!data || !data.version) throw new Error('empty payload');
    latestInfo = data;
    fetchError = false;
    renderLoaded();
  } catch (error) {
    fetchError = true;
    latestInfo = null;
    console.warn('[HueKcbPro] failed to load update info:', error);
    renderError();
  }
}

function setupYear() {
  const yearEl = document.getElementById('year');
  if (yearEl) yearEl.textContent = String(new Date().getFullYear());
}

function setupLocaleReactivity() {
  document.addEventListener('localechange', () => {
    if (fetchError) {
      renderError();
    } else if (latestInfo) {
      renderLoaded();
    }
  });
}

function setupDownloadMenu() {
  syncDownloadMenuTarget();
}

function setupNavMenus() {
  const downloadItem = document.getElementById('nav-download-item');
  const downloadTrigger = document.getElementById('nav-download-trigger');
  const downloadMenu = document.getElementById('nav-download-menu');
  const downloadMask = document.getElementById('nav-menu-mask');
  const mobileToggle = document.getElementById('mobile-menu-toggle');
  const mobileClose = document.getElementById('mobile-menu-close');
  const mobileMenu = document.getElementById('mobile-menu');
  const mobileDownloadItem = document.getElementById('mobile-download-item');
  const mobileDownloadToggle = document.getElementById('mobile-download-toggle');
  const downloadContent = downloadMenu?.querySelector('.nav__dropdown-content');
  const downloadPlatforms = Array.from(downloadMenu?.querySelectorAll('.nav__dropdown-platform[data-download-platform]') || []);
  const hoverCapable = window.matchMedia('(hover: hover) and (pointer: fine)').matches;
  const closeDelayMs = 220;
  const safeZonePadding = 18;
  const detailHoverDelayMs = 120;
  let closeTimer = null;
  let detailHoverTimer = null;
  let pointerPosition = null;
  let previousPointerPosition = null;
  let pointerInMenu = false;
  let activeDownloadDetail = 'android';

  const setActiveDownloadDetail = (platformName = 'android') => {
    activeDownloadDetail = platformName;
    downloadMenu?.classList.add('is-detail-visible');
    downloadContent?.classList.remove('is-detail-android', 'is-detail-ios', 'is-detail-web');
    downloadContent?.classList.add(`is-detail-${platformName}`);
    downloadPlatforms.forEach((platform) => {
      platform.classList.toggle('is-active', platform.dataset.downloadPlatform === platformName);
    });
  };

  const positionDownloadMenu = () => {
    if (!downloadItem) return;
    const rect = downloadItem.getBoundingClientRect();
    const left = Math.round(rect.left);
    document.documentElement.style.setProperty('--download-menu-left', `${left}px`);
  };

  const clearCloseTimer = () => {
    if (closeTimer) {
      window.clearTimeout(closeTimer);
      closeTimer = null;
    }
  };

  const clearDetailHoverTimer = () => {
    if (detailHoverTimer) {
      window.clearTimeout(detailHoverTimer);
      detailHoverTimer = null;
    }
  };

  const isPointerMovingTowardDetails = () => {
    if (!pointerPosition || !previousPointerPosition || !downloadContent) return false;
    if (!downloadContent.classList.contains(`is-detail-${activeDownloadDetail}`)) return false;

    const details = downloadContent.querySelector('.nav__dropdown-details');
    if (!details) return false;

    const detailsRect = details.getBoundingClientRect();
    const movingRight = pointerPosition.x > previousPointerPosition.x;
    const nearDetails = pointerPosition.x >= detailsRect.left - 36;
    const withinDetailsHeight = pointerPosition.y >= detailsRect.top - 18 && pointerPosition.y <= detailsRect.bottom + 18;
    return movingRight && nearDetails && withinDetailsHeight;
  };

  const scheduleActiveDownloadDetail = (platformName) => {
    clearDetailHoverTimer();
    detailHoverTimer = window.setTimeout(() => {
      if (!isPointerMovingTowardDetails()) {
        setActiveDownloadDetail(platformName);
      }
    }, detailHoverDelayMs);
  };

  const isPointerNearMenu = () => {
    if (!pointerPosition || !downloadItem || !downloadMenu || !downloadItem.classList.contains('is-open')) {
      return false;
    }

    const itemRect = downloadItem.getBoundingClientRect();
    const menuRect = downloadMenu.getBoundingClientRect();
    const bounds = {
      left: Math.min(itemRect.left, menuRect.left) - safeZonePadding,
      top: Math.min(itemRect.top, menuRect.top) - safeZonePadding,
      right: Math.max(itemRect.right, menuRect.right) + safeZonePadding,
      bottom: Math.max(itemRect.bottom, menuRect.bottom) + safeZonePadding,
    };

    return (
      pointerPosition.x >= bounds.left &&
      pointerPosition.x <= bounds.right &&
      pointerPosition.y >= bounds.top &&
      pointerPosition.y <= bounds.bottom
    );
  };

  const scheduleCloseDownloadMenu = () => {
    if (!hoverCapable || !downloadItem?.classList.contains('is-open')) return;
    clearCloseTimer();
    closeTimer = window.setTimeout(() => {
      if (!pointerInMenu && !isPointerNearMenu()) {
        closeDownloadMenu();
      }
    }, closeDelayMs);
  };

  const openDownloadMenu = () => {
    if (!downloadItem || !downloadTrigger || !downloadMenu || !downloadMask) return;
    clearCloseTimer();
    positionDownloadMenu();
    downloadItem.classList.add('is-open');
    document.body.classList.add('nav-menu-open');
    downloadTrigger.setAttribute('aria-expanded', 'true');
    downloadMenu.setAttribute('aria-hidden', 'false');
    downloadMask.setAttribute('aria-hidden', 'false');
  };

  const closeDownloadMenu = () => {
    if (!downloadItem || !downloadTrigger || !downloadMenu || !downloadMask) return;
    clearCloseTimer();
    clearDetailHoverTimer();
    downloadItem.classList.remove('is-open');
    downloadMenu.classList.remove('is-detail-visible');
    downloadContent?.classList.remove('is-detail-android', 'is-detail-ios', 'is-detail-web');
    downloadPlatforms.forEach((platform) => platform.classList.remove('is-active'));
    document.body.classList.remove('nav-menu-open');
    downloadTrigger.setAttribute('aria-expanded', 'false');
    downloadMenu.setAttribute('aria-hidden', 'true');
    downloadMask.setAttribute('aria-hidden', 'true');
  };

  const toggleDownloadMenu = () => {
    if (!downloadItem) return;
    if (downloadItem.classList.contains('is-open')) {
      closeDownloadMenu();
    } else {
      openDownloadMenu();
    }
  };

  if (downloadTrigger) {
    downloadTrigger.addEventListener('click', (event) => {
      event.preventDefault();
      toggleDownloadMenu();
    });
    downloadTrigger.addEventListener('keydown', (event) => {
      if (event.key === 'ArrowDown' || event.key === 'Enter' || event.key === ' ') {
        event.preventDefault();
        openDownloadMenu();
      }
    });
  }

  if (downloadItem) {
    if (hoverCapable) {
      downloadItem.addEventListener('pointerenter', () => {
        pointerInMenu = true;
        pointerPosition = null;
        openDownloadMenu();
      });
      downloadItem.addEventListener('pointerleave', (event) => {
        pointerInMenu = false;
        pointerPosition = { x: event.clientX, y: event.clientY };
        scheduleCloseDownloadMenu();
      });
    }
    window.addEventListener('resize', positionDownloadMenu, { passive: true });
    window.addEventListener('pointermove', (event) => {
      if (!hoverCapable) return;
      previousPointerPosition = pointerPosition;
      pointerPosition = { x: event.clientX, y: event.clientY };
      if (downloadItem.classList.contains('is-open') && !pointerInMenu) {
        if (isPointerNearMenu()) {
          clearCloseTimer();
        } else {
          scheduleCloseDownloadMenu();
        }
      }
    }, { passive: true });
    positionDownloadMenu();
  }

  if (downloadMask) {
    downloadMask.addEventListener('click', closeDownloadMenu);
    downloadMask.addEventListener('pointerenter', () => {
      if (hoverCapable) {
        pointerInMenu = false;
        scheduleCloseDownloadMenu();
      }
    });
  }

  downloadMenu?.addEventListener('pointerenter', () => {
    pointerInMenu = true;
    clearCloseTimer();
  });

  downloadMenu?.addEventListener('pointerleave', (event) => {
    pointerInMenu = false;
    clearDetailHoverTimer();
    pointerPosition = { x: event.clientX, y: event.clientY };
    scheduleCloseDownloadMenu();
  });

  downloadPlatforms.forEach((platform) => {
    const platformName = platform.dataset.downloadPlatform || 'android';
    platform.addEventListener('pointerenter', () => scheduleActiveDownloadDetail(platformName));
    platform.addEventListener('pointerleave', clearDetailHoverTimer);
    platform.addEventListener('focus', () => setActiveDownloadDetail(platformName));
  });

  if (hoverCapable) {
    document.querySelectorAll('.nav__links > li:not(#nav-download-item)').forEach((item) => {
      item.addEventListener('pointerenter', () => {
        if (downloadItem?.classList.contains('is-open')) {
          closeDownloadMenu();
        }
      });
    });

    const navActions = document.querySelector('.nav__actions');
    navActions?.addEventListener('pointerenter', () => {
      if (downloadItem?.classList.contains('is-open')) {
        closeDownloadMenu();
      }
    });
  }

  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') closeDownloadMenu();
  });

  const setMobileMenu = (open) => {
    if (!mobileMenu || !mobileToggle) return;
    mobileMenu.classList.toggle('mobile-menu--open', open);
    mobileMenu.setAttribute('aria-hidden', open ? 'false' : 'true');
    mobileToggle.classList.toggle('active', open);
    mobileToggle.setAttribute('aria-expanded', open ? 'true' : 'false');
    document.body.classList.toggle('mobile-menu-open', open);
  };

  if (mobileToggle) {
    mobileToggle.addEventListener('click', () => {
      setMobileMenu(!mobileMenu?.classList.contains('mobile-menu--open'));
    });
  }

  if (mobileClose) {
    mobileClose.addEventListener('click', () => setMobileMenu(false));
  }

  if (mobileDownloadToggle && mobileDownloadItem) {
    mobileDownloadToggle.addEventListener('click', () => {
      const expanded = !mobileDownloadItem.classList.contains('mobile-menu__item--expanded');
      mobileDownloadItem.classList.toggle('mobile-menu__item--expanded', expanded);
      mobileDownloadToggle.setAttribute('aria-expanded', expanded ? 'true' : 'false');
    });
  }

  document.querySelectorAll('.mobile-menu [data-page-link]').forEach((link) => {
    link.addEventListener('click', () => setMobileMenu(false));
  });
}

function setupPageNavigation() {
  const sections = Array.from(document.querySelectorAll('[data-page-section]'));
  const links = Array.from(document.querySelectorAll('[data-page-link]'));
  if (!sections.length || !links.length) return;

  const pageIds = new Set(sections.map((section) => section.dataset.pageSection));

  const setPage = (page, updateHash = true) => {
    const nextPage = pageIds.has(page) ? page : 'home';
    sections.forEach((section) => {
      const isActive = section.dataset.pageSection === nextPage;
      section.classList.toggle('page-section--active', isActive);
      section.toggleAttribute('hidden', !isActive);
    });
    links.forEach((link) => {
      const isActive = link.dataset.pageLink === nextPage;
      link.classList.toggle('nav__link--active', isActive);
      if (isActive) {
        link.setAttribute('aria-current', 'page');
      } else {
        link.removeAttribute('aria-current');
      }
    });
    document.body.dataset.page = nextPage;
    if (updateHash) {
      window.history.pushState({ page: nextPage }, '', `#${nextPage}`);
    }
  };

  links.forEach((link) => {
    link.addEventListener('click', (event) => {
      const page = link.dataset.pageLink;
      if (!page) return;
      event.preventDefault();
      setPage(page);
    });
  });

  window.addEventListener('popstate', () => {
    setPage(window.location.hash.replace('#', '') || 'home', false);
  });

  setPage(window.location.hash.replace('#', '') || 'home', false);
}

function setupHeroCursorGlow() {
  const hero = document.getElementById('home');
  const glow = document.getElementById('cursor-glow');
  const iconGroups = Array.from(document.querySelectorAll('.hidden-icon-group'));
  if (!hero || !glow || window.matchMedia('(pointer: coarse)').matches) return;

  const glowConfig = {
    glowColor: 'rgba(136, 251, 255, 0.35)',
    glowSize: [280, 280],
    trailColor: 'rgba(255, 255, 255, 0.35)',
    blurRadius: 80,
  };
  const glowHost = glow.parentElement || glow;
  const trailParticles = [];
  let frame = 0;
  let trailFrame = 0;
  let targetX = -1000;
  let targetY = -1000;
  let previousX = -1000;
  let previousY = -1000;
  let trailDistance = 0;
  let idleTimer = 0;
  let heroRect = hero.getBoundingClientRect();

  class TrailParticle {
    constructor(x, y) {
      this.x = x;
      this.y = y;
      this.size = 120;
      this.life = 0;
      this.maxLife = Math.random() * 15 + 20;
      this.element = document.createElement('div');
      this.element.className = 'trail-particle';
      this.element.style.background = `radial-gradient(50% 50% at 50% 50%, ${glowConfig.trailColor} 0%, ${glowConfig.trailColor} 100%)`;
      glowHost.appendChild(this.element);
      this.render();
    }

    update() {
      this.life += 1;
      this.render();
      return this.life < this.maxLife;
    }

    render() {
      const opacity = (1 - this.life / this.maxLife) * 0.5;
      this.element.style.transform = `translate3d(${this.x - this.size / 2}px, ${this.y - this.size / 2}px, 0)`;
      this.element.style.opacity = String(Math.max(0, opacity));
    }

    destroy() {
      this.element.remove();
    }
  }

  const stopTrailLoop = () => {
    if (!trailFrame) return;
    window.cancelAnimationFrame(trailFrame);
    trailFrame = 0;
  };

  const runTrailLoop = () => {
    for (let index = trailParticles.length - 1; index >= 0; index -= 1) {
      const particle = trailParticles[index];
      if (!particle.update()) {
        particle.destroy();
        trailParticles.splice(index, 1);
      }
    }

    if (trailParticles.length) {
      trailFrame = window.requestAnimationFrame(runTrailLoop);
    } else {
      trailFrame = 0;
    }
  };

  const ensureTrailLoop = () => {
    if (!trailFrame) trailFrame = window.requestAnimationFrame(runTrailLoop);
  };

  const setGlowState = (active, x = targetX, y = targetY) => {
    const [width, height] = glowConfig.glowSize;
    glow.style.width = active ? `${width}px` : '80px';
    glow.style.height = active ? `${height}px` : '80px';
    glow.style.opacity = active ? '1' : '0';
    glow.style.filter = active ? `blur(${glowConfig.blurRadius}px)` : 'blur(100px)';
    glow.style.background = `radial-gradient(50% 50% at 50% 50%, rgba(255, 255, 255, 0.35) 0%, ${glowConfig.glowColor} 100%)`;
    glow.style.transform = `translate3d(${x}px, ${y}px, 0) translate(-50%, -50%)`;
  };

  const render = () => {
    const localX = targetX - heroRect.left;
    const localY = targetY - heroRect.top;
    setGlowState(true, localX, localY);

    iconGroups.forEach((group, index) => {
      const anchorX = Number(group.dataset.x || 0.5) * heroRect.width;
      const anchorY = Number(group.dataset.y || 0.5) * heroRect.height;
      const dx = localX - anchorX;
      const dy = localY - anchorY;
      const distance = Math.hypot(dx, dy);
      const strength = Math.max(0, 1 - distance / 430);
      const eased = strength * strength * (3 - 2 * strength);
      const moveX = Math.max(-28, Math.min(28, -dx * 0.045));
      const moveY = Math.max(-28, Math.min(28, -dy * 0.045));
      const iconMoveX = Math.max(-10, Math.min(10, -dx * 0.018));
      const iconMoveY = Math.max(-10, Math.min(10, -dy * 0.018));
      const rotate = (index % 2 === 0 ? -1 : 1) * eased * 10;

      group.style.setProperty('--hidden-opacity', String(eased * 0.98));
      group.style.setProperty('--hidden-move-x', `${moveX}px`);
      group.style.setProperty('--hidden-move-y', `${moveY}px`);
      group.style.setProperty('--icon-move-x', `${iconMoveX}px`);
      group.style.setProperty('--icon-move-y', `${iconMoveY}px`);
      group.style.setProperty('--hidden-scale', String(0.94 + eased * 0.08));
      group.style.setProperty('--hidden-rotate', `${rotate}deg`);
    });

    frame = 0;
  };

  const move = (event) => {
    targetX = event.clientX;
    targetY = event.clientY;
    const localX = targetX - heroRect.left;
    const localY = targetY - heroRect.top;

    if (previousX !== -1000 && previousY !== -1000) {
      const dx = targetX - previousX;
      const dy = targetY - previousY;
      trailDistance += Math.hypot(dx, dy);
      if (trailDistance > 8) {
        trailDistance = 0;
        trailParticles.push(new TrailParticle(localX, localY));
        ensureTrailLoop();
        if (trailParticles.length > 30) {
          const particle = trailParticles.shift();
          if (particle) particle.destroy();
        }
      }
    }

    previousX = targetX;
    previousY = targetY;
    setGlowState(true, localX, localY);
    window.clearTimeout(idleTimer);
    idleTimer = window.setTimeout(() => setGlowState(false, localX, localY), 300);
    if (!frame) frame = window.requestAnimationFrame(render);
  };

  const leave = () => {
    setGlowState(false);
    previousX = -1000;
    previousY = -1000;
    trailDistance = 0;
    iconGroups.forEach((group) => {
      group.style.setProperty('--hidden-opacity', '0');
    });
  };

  const measure = () => {
    heroRect = hero.getBoundingClientRect();
    iconGroups.forEach((group) => {
      const x = Number(group.dataset.x || 0.5);
      const y = Number(group.dataset.y || 0.5);
      const iconLeft = Number(group.dataset.iconLeft || 0);
      const iconTop = Number(group.dataset.iconTop || 0);
      group.style.setProperty('--hidden-left', `${x * heroRect.width - 39}px`);
      group.style.setProperty('--hidden-top', `${y * heroRect.height - 39}px`);
      group.style.setProperty('--icon-left', `${iconLeft}px`);
      group.style.setProperty('--icon-top', `${iconTop}px`);
    });
  };

  measure();
  setGlowState(false, -1000, -1000);

  document.addEventListener('mousemove', move);
  document.addEventListener('mouseleave', leave);
  hero.addEventListener('pointerenter', (event) => {
    measure();
    move(event);
  });
  hero.addEventListener('pointerleave', leave);
  window.addEventListener('resize', measure, { passive: true });
  window.addEventListener('scroll', measure, { passive: true });
  window.addEventListener('pagehide', () => {
    window.clearTimeout(idleTimer);
    stopTrailLoop();
    trailParticles.forEach((particle) => particle.destroy());
    trailParticles.length = 0;
  }, { once: true });
}

function setupRasterOverlay() {
  const overlay = document.querySelector('.raster-overlay');
  if (!overlay) return;

  const render = () => {
    const stripWidth = Number.parseFloat(getComputedStyle(overlay).getPropertyValue('--raster-strip-width')) || 36;
    const count = Math.ceil(window.innerWidth / stripWidth) + 2;
    if (overlay.children.length === count) return;

    const fragment = document.createDocumentFragment();
    for (let index = 0; index < count; index += 1) {
      const strip = document.createElement('span');
      strip.className = 'raster-strip';
      fragment.appendChild(strip);
    }

    overlay.replaceChildren(fragment);
  };

  render();
  window.addEventListener('resize', render, { passive: true });
}

function escapeHtml(value) {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function normalizeMarkdownHref(href) {
  const value = href.trim();
  if (/^(https?:|mailto:|#)/i.test(value)) return value;
  return `${REPO_BLOB_URL}${value.replace(/^\.\//, '').replace(/^\//, '')}`;
}

function renderMarkdownInline(text) {
  return escapeHtml(text)
    .replace(/`([^`]+)`/g, '<code>$1</code>')
    .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
    .replace(/\[([^\]]+)\]\(([^)]+)\)/g, (_, label, href) => {
      const safeHref = escapeHtml(normalizeMarkdownHref(href));
      return `<a href="${safeHref}" target="_blank" rel="noopener">${label}</a>`;
    });
}

function renderMarkdown(markdown) {
  const lines = markdown.replace(/\r\n?/g, '\n').split('\n');
  const html = [];
  let inList = false;
  let inCode = false;
  let codeLanguage = '';
  let codeLines = [];

  const closeList = () => {
    if (inList) {
      html.push('</ul>');
      inList = false;
    }
  };

  lines.forEach((line) => {
    const fence = line.match(/^```(\w+)?\s*$/);
    if (fence) {
      if (inCode) {
        html.push(`<pre><code class="language-${escapeHtml(codeLanguage)}">${escapeHtml(codeLines.join('\n'))}</code></pre>`);
        inCode = false;
        codeLanguage = '';
        codeLines = [];
      } else {
        closeList();
        inCode = true;
        codeLanguage = fence[1] || '';
      }
      return;
    }

    if (inCode) {
      codeLines.push(line);
      return;
    }

    if (!line.trim()) {
      closeList();
      return;
    }

    const heading = line.match(/^(#{1,3})\s+(.+)$/);
    if (heading) {
      closeList();
      const level = heading[1].length + 1;
      html.push(`<h${level}>${renderMarkdownInline(heading[2])}</h${level}>`);
      return;
    }

    const listItem = line.match(/^-\s+(.+)$/);
    if (listItem) {
      if (!inList) {
        html.push('<ul>');
        inList = true;
      }
      html.push(`<li>${renderMarkdownInline(listItem[1])}</li>`);
      return;
    }

    closeList();
    html.push(`<p>${renderMarkdownInline(line)}</p>`);
  });

  closeList();
  if (inCode) {
    html.push(`<pre><code class="language-${escapeHtml(codeLanguage)}">${escapeHtml(codeLines.join('\n'))}</code></pre>`);
  }

  return html.join('');
}

async function setupReadmeMarkdown() {
  const container = document.getElementById('readme-markdown');
  const source = README_SOURCES[getLocale()] || README_SOURCES['zh-CN'];
  if (!container || !source) return;

  try {
    container.innerHTML = `<p>${escapeHtml(t('features.markdownLoading'))}</p>`;
    const response = await fetch(source, { cache: 'no-store' });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const markdown = await response.text();
    container.innerHTML = renderMarkdown(markdown);
  } catch (error) {
    console.warn('[HueKcbPro] failed to load README markdown:', error);
    container.textContent = t('features.markdownError');
  }
}

function boot() {
  initI18n();
  setupYear();
  applyHeroDeviceTarget();
  setupDownloadMenu();
  setupNavMenus();
  setupLocaleReactivity();
  setupPageNavigation();
  setupReadmeMarkdown();
  document.addEventListener('localechange', setupReadmeMarkdown);
  setupRasterOverlay();
  setupHeroCursorGlow();
  loadLatestUpdate();
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', boot);
} else {
  boot();
}
