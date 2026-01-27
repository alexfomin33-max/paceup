<?php
/**
 * ────────────────────────────────────────────────────────────────────────
 * Задачник PaceUp - PHP версия
 * ────────────────────────────────────────────────────────────────────────
 * 
 * Обработка всех операций с задачами и сохранение в JSON файл
 */

// ────────────────────────────────────────────────────────────────────────
// Константы и настройки
// ────────────────────────────────────────────────────────────────────────

define('TASKS_FILE', __DIR__ . '/tasks.json');

// ────────────────────────────────────────────────────────────────────────
// Функции работы с файлом задач
// ────────────────────────────────────────────────────────────────────────

/**
 * Загрузка задач из JSON файла
 */
function loadTasks() {
    if (!file_exists(TASKS_FILE)) {
        return [];
    }
    
    $content = file_get_contents(TASKS_FILE);
    if ($content === false) {
        return [];
    }
    
    $tasks = json_decode($content, true);
    if (json_last_error() !== JSON_ERROR_NONE) {
        return [];
    }
    
    return is_array($tasks) ? $tasks : [];
}

/**
 * Сохранение задач в JSON файл
 */
function saveTasks($tasks) {
    $json = json_encode($tasks, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    if ($json === false) {
        return false;
    }
    
    $result = file_put_contents(TASKS_FILE, $json, LOCK_EX);
    return $result !== false;
}

/**
 * Получение следующего ID для новой задачи
 */
function getNextId($tasks) {
    if (empty($tasks)) {
        return 1;
    }
    
    $maxId = 0;
    foreach ($tasks as $task) {
        if (isset($task['id']) && $task['id'] > $maxId) {
            $maxId = $task['id'];
        }
    }
    
    return $maxId + 1;
}

// ────────────────────────────────────────────────────────────────────────
// Обработка запросов
// ────────────────────────────────────────────────────────────────────────

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$action = $_GET['action'] ?? '';

// Если это обычный GET запрос без action, показываем HTML страницу
if ($method === 'GET' && $action === '') {
    // Отображение HTML страницы
    header('Content-Type: text/html; charset=utf-8');
    ?>
<!DOCTYPE html>
<html lang="ru">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="robots" content="noindex">
  <meta name="description" content="Задачник - управляй своими задачами эффективно">
  <title>Задачник - PaceUp</title>
  <link rel="stylesheet" href="styles.css">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
</head>
<body>
  <!-- ────────────────────────────────────────────────────────────────────────
       Основной контент
       ──────────────────────────────────────────────────────────────────────── -->
  <main class="main">
    <div class="container">
      <!-- ────────────────────────────────────────────────────────────────────────
           Заголовок
           ──────────────────────────────────────────────────────────────────────── -->
      <h1 class="page-title">Задачи по PaceUp</h1>
      
      <!-- ────────────────────────────────────────────────────────────────────────
           Форма добавления задачи
           ──────────────────────────────────────────────────────────────────────── -->
      <section class="add-task-section">
        <div class="add-task-wrapper">
          <textarea 
            id="taskInput" 
            class="task-input" 
            placeholder="Введите новую задачу..."
            rows="2"
          ></textarea>
          <div class="add-task-controls">
            <div class="task-icons">
              <span class="task-icon task-icon-human" data-icon="human">🧔</span>
              <span class="task-icon task-icon-robot" data-icon="robot">🤖</span>
            </div>
            <button id="addTaskBtn" class="btn-add">
              Добавить
            </button>
          </div>
        </div>
      </section>

      <!-- ────────────────────────────────────────────────────────────────────────
           Раздел текущих задач
           ──────────────────────────────────────────────────────────────────────── -->
      <section class="tasks-section">
        <h2 class="section-title">
          <span class="section-title-text">Текущие задачи</span>
          <span id="activeTasksCount" class="tasks-count">0</span>
        </h2>
        <div id="activeTasksList" class="tasks-list">
          <!-- Задачи будут добавлены через JavaScript -->
        </div>
      </section>

      <!-- ────────────────────────────────────────────────────────────────────────
           Раздел выполненных задач
           ──────────────────────────────────────────────────────────────────────── -->
      <section class="tasks-section completed-section">
        <h2 class="section-title">
          <span class="section-title-text">Выполненные задачи</span>
          <span id="completedTasksCount" class="tasks-count">0</span>
        </h2>
        <div id="completedTasksList" class="tasks-list">
          <!-- Задачи будут добавлены через JavaScript -->
        </div>
      </section>
    </div>
  </main>

  <script src="script.php.js"></script>
</body>
</html>
    <?php
    exit;
}

// Установка заголовков для API запросов
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE');
header('Access-Control-Allow-Headers: Content-Type');

// Обработка API запросов
$tasks = loadTasks();
$response = ['success' => false, 'message' => ''];

// Получение данных из POST/PUT запросов
$input = file_get_contents('php://input');
$data = json_decode($input, true);

try {
    switch ($action) {
        case 'get':
            // Получение всех задач
            $response = [
                'success' => true,
                'tasks' => $tasks
            ];
            break;
            
        case 'add':
            // Добавление новой задачи
            $text = trim($data['text'] ?? '');
            $iconType = $data['iconType'] ?? null;
            
            if (empty($text)) {
                throw new Exception('Текст задачи не может быть пустым');
            }
            
            // Валидация iconType
            if ($iconType !== null && $iconType !== 'human' && $iconType !== 'robot') {
                $iconType = null;
            }
            
            $newTask = [
                'id' => getNextId($tasks),
                'text' => $text,
                'completed' => false,
                'createdAt' => time() * 1000, // миллисекунды для совместимости с JS
                'iconType' => $iconType
            ];
            
            $tasks[] = $newTask;
            
            if (!saveTasks($tasks)) {
                throw new Exception('Ошибка сохранения задач');
            }
            
            $response = [
                'success' => true,
                'task' => $newTask,
                'message' => 'Задача добавлена'
            ];
            break;
            
        case 'edit':
            // Редактирование задачи
            $id = intval($data['id'] ?? 0);
            $text = trim($data['text'] ?? '');
            $iconType = $data['iconType'] ?? null;
            
            if ($id === 0) {
                throw new Exception('Неверный ID задачи');
            }
            
            if (empty($text)) {
                throw new Exception('Текст задачи не может быть пустым');
            }
            
            // Валидация iconType
            if ($iconType !== null && $iconType !== 'human' && $iconType !== 'robot') {
                $iconType = null;
            }
            
            $found = false;
            foreach ($tasks as &$task) {
                if (isset($task['id']) && $task['id'] === $id) {
                    $task['text'] = $text;
                    if ($iconType !== null) {
                        $task['iconType'] = $iconType;
                    }
                    $found = true;
                    break;
                }
            }
            
            if (!$found) {
                throw new Exception('Задача не найдена');
            }
            
            if (!saveTasks($tasks)) {
                throw new Exception('Ошибка сохранения задач');
            }
            
            $response = [
                'success' => true,
                'message' => 'Задача обновлена'
            ];
            break;
            
        case 'complete':
            // Отметка задачи как выполненной
            $id = intval($data['id'] ?? 0);
            
            if ($id === 0) {
                throw new Exception('Неверный ID задачи');
            }
            
            $found = false;
            foreach ($tasks as &$task) {
                if (isset($task['id']) && $task['id'] === $id) {
                    $task['completed'] = true;
                    $found = true;
                    break;
                }
            }
            
            if (!$found) {
                throw new Exception('Задача не найдена');
            }
            
            if (!saveTasks($tasks)) {
                throw new Exception('Ошибка сохранения задач');
            }
            
            $response = [
                'success' => true,
                'message' => 'Задача выполнена'
            ];
            break;
            
        case 'restore':
            // Восстановление задачи из выполненных
            $id = intval($data['id'] ?? 0);
            
            if ($id === 0) {
                throw new Exception('Неверный ID задачи');
            }
            
            $found = false;
            foreach ($tasks as &$task) {
                if (isset($task['id']) && $task['id'] === $id) {
                    $task['completed'] = false;
                    $found = true;
                    break;
                }
            }
            
            if (!$found) {
                throw new Exception('Задача не найдена');
            }
            
            if (!saveTasks($tasks)) {
                throw new Exception('Ошибка сохранения задач');
            }
            
            $response = [
                'success' => true,
                'message' => 'Задача восстановлена'
            ];
            break;
            
        case 'delete':
            // Удаление задачи
            $id = intval($data['id'] ?? 0);
            
            if ($id === 0) {
                throw new Exception('Неверный ID задачи');
            }
            
            $newTasks = [];
            $found = false;
            foreach ($tasks as $task) {
                if (isset($task['id']) && $task['id'] === $id) {
                    $found = true;
                    continue;
                }
                $newTasks[] = $task;
            }
            
            if (!$found) {
                throw new Exception('Задача не найдена');
            }
            
            $tasks = $newTasks;
            
            if (!saveTasks($tasks)) {
                throw new Exception('Ошибка сохранения задач');
            }
            
            $response = [
                'success' => true,
                'message' => 'Задача удалена'
            ];
            break;
            
        default:
            throw new Exception('Неизвестное действие');
    }
} catch (Exception $e) {
    $response = [
        'success' => false,
        'message' => $e->getMessage()
    ];
}

echo json_encode($response, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);