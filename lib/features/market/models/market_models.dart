// lib/models/market_models.dart

/// Пол пользователя / товара — просто два варианта.
enum Gender { female, male }

/// Режим сортировки списка слотов.
enum SortMode { relevance, priceAsc, priceDesc }

/// Модель «Слот» — место на забег / старт и т.п.
class MarketItem {
  final int id; // ID слота из базы данных
  final String title; // Заголовок: например, «Марафон "Алые Паруса"»
  final String distance; // Дистанция: «21,1 км», «10 км» и т.п.
  final int price; // Цена в рублях
  final Gender gender; // Для кого слот (М/Ж)
  final bool buttonEnabled; // Доступна ли кнопка (можно ли купить)
  final String buttonText; // Текст на кнопке: «Купить» или «Бронь»
  final bool locked; // На будущее: заблокировано или нет
  final String imageUrl; // Путь к картинке-миниатюре ассета

  // Доп. поля — можно не заполнять
  final String? dateText; // Дата/время
  final String? placeText; // Город/место
  final String? typeText; // Тип (марафон/полумарафон и т.п.)
  final String? description; // Подробное описание (для раскрывающегося блока)

  const MarketItem({
    required this.id,
    required this.title,
    required this.distance,
    required this.price,
    required this.gender,
    required this.buttonEnabled,
    required this.buttonText,
    required this.locked,
    required this.imageUrl,
    this.dateText,
    this.placeText,
    this.typeText,
    this.description,
  });
}

/// Модель «Товар» — кроссовки, часы и т.п.
class GoodsItem {
  final String title; // Название
  final List<String> images; // Список картинок ассетов
  final int price; // Цена
  final Gender gender; // «Ж» или «М» (для фильтра/чипа)
  final String city; // Город
  final String? description; // Описание (если пусто — раскрывать нечего)

  const GoodsItem({
    required this.title,
    required this.images,
    required this.price,
    required this.gender,
    required this.city,
    this.description,
  });
}

