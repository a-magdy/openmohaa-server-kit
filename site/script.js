/**
 * MOHAA COMPOSITE VARIANT — script.js
 *
 * Feature inventory:
 *  1. Viewport custom properties (--vw / --dvh)
 *  2. Lenis@1.1.14 smooth scroll, connected to GSAP ticker
 *  3. Reading progress bar (#readingProgress)
 *  4. Scroll-pinned chapter numeral (#chapterNumeralFixed)
 *  5. GSAP ScrollTrigger.batch reveals on .reveal-up
 *  6. Hero word-wrapped letter rise (Cinzel, per-word)
 *  7. Hero .reveal-fade entrance on load
 *  8. Three.js particle smoke behind hero (IntersectionObserver pause)
 *     → CSS gradient fallback if WebGL unavailable
 *  9. Briefing redacted-bar reveal (IntersectionObserver)
 * 10. Letterbox bars fade-out past hero
 * 11. Platform tabs
 * 12. FAQ accordion
 * 13. Lenis anchor-link integration
 * 14. prefers-reduced-motion: disables Lenis, GSAP, Three.js loop, letter-rise
 */

(function () {
  'use strict';

  /* ── 0. Reduced-motion gate ──────────────────────────────── */
  const prefersReducedMotion = window.matchMedia(
    '(prefers-reduced-motion: reduce)'
  ).matches;

  /* ── 1. Viewport CSS variables ───────────────────────────── */
  function setViewportVars() {
    document.documentElement.style.setProperty(
      '--vw', `${window.innerWidth * 0.01}px`
    );
    document.documentElement.style.setProperty(
      '--dvh', `${window.innerHeight * 0.01}px`
    );
  }
  setViewportVars();
  window.addEventListener('resize', setViewportVars, { passive: true });

  /* ── 2. Lenis smooth scroll ──────────────────────────────── */
  let lenis = null;

  if (!prefersReducedMotion && typeof Lenis !== 'undefined') {
    lenis = new Lenis({
      duration: 1.25,
      easing: (t) => Math.min(1, 1.001 - Math.pow(2, -10 * t)),
      smoothWheel: true,
      wheelMultiplier: 1,
      touchMultiplier: 1.8,
    });

    document.documentElement.classList.add('lenis');

    // Connect to GSAP ticker — no separate rAF loop
    if (typeof gsap !== 'undefined' && typeof ScrollTrigger !== 'undefined') {
      lenis.on('scroll', ScrollTrigger.update);
      gsap.ticker.add((time) => lenis.raf(time * 1000));
      gsap.ticker.lagSmoothing(0);
    }
  }

  /* ── 3. Reading progress bar ─────────────────────────────── */
  const progressBar = document.getElementById('readingProgress');

  function updateProgress() {
    if (!progressBar) return;
    const scrollTop = window.scrollY || document.documentElement.scrollTop;
    const docH = document.documentElement.scrollHeight
               - document.documentElement.clientHeight;
    const pct = docH > 0 ? (scrollTop / docH) * 100 : 0;
    progressBar.style.width = Math.min(100, Math.max(0, pct)) + '%';
  }

  window.addEventListener('scroll', updateProgress, { passive: true });
  updateProgress();

  /* ── 4. Scroll-pinned chapter numeral ────────────────────── */
  const chapterNumeralEl = document.getElementById('chapterNumeralFixed');
  const chapters = Array.from(
    document.querySelectorAll('.chapter[data-chapter]')
  );

  if (chapterNumeralEl && chapters.length) {
    let currentChapter = null;

    const chObs = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            const label = entry.target.getAttribute('data-chapter');
            if (label && label !== currentChapter) {
              currentChapter = label;
              chapterNumeralEl.style.opacity = '0';
              setTimeout(() => {
                chapterNumeralEl.textContent = label;
                chapterNumeralEl.style.opacity = '0.11';
              }, 280);
            }
          }
        });
      },
      { threshold: 0, rootMargin: '-40% 0px -40% 0px' }
    );

    chapters.forEach((ch) => chObs.observe(ch));
  }

  /* ── 5. GSAP ScrollTrigger.batch reveals ─────────────────── */
  if (
    !prefersReducedMotion &&
    typeof gsap !== 'undefined' &&
    typeof ScrollTrigger !== 'undefined'
  ) {
    gsap.registerPlugin(ScrollTrigger);

    // Exclude .hero .reveal-up (handled separately below)
    // and exclude .pull-quote from batch
    ScrollTrigger.batch(
      '.reveal-up:not(.hero .reveal-up):not(.pull-quote)',
      {
        start: 'top 88%',
        onEnter: (batch) => {
          gsap.fromTo(
            batch,
            { opacity: 0, y: 38 },
            {
              opacity: 1,
              y: 0,
              duration: 1.0,
              ease: 'power3.out',
              stagger: 0.1,
            }
          );
        },
        once: true,
      }
    );

    /* Chapter label blocks slide in from left */
    document.querySelectorAll('.chapter-label-block').forEach((block) => {
      gsap.fromTo(
        block,
        { opacity: 0, x: -20 },
        {
          opacity: 1,
          x: 0,
          duration: 1.0,
          ease: 'power3.out',
          scrollTrigger: {
            trigger: block,
            start: 'top 92%',
            toggleActions: 'play none none none',
          },
        }
      );
    });
  }

  /* ── 6. Hero word-wrapped letter rise ────────────────────── */
  (function initHeroLetterRise() {
    const titleEl = document.getElementById('heroTitle');
    if (!titleEl) return;

    // Words are pre-marked with .word spans in HTML
    // Each word span receives individual letter .char spans
    const wordSpans = titleEl.querySelectorAll('.word');

    wordSpans.forEach((wordSpan) => {
      const text = wordSpan.textContent;
      wordSpan.textContent = '';

      Array.from(text).forEach((ch) => {
        const span = document.createElement('span');
        span.className = 'char';
        span.textContent = ch;
        span.setAttribute('aria-hidden', 'true');
        wordSpan.appendChild(span);
      });
    });

    const allChars = Array.from(titleEl.querySelectorAll('.char'));

    if (prefersReducedMotion) {
      allChars.forEach((c) => {
        c.style.opacity = '1';
        c.style.transform = 'none';
      });
      return;
    }

    if (typeof gsap !== 'undefined') {
      gsap.to(allChars, {
        opacity: 1,
        y: 0,
        duration: 0.8,
        stagger: 0.048,
        ease: 'power3.out',
        delay: 0.5,
      });
    } else {
      // Fallback: CSS transition
      allChars.forEach((c, i) => {
        c.style.transition = `opacity 0.7s ease ${0.4 + i * 0.05}s, transform 0.7s ease ${0.4 + i * 0.05}s`;
        requestAnimationFrame(() => {
          c.style.opacity = '1';
          c.style.transform = 'none';
        });
      });
    }
  })();

  /* ── 7. Hero reveal-fade elements ───────────────────────── */
  (function initHeroFades() {
    const fades = document.querySelectorAll('.hero .reveal-fade');
    if (!fades.length) return;

    if (prefersReducedMotion) {
      fades.forEach((el) => { el.style.opacity = '1'; });
      return;
    }

    if (typeof gsap !== 'undefined') {
      gsap.to(fades, {
        opacity: 1,
        duration: 1.1,
        stagger: 0.18,
        ease: 'power2.out',
        delay: 1.9,
      });
    }
  })();

  /* ── 8. Three.js particle smoke ──────────────────────────── */
  (function initParticles() {
    if (prefersReducedMotion) return;

    const canvas = document.getElementById('particle-canvas');
    if (!canvas) return;

    // WebGL check
    let hasWebGL = false;
    try {
      const test = document.createElement('canvas').getContext('webgl');
      if (test) hasWebGL = true;
    } catch (_) { /* noop */ }

    if (!hasWebGL || typeof THREE === 'undefined') return;

    const W = canvas.offsetWidth  || window.innerWidth;
    const H = canvas.offsetHeight || window.innerHeight;

    const scene    = new THREE.Scene();
    const camera   = new THREE.PerspectiveCamera(60, W / H, 0.1, 200);
    camera.position.set(0, 0, 50);

    const renderer = new THREE.WebGLRenderer({ canvas, alpha: true, antialias: false });
    renderer.setSize(W, H);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    renderer.setClearColor(0x000000, 0);

    const PARTICLES = 1200;
    const positions  = new Float32Array(PARTICLES * 3);
    const velocities = [];

    for (let i = 0; i < PARTICLES; i++) {
      positions[i * 3 + 0] = (Math.random() - 0.5) * 140;
      positions[i * 3 + 1] = (Math.random() - 0.5) * 80;
      positions[i * 3 + 2] = (Math.random() - 0.5) * 40;

      velocities.push({
        x: (Math.random() - 0.5) * 0.012,
        y:  Math.random() * 0.016 + 0.004,
        z: (Math.random() - 0.5) * 0.008,
      });
    }

    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.BufferAttribute(positions, 3));

    const mat = new THREE.PointsMaterial({
      color: 0xc4a97a, /* warm sepia */
      size: 0.32,
      transparent: true,
      opacity: 0.18,
      sizeAttenuation: true,
      depthWrite: false,
    });

    const pts = new THREE.Points(geo, mat);
    scene.add(pts);

    let isVisible = true;

    const heroEl = document.getElementById('hero');
    const heroObs = new IntersectionObserver(
      (entries) => { isVisible = entries[0].isIntersecting; },
      { threshold: 0 }
    );
    if (heroEl) heroObs.observe(heroEl);

    window.addEventListener('resize', () => {
      const w = window.innerWidth;
      const h = window.innerHeight;
      camera.aspect = w / h;
      camera.updateProjectionMatrix();
      renderer.setSize(w, h);
    });

    const posAttr = geo.attributes.position;

    function animate() {
      requestAnimationFrame(animate);
      if (!isVisible) return;

      for (let i = 0; i < PARTICLES; i++) {
        posAttr.array[i * 3 + 0] += velocities[i].x;
        posAttr.array[i * 3 + 1] += velocities[i].y;
        posAttr.array[i * 3 + 2] += velocities[i].z;

        if (posAttr.array[i * 3 + 1] > 45) {
          posAttr.array[i * 3 + 1] = -45;
          posAttr.array[i * 3 + 0] = (Math.random() - 0.5) * 140;
        }
      }

      posAttr.needsUpdate = true;

      const t = Date.now() * 0.00003;
      camera.position.x = Math.sin(t) * 2;
      camera.position.y = Math.cos(t * 0.7) * 1.2;

      renderer.render(scene, camera);
    }

    animate();
  })();

  /* ── 9. Briefing redacted-bar reveal ─────────────────────── */
  (function initRedactedBars() {
    const wraps = document.querySelectorAll('.redact-wrap');
    if (!wraps.length) return;

    if (prefersReducedMotion) {
      wraps.forEach((w) => w.classList.add('revealed'));
      return;
    }

    const obs = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            setTimeout(() => entry.target.classList.add('revealed'), 400);
            obs.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.7 }
    );

    wraps.forEach((w) => obs.observe(w));
  })();

  /* ── 10. Letterbox fade past hero ────────────────────────── */
  if (lenis) {
    lenis.on('scroll', ({ scroll }) => {
      const threshold = window.innerHeight * 0.3;
      document.body.classList.toggle('past-hero', scroll > threshold);
    });
  } else {
    window.addEventListener('scroll', () => {
      const threshold = window.innerHeight * 0.3;
      document.body.classList.toggle(
        'past-hero', window.scrollY > threshold
      );
    }, { passive: true });
  }

  /* ── 11. Platform tabs ───────────────────────────────────── */
  document.querySelectorAll('[data-tabs]').forEach((tabGroup) => {
    const buttons = tabGroup.querySelectorAll('.ptab-btn');
    const panes   = tabGroup.querySelectorAll('.ptab-pane');

    buttons.forEach((btn) => {
      btn.addEventListener('click', () => {
        const platform = btn.getAttribute('data-platform');

        buttons.forEach((b) => {
          b.classList.remove('active');
          b.setAttribute('aria-selected', 'false');
        });
        panes.forEach((p) => p.classList.remove('active'));

        btn.classList.add('active');
        btn.setAttribute('aria-selected', 'true');

        const targetPane = tabGroup.querySelector(`#${platform}`);
        if (targetPane) targetPane.classList.add('active');
      });
    });
  });

  /* ── 12. FAQ accordion ───────────────────────────────────── */
  document.querySelectorAll('.faq-question').forEach((btn) => {
    btn.addEventListener('click', () => {
      const item   = btn.closest('.faq-item');
      const isOpen = item.classList.contains('open');

      // Close all
      document.querySelectorAll('.faq-item.open').forEach((openItem) => {
        openItem.classList.remove('open');
      });

      if (!isOpen) item.classList.add('open');
    });

    btn.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        btn.click();
      }
    });
  });

  /* ── 13. Anchor smooth scroll ────────────────────────────── */
  const navToggle = document.getElementById("nav-toggle");

  document.querySelectorAll('a[href^="#"]').forEach((anchor) => {
    anchor.addEventListener('click', (e) => {
      const id = anchor.getAttribute("href").slice(1);
      if (!id) return;
      const target = document.getElementById(id);
      if (!target) return;
      e.preventDefault();

      // Close mobile drawer
      if (navToggle) navToggle.checked = false;

      if (lenis) {
        lenis.scrollTo(target, { offset: -70, duration: 1.4 });
      } else {
        target.scrollIntoView({ behavior: "smooth", block: "start" });
      }
    });
  });

})();
