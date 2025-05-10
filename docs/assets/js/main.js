// assets/js/main.js
document.addEventListener('DOMContentLoaded', () => {
    // 1) Fade in
    document.body.classList.add('page-loaded');
  
    // 2) Catch *all* internal .html links (root or pages/) and animate out
    document.querySelectorAll('a[href$=".html"]').forEach(a => {
      const href = a.getAttribute('href');
      // skip true externals
      if (a.target === '_blank' || href.startsWith('http') || href.startsWith('//')) return;
      a.addEventListener('click', e => {
        e.preventDefault();
        document.body.classList.remove('page-loaded');
        setTimeout(() => window.location.href = href, 500);
      });
    });
  
    // 3) Mobile nav toggle
    const navToggle = document.getElementById('nav-toggle');
    const navMenu   = document.getElementById('nav-menu');
    if (navToggle && navMenu) {
      navToggle.addEventListener('click', () => {
        navMenu.classList.toggle('open');
      });
    }
  });
  