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
// FAQ аккордеон (независимое открытие блоков)
// ────────────────────────────────────────────────────────────────────────

const faqItems = document.querySelectorAll('.faq-item');

faqItems.forEach(item => {
  const question = item.querySelector('.faq-question');
  
  question.addEventListener('click', () => {
    // Переключаем только текущий блок, не закрывая другие
    item.classList.toggle('active');
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

// ────────────────────────────────────────────────────────────────────────
// Parallax эффект для фоновой картинки между блоками
// ────────────────────────────────────────────────────────────────────────

window.addEventListener('scroll', () => {
  const parallaxSections = document.querySelectorAll('.parallax-image-section');
  
  parallaxSections.forEach(parallaxSection => {
    const parallaxBg = parallaxSection.querySelector('.parallax-image-bg');
    
    if (parallaxBg) {
      const rect = parallaxSection.getBoundingClientRect();
      const scrolled = window.pageYOffset;
      const sectionTop = parallaxSection.offsetTop;
      
      // Вычисляем, находится ли секция в viewport
      if (rect.top < window.innerHeight && rect.bottom > 0) {
        // Вычисляем скорость движения картинки (parallax скорость)
        // Картинка двигается медленнее контента для эффекта глубины
        const parallaxSpeed = 0.4;
        // Вычисляем смещение относительно начала секции
        const sectionOffset = scrolled - sectionTop;
        // Применяем parallax с учетом начальной позиции (-50%)
        const yPos = sectionOffset * parallaxSpeed;
        
        // Применяем transform для движения картинки
        parallaxBg.style.transform = `translate3d(0, ${yPos}px, 0)`;
      }
    }
  });
}, { passive: true });

// ────────────────────────────────────────────────────────────────────────
// Карусель для блока "Все возможности в одном приложении"
// ────────────────────────────────────────────────────────────────────────

let currentSlide = 0;
const totalSlides = 5;

// Функция для определения количества видимых слайдов в зависимости от ширины экрана
function getVisibleSlides() {
  return window.innerWidth <= 768 ? 1 : 3;
}

// Функция для получения максимальной позиции слайда
function getMaxSlide() {
  const visibleSlides = getVisibleSlides();
  return Math.max(0, totalSlides - visibleSlides);
}

function updateCarousel() {
  const track = document.getElementById('featuresCarousel');
  
  if (track) {
    track.style.transition = 'transform 0.5s ease-in-out';
    
    // Получаем первый слайд для расчета его ширины
    const slides = track.querySelectorAll('.carousel-slide');
    if (slides.length > 0) {
      const firstSlide = slides[0];
      const slideWidth = firstSlide.offsetWidth;
      
      // Получаем gap из computed style и конвертируем в пиксели
      const trackStyle = window.getComputedStyle(track);
      const gapValue = trackStyle.gap;
      let gap = 0;
      
      if (gapValue) {
        // Если gap в rem, конвертируем в px
        if (gapValue.includes('rem')) {
          const remValue = parseFloat(gapValue);
          gap = remValue * parseFloat(getComputedStyle(document.documentElement).fontSize);
        } else {
          // Если gap в px или других единицах, просто парсим число
          gap = parseFloat(gapValue) || 0;
        }
      }
      
      // Вычисляем смещение: ширина слайда + gap
      const offset = currentSlide * (slideWidth + gap);
      track.style.transform = `translateX(-${offset}px)`;
    }
  }
  
  // Обновляем изображение "Маркет" в зависимости от позиции
  updateMarketImage();
  // Обновляем изображение "Задачи" в зависимости от позиции
  updateTaskImage();
}

function updateMarketImage() {
  const visibleSlides = getVisibleSlides();
  
  // На мобильных устройствах не меняем изображения
  if (visibleSlides === 1) {
    return;
  }
  
  // Центральный слайд: для десктопа (3 слайда) = currentSlide + 1
  const centerSlideIndex = currentSlide + 1;
  
  // Находим все слайды в карусели
  const slides = document.querySelectorAll('#featuresCarousel .carousel-slide');
  
  slides.forEach((slide, index) => {
    const marketImg = slide.querySelector('img[alt="Маркет"]');
    if (marketImg) {
      const isCenter = index === centerSlideIndex;
      
      if (isCenter) {
        // Когда слайд в центре - показываем market.png
        if (!marketImg.src.includes('market.png')) {
          marketImg.style.transition = 'opacity 0.5s ease-in-out';
          marketImg.style.opacity = '0';
          setTimeout(() => {
            marketImg.src = 'img/market.png';
            marketImg.style.opacity = '1';
          }, 250);
        }
      } else {
        // Когда слайд уходит из центра - показываем goods.png
        if (!marketImg.src.includes('goods.png')) {
          marketImg.style.transition = 'opacity 0.5s ease-in-out';
          marketImg.style.opacity = '0';
          setTimeout(() => {
            marketImg.src = 'img/goods.png';
            marketImg.style.opacity = '1';
          }, 250);
        }
      }
    }
  });
}

function updateTaskImage() {
  const visibleSlides = getVisibleSlides();
  
  // На мобильных устройствах не меняем изображения
  if (visibleSlides === 1) {
    return;
  }
  
  // Центральный слайд: для десктопа (3 слайда) = currentSlide + 1
  const centerSlideIndex = currentSlide + 1;
  
  // Находим все слайды в карусели
  const slides = document.querySelectorAll('#featuresCarousel .carousel-slide');
  
  slides.forEach((slide, index) => {
    const taskImg = slide.querySelector('img[alt="Задачи"]');
    if (taskImg) {
      const isCenter = index === centerSlideIndex;
      
      if (isCenter) {
        // Когда слайд в центре - показываем rewards.png
        if (!taskImg.src.includes('rewards.png')) {
          taskImg.style.transition = 'opacity 0.5s ease-in-out';
          taskImg.style.opacity = '0';
          setTimeout(() => {
            taskImg.src = 'img/rewards.png';
            taskImg.style.opacity = '1';
          }, 250);
        }
      } else {
        // Когда слайд уходит из центра - показываем task.png
        if (!taskImg.src.includes('task.png')) {
          taskImg.style.transition = 'opacity 0.5s ease-in-out';
          taskImg.style.opacity = '0';
          setTimeout(() => {
            taskImg.src = 'img/task.png';
            taskImg.style.opacity = '1';
          }, 250);
        }
      }
    }
  });
}

function nextSlide() {
  const maxSlide = getMaxSlide();
  if (currentSlide < maxSlide) {
    currentSlide++;
  } else {
    currentSlide = 0; // Зацикливаем в начало
  }
  updateCarousel();
}

function prevSlide() {
  const maxSlide = getMaxSlide();
  if (currentSlide > 0) {
    currentSlide--;
  } else {
    currentSlide = maxSlide; // Зацикливаем в конец
  }
  updateCarousel();
}

function goToSlide(index) {
  const maxSlide = getMaxSlide();
  if (index >= 0 && index <= maxSlide) {
    currentSlide = index;
    updateCarousel();
  }
}

// Инициализация изображений при загрузке
updateMarketImage();
updateTaskImage();

// Обработчик изменения размера окна для адаптивности карусели
window.addEventListener('resize', () => {
  const maxSlide = getMaxSlide();
  // Если текущая позиция больше максимальной после изменения размера, сбрасываем на максимум
  if (currentSlide > maxSlide) {
    currentSlide = maxSlide;
  }
  updateCarousel();
});

// Автоматическое переключение слайдов каждые 5 секунд
setInterval(() => {
  nextSlide();
}, 6000);
