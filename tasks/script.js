// ────────────────────────────────────────────────────────────────────────
// Управление задачами
// ────────────────────────────────────────────────────────────────────────

class TaskManager {
  constructor() {
    this.tasks = [];
    this.nextId = 1;
    this.selectedIcon = null; // 'human' или 'robot'
    this.init();
  }

  init() {
    this.loadTasks();
    this.renderTasks();
    this.setupEventListeners();
    this.updateCounts();
  }

  // ────────────────────────────────────────────────────────────────────────
  // Загрузка и сохранение
  // ────────────────────────────────────────────────────────────────────────

  loadTasks() {
    const saved = localStorage.getItem('tasks');
    if (saved) {
      this.tasks = JSON.parse(saved);
      // Находим максимальный ID для продолжения нумерации
      if (this.tasks.length > 0) {
        this.nextId = Math.max(...this.tasks.map(t => t.id)) + 1;
      }
    }
  }

  saveTasks() {
    localStorage.setItem('tasks', JSON.stringify(this.tasks));
  }

  // ────────────────────────────────────────────────────────────────────────
  // Управление задачами
  // ────────────────────────────────────────────────────────────────────────

  addTask(text) {
    if (!text || text.trim() === '') {
      return;
    }

    const task = {
      id: this.nextId++,
      text: text.trim(),
      completed: false,
      createdAt: Date.now(),
      iconType: this.selectedIcon || null, // 'human', 'robot' или null
    };

    this.tasks.push(task);
    this.saveTasks();
    this.renderTasks();
    this.updateCounts();

    // Анимация bounce для новой задачи
    requestAnimationFrame(() => {
      const taskItem = document.querySelector(`[data-task-id="${task.id}"]`);
      if (taskItem) {
        taskItem.style.animation = 'bounce 0.5s ease-out';
        setTimeout(() => {
          taskItem.style.animation = '';
        }, 500);
      }
    });
  }

  completeTask(id) {
    const task = this.tasks.find(t => t.id === id);
    if (!task || task.completed) return;

    // Анимация перемещения
    const taskItem = document.querySelector(`[data-task-id="${id}"]`);
    if (taskItem) {
      taskItem.classList.add('moving');
      
      setTimeout(() => {
        task.completed = true;
        this.saveTasks();
        this.renderTasks();
        this.updateCounts();
      }, 500);
    }
  }

  restoreTask(id) {
    const task = this.tasks.find(t => t.id === id);
    if (!task || !task.completed) return;

    task.completed = false;
    this.saveTasks();
    this.renderTasks();
    this.updateCounts();
  }

  deleteTask(id) {
    const taskItem = document.querySelector(`[data-task-id="${id}"]`);
    if (taskItem) {
      taskItem.classList.add('removing');
      
      setTimeout(() => {
        this.tasks = this.tasks.filter(t => t.id !== id);
        this.saveTasks();
        this.renderTasks();
        this.updateCounts();
      }, 300);
    }
  }

  editTask(id, newText) {
    const task = this.tasks.find(t => t.id === id);
    if (!task) return;

    task.text = newText.trim() || task.text;
    this.saveTasks();
    this.renderTasks();
  }

  // ────────────────────────────────────────────────────────────────────────
  // Рендеринг
  // ────────────────────────────────────────────────────────────────────────

  renderTasks() {
    const activeList = document.getElementById('activeTasksList');
    const completedList = document.getElementById('completedTasksList');

    const activeTasks = this.tasks.filter(t => !t.completed);
    const completedTasks = this.tasks.filter(t => t.completed);

    activeList.innerHTML = '';
    completedList.innerHTML = '';

    activeTasks.forEach((task) => {
      activeList.appendChild(this.createTaskElement(task, 0, false));
    });

    completedTasks.forEach((task) => {
      completedList.appendChild(this.createTaskElement(task, 0, true));
    });
  }

  createTaskElement(task, number, isCompleted) {
    // Карточка задачи
    const taskItem = document.createElement('div');
    taskItem.className = `task-item ${task.completed ? 'completed-task' : ''}`;
    taskItem.setAttribute('data-task-id', task.id);

    // Иконка задачи (если есть)
    if (task.iconType) {
      const taskIcon = document.createElement('div');
      taskIcon.className = `task-item-icon task-item-icon-${task.iconType}`;
      taskIcon.textContent = task.iconType === 'human' ? '🧔' : '🤖';
      taskItem.appendChild(taskIcon);
    }

    // Контент задачи
    const taskContent = document.createElement('div');
    taskContent.className = 'task-content';

    const taskText = document.createElement('div');
    taskText.className = 'task-text';
    taskText.textContent = task.text;
    taskText.addEventListener('dblclick', () => {
      this.startEditing(task.id, taskText);
    });

    taskContent.appendChild(taskText);

    // Кнопки действий
    const taskActions = document.createElement('div');
    taskActions.className = 'task-actions';

    if (!task.completed) {
      // Кнопка редактирования
      const editBtn = document.createElement('button');
      editBtn.className = 'btn-action btn-edit';
      editBtn.innerHTML = '✎';
      editBtn.setAttribute('aria-label', 'Редактировать');
      editBtn.addEventListener('click', () => {
        this.startEditing(task.id, taskText);
      });
      taskActions.appendChild(editBtn);

      // Кнопка выполнения
      const completeBtn = document.createElement('button');
      completeBtn.className = 'btn-action btn-complete';
      completeBtn.innerHTML = '✓';
      completeBtn.setAttribute('aria-label', 'Выполнено');
      completeBtn.addEventListener('click', () => {
        this.completeTask(task.id);
      });
      taskActions.appendChild(completeBtn);

      // Кнопка удаления (только для текущих задач)
      const deleteBtn = document.createElement('button');
      deleteBtn.className = 'btn-action btn-delete';
      deleteBtn.innerHTML = '×';
      deleteBtn.setAttribute('aria-label', 'Удалить');
      deleteBtn.addEventListener('click', () => {
        this.deleteTask(task.id);
      });
      taskActions.appendChild(deleteBtn);
    } else {
      const restoreBtn = document.createElement('button');
      restoreBtn.className = 'btn-action btn-restore';
      restoreBtn.innerHTML = '↻';
      restoreBtn.setAttribute('aria-label', 'Восстановить');
      restoreBtn.addEventListener('click', () => {
        this.restoreTask(task.id);
      });
      taskActions.appendChild(restoreBtn);
    }

    // Сборка элемента
    taskItem.appendChild(taskContent);
    taskItem.appendChild(taskActions);

    return taskItem;
  }

  // ────────────────────────────────────────────────────────────────────────
  // Редактирование
  // ────────────────────────────────────────────────────────────────────────

  startEditing(id, textElement) {
    const task = this.tasks.find(t => t.id === id);
    if (!task) return;

    const currentText = task.text;
    const input = document.createElement('textarea');
    input.className = 'task-text-input';
    input.value = currentText;
    input.rows = Math.max(2, Math.ceil(currentText.length / 50));

    textElement.classList.add('editing');
    textElement.replaceWith(input);

    input.focus();
    input.select();

    const finishEditing = () => {
      const newText = input.value.trim();
      if (newText !== currentText) {
        this.editTask(id, newText);
      }
      
      const newTextElement = document.createElement('div');
      newTextElement.className = 'task-text';
      newTextElement.textContent = newText || currentText;
      newTextElement.addEventListener('dblclick', () => {
        this.startEditing(id, newTextElement);
      });
      
      input.replaceWith(newTextElement);
    };

    input.addEventListener('blur', finishEditing);
    input.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) {
        finishEditing();
      } else if (e.key === 'Escape') {
        const newTextElement = document.createElement('div');
        newTextElement.className = 'task-text';
        newTextElement.textContent = currentText;
        newTextElement.addEventListener('dblclick', () => {
          this.startEditing(id, newTextElement);
        });
        input.replaceWith(newTextElement);
      }
    });
  }

  // ────────────────────────────────────────────────────────────────────────
  // Обновление счетчиков
  // ────────────────────────────────────────────────────────────────────────

  updateCounts() {
    const activeCount = this.tasks.filter(t => !t.completed).length;
    const completedCount = this.tasks.filter(t => t.completed).length;

    document.getElementById('activeTasksCount').textContent = activeCount;
    document.getElementById('completedTasksCount').textContent = completedCount;
  }

  // ────────────────────────────────────────────────────────────────────────
  // Обработчики событий
  // ────────────────────────────────────────────────────────────────────────

  setupEventListeners() {
    const taskInput = document.getElementById('taskInput');
    const addTaskBtn = document.getElementById('addTaskBtn');
    const humanIcon = document.querySelector('.task-icon-human');
    const robotIcon = document.querySelector('.task-icon-robot');

    // Выбор иконки
    if (humanIcon) {
      humanIcon.addEventListener('click', () => {
        this.selectIcon('human');
      });
    }

    if (robotIcon) {
      robotIcon.addEventListener('click', () => {
        this.selectIcon('robot');
      });
    }

    // Добавление задачи по кнопке
    addTaskBtn.addEventListener('click', () => {
      const text = taskInput.value;
      if (text.trim()) {
        this.addTask(text);
        taskInput.value = '';
        taskInput.style.height = 'auto';
        this.selectedIcon = null;
        this.updateIconSelection();
      }
    });

    // Добавление задачи по Enter (Ctrl+Enter или Cmd+Enter)
    taskInput.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) {
        e.preventDefault();
        const text = taskInput.value;
        if (text.trim()) {
          this.addTask(text);
          taskInput.value = '';
          taskInput.style.height = 'auto';
          this.selectedIcon = null;
          this.updateIconSelection();
        }
      }
    });

    // Автоматическое изменение высоты textarea
    taskInput.addEventListener('input', () => {
      taskInput.style.height = 'auto';
      taskInput.style.height = taskInput.scrollHeight + 'px';
    });
  }

  selectIcon(iconType) {
    this.selectedIcon = iconType;
    this.updateIconSelection();
  }

  updateIconSelection() {
    const humanIcon = document.querySelector('.task-icon-human');
    const robotIcon = document.querySelector('.task-icon-robot');

    if (humanIcon) {
      if (this.selectedIcon === 'human') {
        humanIcon.classList.add('selected');
        humanIcon.style.opacity = '1';
      } else {
        humanIcon.classList.remove('selected');
        humanIcon.style.opacity = '0.6';
      }
    }

    if (robotIcon) {
      if (this.selectedIcon === 'robot') {
        robotIcon.classList.add('selected');
        robotIcon.style.opacity = '1';
      } else {
        robotIcon.classList.remove('selected');
        robotIcon.style.opacity = '0.6';
      }
    }
  }
}

// ────────────────────────────────────────────────────────────────────────
// Инициализация приложения
// ────────────────────────────────────────────────────────────────────────

document.addEventListener('DOMContentLoaded', () => {
  new TaskManager();
});
