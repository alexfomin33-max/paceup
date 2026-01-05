// ────────────────────────────────────────────────────────────────────────
// Навигация (мобильное меню)
// ────────────────────────────────────────────────────────────────────────

const navToggle = document.getElementById('navToggle');
const navMenu = document.getElementById('navMenu');

if (navToggle) {
  navToggle.addEventListener('click', () => {
    navMenu.classList.toggle('active');
  });
}

// Закрытие меню при клике на ссылку
const navLinks = document.querySelectorAll('.nav-menu a');
navLinks.forEach(link => {
  link.addEventListener('click', () => {
    navMenu.classList.remove('active');
  });
});

// ────────────────────────────────────────────────────────────────────────
// Плавная прокрутка
// ────────────────────────────────────────────────────────────────────────

document.querySelectorAll('a[href^="#"]').forEach(anchor => {
  anchor.addEventListener('click', function (e) {
    e.preventDefault();
    const target = document.querySelector(this.getAttribute('href'));
    if (target) {
      target.scrollIntoView({
        behavior: 'smooth',
        block: 'start'
      });
    }
  });
});

// ────────────────────────────────────────────────────────────────────────
// Анимация счетчиков статистики
// ────────────────────────────────────────────────────────────────────────

function animateCounter(element, target, duration = 2000) {
  let start = 0;
  const increment = target / (duration / 16);
  
  const timer = setInterval(() => {
    start += increment;
    if (start >= target) {
      element.textContent = formatNumber(target);
      clearInterval(timer);
    } else {
      element.textContent = formatNumber(Math.floor(start));
    }
  }, 16);
}

function formatNumber(num) {
  if (num >= 1000) {
    return (num / 1000).toFixed(1) + 'K';
  }
  return Math.floor(num).toString();
}

// Запуск анимации при появлении в viewport
const observerOptions = {
  threshold: 0.5,
  rootMargin: '0px'
};

const statsObserver = new IntersectionObserver((entries) => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      const statNumber = entry.target.querySelector('.stat-number');
      const target = parseFloat(statNumber.getAttribute('data-target'));
      
      if (target) {
        animateCounter(statNumber, target);
        statsObserver.unobserve(entry.target);
      }
    }
  });
}, observerOptions);

document.querySelectorAll('.stat-item').forEach(item => {
  statsObserver.observe(item);
});

// ────────────────────────────────────────────────────────────────────────
// FAQ аккордеон
// ────────────────────────────────────────────────────────────────────────

const faqItems = document.querySelectorAll('.faq-item');

faqItems.forEach(item => {
  const question = item.querySelector('.faq-question');
  
  question.addEventListener('click', () => {
    const isActive = item.classList.contains('active');
    
    // Закрываем все остальные
    faqItems.forEach(otherItem => {
      if (otherItem !== item) {
        otherItem.classList.remove('active');
      }
    });
    
    // Переключаем текущий
    item.classList.toggle('active', !isActive);
  });
});

// ────────────────────────────────────────────────────────────────────────
// Эффект параллакса для hero секции
// ────────────────────────────────────────────────────────────────────────

window.addEventListener('scroll', () => {
  const scrolled = window.pageYOffset;
  const hero = document.querySelector('.hero');
  
  if (hero) {
    const heroContent = hero.querySelector('.hero-content');
    if (heroContent && scrolled < window.innerHeight) {
      heroContent.style.transform = `translateY(${scrolled * 0.5}px)`;
      heroContent.style.opacity = 1 - (scrolled / window.innerHeight);
    }
  }
});

// ────────────────────────────────────────────────────────────────────────
// Анимация появления элементов при скролле
// ────────────────────────────────────────────────────────────────────────

const fadeInObserver = new IntersectionObserver((entries) => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      entry.target.style.opacity = '1';
      entry.target.style.transform = 'translateY(0)';
    }
  });
}, {
  threshold: 0.1,
  rootMargin: '0px 0px -50px 0px'
});

// Применяем анимацию к карточкам
document.querySelectorAll('.feature-card, .testimonial-card, .step-item, .screenshot-item').forEach(item => {
  item.style.opacity = '0';
  item.style.transform = 'translateY(30px)';
  item.style.transition = 'opacity 0.6s ease, transform 0.6s ease';
  fadeInObserver.observe(item);
});

// ────────────────────────────────────────────────────────────────────────
// Изменение навбара при скролле
// ────────────────────────────────────────────────────────────────────────

let lastScroll = 0;
const navbar = document.querySelector('.navbar');

window.addEventListener('scroll', () => {
  const currentScroll = window.pageYOffset;
  
  if (currentScroll > 100) {
    navbar.style.boxShadow = '0 4px 16px rgba(0, 0, 0, 0.12)';
  } else {
    navbar.style.boxShadow = '0 2px 8px rgba(0, 0, 0, 0.08)';
  }
  
  lastScroll = currentScroll;
});

