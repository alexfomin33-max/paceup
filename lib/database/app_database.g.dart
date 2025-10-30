// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CachedActivitiesTable extends CachedActivities
    with TableInfo<$CachedActivitiesTable, CachedActivity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedActivitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _activityIdMeta = const VerificationMeta(
    'activityId',
  );
  @override
  late final GeneratedColumn<int> activityId = GeneratedColumn<int>(
    'activity_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lentaIdMeta = const VerificationMeta(
    'lentaId',
  );
  @override
  late final GeneratedColumn<int> lentaId = GeneratedColumn<int>(
    'lenta_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<int> userId = GeneratedColumn<int>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateStartMeta = const VerificationMeta(
    'dateStart',
  );
  @override
  late final GeneratedColumn<DateTime> dateStart = GeneratedColumn<DateTime>(
    'date_start',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dateEndMeta = const VerificationMeta(
    'dateEnd',
  );
  @override
  late final GeneratedColumn<DateTime> dateEnd = GeneratedColumn<DateTime>(
    'date_end',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userNameMeta = const VerificationMeta(
    'userName',
  );
  @override
  late final GeneratedColumn<String> userName = GeneratedColumn<String>(
    'user_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userAvatarMeta = const VerificationMeta(
    'userAvatar',
  );
  @override
  late final GeneratedColumn<String> userAvatar = GeneratedColumn<String>(
    'user_avatar',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userGroupMeta = const VerificationMeta(
    'userGroup',
  );
  @override
  late final GeneratedColumn<int> userGroup = GeneratedColumn<int>(
    'user_group',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _likesMeta = const VerificationMeta('likes');
  @override
  late final GeneratedColumn<int> likes = GeneratedColumn<int>(
    'likes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _commentsMeta = const VerificationMeta(
    'comments',
  );
  @override
  late final GeneratedColumn<int> comments = GeneratedColumn<int>(
    'comments',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isLikeMeta = const VerificationMeta('isLike');
  @override
  late final GeneratedColumn<bool> isLike = GeneratedColumn<bool>(
    'is_like',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_like" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _postDateTextMeta = const VerificationMeta(
    'postDateText',
  );
  @override
  late final GeneratedColumn<String> postDateText = GeneratedColumn<String>(
    'post_date_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _postMediaUrlMeta = const VerificationMeta(
    'postMediaUrl',
  );
  @override
  late final GeneratedColumn<String> postMediaUrl = GeneratedColumn<String>(
    'post_media_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _postContentMeta = const VerificationMeta(
    'postContent',
  );
  @override
  late final GeneratedColumn<String> postContent = GeneratedColumn<String>(
    'post_content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<Equipment>, String>
  equipments = GeneratedColumn<String>(
    'equipments',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  ).withConverter<List<Equipment>>($CachedActivitiesTable.$converterequipments);
  @override
  late final GeneratedColumnWithTypeConverter<ActivityStats?, String> stats =
      GeneratedColumn<String>(
        'stats',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant(''),
      ).withConverter<ActivityStats?>($CachedActivitiesTable.$converterstats);
  @override
  late final GeneratedColumnWithTypeConverter<List<Coord>, String> points =
      GeneratedColumn<String>(
        'points',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<Coord>>($CachedActivitiesTable.$converterpoints);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String>
  mediaImages = GeneratedColumn<String>(
    'media_images',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  ).withConverter<List<String>>($CachedActivitiesTable.$convertermediaImages);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String>
  mediaVideos = GeneratedColumn<String>(
    'media_videos',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  ).withConverter<List<String>>($CachedActivitiesTable.$convertermediaVideos);
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _cacheOwnerMeta = const VerificationMeta(
    'cacheOwner',
  );
  @override
  late final GeneratedColumn<int> cacheOwner = GeneratedColumn<int>(
    'cache_owner',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    activityId,
    lentaId,
    userId,
    type,
    dateStart,
    dateEnd,
    userName,
    userAvatar,
    userGroup,
    likes,
    comments,
    isLike,
    postDateText,
    postMediaUrl,
    postContent,
    equipments,
    stats,
    points,
    mediaImages,
    mediaVideos,
    cachedAt,
    cacheOwner,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_activities';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedActivity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('activity_id')) {
      context.handle(
        _activityIdMeta,
        activityId.isAcceptableOrUnknown(data['activity_id']!, _activityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_activityIdMeta);
    }
    if (data.containsKey('lenta_id')) {
      context.handle(
        _lentaIdMeta,
        lentaId.isAcceptableOrUnknown(data['lenta_id']!, _lentaIdMeta),
      );
    } else if (isInserting) {
      context.missing(_lentaIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('date_start')) {
      context.handle(
        _dateStartMeta,
        dateStart.isAcceptableOrUnknown(data['date_start']!, _dateStartMeta),
      );
    }
    if (data.containsKey('date_end')) {
      context.handle(
        _dateEndMeta,
        dateEnd.isAcceptableOrUnknown(data['date_end']!, _dateEndMeta),
      );
    }
    if (data.containsKey('user_name')) {
      context.handle(
        _userNameMeta,
        userName.isAcceptableOrUnknown(data['user_name']!, _userNameMeta),
      );
    } else if (isInserting) {
      context.missing(_userNameMeta);
    }
    if (data.containsKey('user_avatar')) {
      context.handle(
        _userAvatarMeta,
        userAvatar.isAcceptableOrUnknown(data['user_avatar']!, _userAvatarMeta),
      );
    } else if (isInserting) {
      context.missing(_userAvatarMeta);
    }
    if (data.containsKey('user_group')) {
      context.handle(
        _userGroupMeta,
        userGroup.isAcceptableOrUnknown(data['user_group']!, _userGroupMeta),
      );
    } else if (isInserting) {
      context.missing(_userGroupMeta);
    }
    if (data.containsKey('likes')) {
      context.handle(
        _likesMeta,
        likes.isAcceptableOrUnknown(data['likes']!, _likesMeta),
      );
    }
    if (data.containsKey('comments')) {
      context.handle(
        _commentsMeta,
        comments.isAcceptableOrUnknown(data['comments']!, _commentsMeta),
      );
    }
    if (data.containsKey('is_like')) {
      context.handle(
        _isLikeMeta,
        isLike.isAcceptableOrUnknown(data['is_like']!, _isLikeMeta),
      );
    }
    if (data.containsKey('post_date_text')) {
      context.handle(
        _postDateTextMeta,
        postDateText.isAcceptableOrUnknown(
          data['post_date_text']!,
          _postDateTextMeta,
        ),
      );
    }
    if (data.containsKey('post_media_url')) {
      context.handle(
        _postMediaUrlMeta,
        postMediaUrl.isAcceptableOrUnknown(
          data['post_media_url']!,
          _postMediaUrlMeta,
        ),
      );
    }
    if (data.containsKey('post_content')) {
      context.handle(
        _postContentMeta,
        postContent.isAcceptableOrUnknown(
          data['post_content']!,
          _postContentMeta,
        ),
      );
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    }
    if (data.containsKey('cache_owner')) {
      context.handle(
        _cacheOwnerMeta,
        cacheOwner.isAcceptableOrUnknown(data['cache_owner']!, _cacheOwnerMeta),
      );
    } else if (isInserting) {
      context.missing(_cacheOwnerMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedActivity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedActivity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      activityId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}activity_id'],
      )!,
      lentaId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lenta_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}user_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      dateStart: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date_start'],
      ),
      dateEnd: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date_end'],
      ),
      userName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_name'],
      )!,
      userAvatar: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_avatar'],
      )!,
      userGroup: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}user_group'],
      )!,
      likes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}likes'],
      )!,
      comments: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}comments'],
      )!,
      isLike: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_like'],
      )!,
      postDateText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}post_date_text'],
      )!,
      postMediaUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}post_media_url'],
      )!,
      postContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}post_content'],
      )!,
      equipments: $CachedActivitiesTable.$converterequipments.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}equipments'],
        )!,
      ),
      stats: $CachedActivitiesTable.$converterstats.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}stats'],
        )!,
      ),
      points: $CachedActivitiesTable.$converterpoints.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}points'],
        )!,
      ),
      mediaImages: $CachedActivitiesTable.$convertermediaImages.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}media_images'],
        )!,
      ),
      mediaVideos: $CachedActivitiesTable.$convertermediaVideos.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}media_videos'],
        )!,
      ),
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
      cacheOwner: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cache_owner'],
      )!,
    );
  }

  @override
  $CachedActivitiesTable createAlias(String alias) {
    return $CachedActivitiesTable(attachedDatabase, alias);
  }

  static TypeConverter<List<Equipment>, String> $converterequipments =
      const EquipmentListConverter();
  static TypeConverter<ActivityStats?, String> $converterstats =
      const ActivityStatsConverter();
  static TypeConverter<List<Coord>, String> $converterpoints =
      const CoordListConverter();
  static TypeConverter<List<String>, String> $convertermediaImages =
      const StringListConverter();
  static TypeConverter<List<String>, String> $convertermediaVideos =
      const StringListConverter();
}

class CachedActivity extends DataClass implements Insertable<CachedActivity> {
  final int id;
  final int activityId;
  final int lentaId;
  final int userId;
  final String type;
  final DateTime? dateStart;
  final DateTime? dateEnd;
  final String userName;
  final String userAvatar;
  final int userGroup;
  final int likes;
  final int comments;
  final bool isLike;
  final String postDateText;
  final String postMediaUrl;
  final String postContent;
  final List<Equipment> equipments;
  final ActivityStats? stats;
  final List<Coord> points;
  final List<String> mediaImages;
  final List<String> mediaVideos;
  final DateTime cachedAt;
  final int cacheOwner;
  const CachedActivity({
    required this.id,
    required this.activityId,
    required this.lentaId,
    required this.userId,
    required this.type,
    this.dateStart,
    this.dateEnd,
    required this.userName,
    required this.userAvatar,
    required this.userGroup,
    required this.likes,
    required this.comments,
    required this.isLike,
    required this.postDateText,
    required this.postMediaUrl,
    required this.postContent,
    required this.equipments,
    this.stats,
    required this.points,
    required this.mediaImages,
    required this.mediaVideos,
    required this.cachedAt,
    required this.cacheOwner,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['activity_id'] = Variable<int>(activityId);
    map['lenta_id'] = Variable<int>(lentaId);
    map['user_id'] = Variable<int>(userId);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || dateStart != null) {
      map['date_start'] = Variable<DateTime>(dateStart);
    }
    if (!nullToAbsent || dateEnd != null) {
      map['date_end'] = Variable<DateTime>(dateEnd);
    }
    map['user_name'] = Variable<String>(userName);
    map['user_avatar'] = Variable<String>(userAvatar);
    map['user_group'] = Variable<int>(userGroup);
    map['likes'] = Variable<int>(likes);
    map['comments'] = Variable<int>(comments);
    map['is_like'] = Variable<bool>(isLike);
    map['post_date_text'] = Variable<String>(postDateText);
    map['post_media_url'] = Variable<String>(postMediaUrl);
    map['post_content'] = Variable<String>(postContent);
    {
      map['equipments'] = Variable<String>(
        $CachedActivitiesTable.$converterequipments.toSql(equipments),
      );
    }
    if (!nullToAbsent || stats != null) {
      map['stats'] = Variable<String>(
        $CachedActivitiesTable.$converterstats.toSql(stats),
      );
    }
    {
      map['points'] = Variable<String>(
        $CachedActivitiesTable.$converterpoints.toSql(points),
      );
    }
    {
      map['media_images'] = Variable<String>(
        $CachedActivitiesTable.$convertermediaImages.toSql(mediaImages),
      );
    }
    {
      map['media_videos'] = Variable<String>(
        $CachedActivitiesTable.$convertermediaVideos.toSql(mediaVideos),
      );
    }
    map['cached_at'] = Variable<DateTime>(cachedAt);
    map['cache_owner'] = Variable<int>(cacheOwner);
    return map;
  }

  CachedActivitiesCompanion toCompanion(bool nullToAbsent) {
    return CachedActivitiesCompanion(
      id: Value(id),
      activityId: Value(activityId),
      lentaId: Value(lentaId),
      userId: Value(userId),
      type: Value(type),
      dateStart: dateStart == null && nullToAbsent
          ? const Value.absent()
          : Value(dateStart),
      dateEnd: dateEnd == null && nullToAbsent
          ? const Value.absent()
          : Value(dateEnd),
      userName: Value(userName),
      userAvatar: Value(userAvatar),
      userGroup: Value(userGroup),
      likes: Value(likes),
      comments: Value(comments),
      isLike: Value(isLike),
      postDateText: Value(postDateText),
      postMediaUrl: Value(postMediaUrl),
      postContent: Value(postContent),
      equipments: Value(equipments),
      stats: stats == null && nullToAbsent
          ? const Value.absent()
          : Value(stats),
      points: Value(points),
      mediaImages: Value(mediaImages),
      mediaVideos: Value(mediaVideos),
      cachedAt: Value(cachedAt),
      cacheOwner: Value(cacheOwner),
    );
  }

  factory CachedActivity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedActivity(
      id: serializer.fromJson<int>(json['id']),
      activityId: serializer.fromJson<int>(json['activityId']),
      lentaId: serializer.fromJson<int>(json['lentaId']),
      userId: serializer.fromJson<int>(json['userId']),
      type: serializer.fromJson<String>(json['type']),
      dateStart: serializer.fromJson<DateTime?>(json['dateStart']),
      dateEnd: serializer.fromJson<DateTime?>(json['dateEnd']),
      userName: serializer.fromJson<String>(json['userName']),
      userAvatar: serializer.fromJson<String>(json['userAvatar']),
      userGroup: serializer.fromJson<int>(json['userGroup']),
      likes: serializer.fromJson<int>(json['likes']),
      comments: serializer.fromJson<int>(json['comments']),
      isLike: serializer.fromJson<bool>(json['isLike']),
      postDateText: serializer.fromJson<String>(json['postDateText']),
      postMediaUrl: serializer.fromJson<String>(json['postMediaUrl']),
      postContent: serializer.fromJson<String>(json['postContent']),
      equipments: serializer.fromJson<List<Equipment>>(json['equipments']),
      stats: serializer.fromJson<ActivityStats?>(json['stats']),
      points: serializer.fromJson<List<Coord>>(json['points']),
      mediaImages: serializer.fromJson<List<String>>(json['mediaImages']),
      mediaVideos: serializer.fromJson<List<String>>(json['mediaVideos']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
      cacheOwner: serializer.fromJson<int>(json['cacheOwner']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'activityId': serializer.toJson<int>(activityId),
      'lentaId': serializer.toJson<int>(lentaId),
      'userId': serializer.toJson<int>(userId),
      'type': serializer.toJson<String>(type),
      'dateStart': serializer.toJson<DateTime?>(dateStart),
      'dateEnd': serializer.toJson<DateTime?>(dateEnd),
      'userName': serializer.toJson<String>(userName),
      'userAvatar': serializer.toJson<String>(userAvatar),
      'userGroup': serializer.toJson<int>(userGroup),
      'likes': serializer.toJson<int>(likes),
      'comments': serializer.toJson<int>(comments),
      'isLike': serializer.toJson<bool>(isLike),
      'postDateText': serializer.toJson<String>(postDateText),
      'postMediaUrl': serializer.toJson<String>(postMediaUrl),
      'postContent': serializer.toJson<String>(postContent),
      'equipments': serializer.toJson<List<Equipment>>(equipments),
      'stats': serializer.toJson<ActivityStats?>(stats),
      'points': serializer.toJson<List<Coord>>(points),
      'mediaImages': serializer.toJson<List<String>>(mediaImages),
      'mediaVideos': serializer.toJson<List<String>>(mediaVideos),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
      'cacheOwner': serializer.toJson<int>(cacheOwner),
    };
  }

  CachedActivity copyWith({
    int? id,
    int? activityId,
    int? lentaId,
    int? userId,
    String? type,
    Value<DateTime?> dateStart = const Value.absent(),
    Value<DateTime?> dateEnd = const Value.absent(),
    String? userName,
    String? userAvatar,
    int? userGroup,
    int? likes,
    int? comments,
    bool? isLike,
    String? postDateText,
    String? postMediaUrl,
    String? postContent,
    List<Equipment>? equipments,
    Value<ActivityStats?> stats = const Value.absent(),
    List<Coord>? points,
    List<String>? mediaImages,
    List<String>? mediaVideos,
    DateTime? cachedAt,
    int? cacheOwner,
  }) => CachedActivity(
    id: id ?? this.id,
    activityId: activityId ?? this.activityId,
    lentaId: lentaId ?? this.lentaId,
    userId: userId ?? this.userId,
    type: type ?? this.type,
    dateStart: dateStart.present ? dateStart.value : this.dateStart,
    dateEnd: dateEnd.present ? dateEnd.value : this.dateEnd,
    userName: userName ?? this.userName,
    userAvatar: userAvatar ?? this.userAvatar,
    userGroup: userGroup ?? this.userGroup,
    likes: likes ?? this.likes,
    comments: comments ?? this.comments,
    isLike: isLike ?? this.isLike,
    postDateText: postDateText ?? this.postDateText,
    postMediaUrl: postMediaUrl ?? this.postMediaUrl,
    postContent: postContent ?? this.postContent,
    equipments: equipments ?? this.equipments,
    stats: stats.present ? stats.value : this.stats,
    points: points ?? this.points,
    mediaImages: mediaImages ?? this.mediaImages,
    mediaVideos: mediaVideos ?? this.mediaVideos,
    cachedAt: cachedAt ?? this.cachedAt,
    cacheOwner: cacheOwner ?? this.cacheOwner,
  );
  CachedActivity copyWithCompanion(CachedActivitiesCompanion data) {
    return CachedActivity(
      id: data.id.present ? data.id.value : this.id,
      activityId: data.activityId.present
          ? data.activityId.value
          : this.activityId,
      lentaId: data.lentaId.present ? data.lentaId.value : this.lentaId,
      userId: data.userId.present ? data.userId.value : this.userId,
      type: data.type.present ? data.type.value : this.type,
      dateStart: data.dateStart.present ? data.dateStart.value : this.dateStart,
      dateEnd: data.dateEnd.present ? data.dateEnd.value : this.dateEnd,
      userName: data.userName.present ? data.userName.value : this.userName,
      userAvatar: data.userAvatar.present
          ? data.userAvatar.value
          : this.userAvatar,
      userGroup: data.userGroup.present ? data.userGroup.value : this.userGroup,
      likes: data.likes.present ? data.likes.value : this.likes,
      comments: data.comments.present ? data.comments.value : this.comments,
      isLike: data.isLike.present ? data.isLike.value : this.isLike,
      postDateText: data.postDateText.present
          ? data.postDateText.value
          : this.postDateText,
      postMediaUrl: data.postMediaUrl.present
          ? data.postMediaUrl.value
          : this.postMediaUrl,
      postContent: data.postContent.present
          ? data.postContent.value
          : this.postContent,
      equipments: data.equipments.present
          ? data.equipments.value
          : this.equipments,
      stats: data.stats.present ? data.stats.value : this.stats,
      points: data.points.present ? data.points.value : this.points,
      mediaImages: data.mediaImages.present
          ? data.mediaImages.value
          : this.mediaImages,
      mediaVideos: data.mediaVideos.present
          ? data.mediaVideos.value
          : this.mediaVideos,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
      cacheOwner: data.cacheOwner.present
          ? data.cacheOwner.value
          : this.cacheOwner,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedActivity(')
          ..write('id: $id, ')
          ..write('activityId: $activityId, ')
          ..write('lentaId: $lentaId, ')
          ..write('userId: $userId, ')
          ..write('type: $type, ')
          ..write('dateStart: $dateStart, ')
          ..write('dateEnd: $dateEnd, ')
          ..write('userName: $userName, ')
          ..write('userAvatar: $userAvatar, ')
          ..write('userGroup: $userGroup, ')
          ..write('likes: $likes, ')
          ..write('comments: $comments, ')
          ..write('isLike: $isLike, ')
          ..write('postDateText: $postDateText, ')
          ..write('postMediaUrl: $postMediaUrl, ')
          ..write('postContent: $postContent, ')
          ..write('equipments: $equipments, ')
          ..write('stats: $stats, ')
          ..write('points: $points, ')
          ..write('mediaImages: $mediaImages, ')
          ..write('mediaVideos: $mediaVideos, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('cacheOwner: $cacheOwner')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    activityId,
    lentaId,
    userId,
    type,
    dateStart,
    dateEnd,
    userName,
    userAvatar,
    userGroup,
    likes,
    comments,
    isLike,
    postDateText,
    postMediaUrl,
    postContent,
    equipments,
    stats,
    points,
    mediaImages,
    mediaVideos,
    cachedAt,
    cacheOwner,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedActivity &&
          other.id == this.id &&
          other.activityId == this.activityId &&
          other.lentaId == this.lentaId &&
          other.userId == this.userId &&
          other.type == this.type &&
          other.dateStart == this.dateStart &&
          other.dateEnd == this.dateEnd &&
          other.userName == this.userName &&
          other.userAvatar == this.userAvatar &&
          other.userGroup == this.userGroup &&
          other.likes == this.likes &&
          other.comments == this.comments &&
          other.isLike == this.isLike &&
          other.postDateText == this.postDateText &&
          other.postMediaUrl == this.postMediaUrl &&
          other.postContent == this.postContent &&
          other.equipments == this.equipments &&
          other.stats == this.stats &&
          other.points == this.points &&
          other.mediaImages == this.mediaImages &&
          other.mediaVideos == this.mediaVideos &&
          other.cachedAt == this.cachedAt &&
          other.cacheOwner == this.cacheOwner);
}

class CachedActivitiesCompanion extends UpdateCompanion<CachedActivity> {
  final Value<int> id;
  final Value<int> activityId;
  final Value<int> lentaId;
  final Value<int> userId;
  final Value<String> type;
  final Value<DateTime?> dateStart;
  final Value<DateTime?> dateEnd;
  final Value<String> userName;
  final Value<String> userAvatar;
  final Value<int> userGroup;
  final Value<int> likes;
  final Value<int> comments;
  final Value<bool> isLike;
  final Value<String> postDateText;
  final Value<String> postMediaUrl;
  final Value<String> postContent;
  final Value<List<Equipment>> equipments;
  final Value<ActivityStats?> stats;
  final Value<List<Coord>> points;
  final Value<List<String>> mediaImages;
  final Value<List<String>> mediaVideos;
  final Value<DateTime> cachedAt;
  final Value<int> cacheOwner;
  const CachedActivitiesCompanion({
    this.id = const Value.absent(),
    this.activityId = const Value.absent(),
    this.lentaId = const Value.absent(),
    this.userId = const Value.absent(),
    this.type = const Value.absent(),
    this.dateStart = const Value.absent(),
    this.dateEnd = const Value.absent(),
    this.userName = const Value.absent(),
    this.userAvatar = const Value.absent(),
    this.userGroup = const Value.absent(),
    this.likes = const Value.absent(),
    this.comments = const Value.absent(),
    this.isLike = const Value.absent(),
    this.postDateText = const Value.absent(),
    this.postMediaUrl = const Value.absent(),
    this.postContent = const Value.absent(),
    this.equipments = const Value.absent(),
    this.stats = const Value.absent(),
    this.points = const Value.absent(),
    this.mediaImages = const Value.absent(),
    this.mediaVideos = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.cacheOwner = const Value.absent(),
  });
  CachedActivitiesCompanion.insert({
    this.id = const Value.absent(),
    required int activityId,
    required int lentaId,
    required int userId,
    required String type,
    this.dateStart = const Value.absent(),
    this.dateEnd = const Value.absent(),
    required String userName,
    required String userAvatar,
    required int userGroup,
    this.likes = const Value.absent(),
    this.comments = const Value.absent(),
    this.isLike = const Value.absent(),
    this.postDateText = const Value.absent(),
    this.postMediaUrl = const Value.absent(),
    this.postContent = const Value.absent(),
    this.equipments = const Value.absent(),
    this.stats = const Value.absent(),
    this.points = const Value.absent(),
    this.mediaImages = const Value.absent(),
    this.mediaVideos = const Value.absent(),
    this.cachedAt = const Value.absent(),
    required int cacheOwner,
  }) : activityId = Value(activityId),
       lentaId = Value(lentaId),
       userId = Value(userId),
       type = Value(type),
       userName = Value(userName),
       userAvatar = Value(userAvatar),
       userGroup = Value(userGroup),
       cacheOwner = Value(cacheOwner);
  static Insertable<CachedActivity> custom({
    Expression<int>? id,
    Expression<int>? activityId,
    Expression<int>? lentaId,
    Expression<int>? userId,
    Expression<String>? type,
    Expression<DateTime>? dateStart,
    Expression<DateTime>? dateEnd,
    Expression<String>? userName,
    Expression<String>? userAvatar,
    Expression<int>? userGroup,
    Expression<int>? likes,
    Expression<int>? comments,
    Expression<bool>? isLike,
    Expression<String>? postDateText,
    Expression<String>? postMediaUrl,
    Expression<String>? postContent,
    Expression<String>? equipments,
    Expression<String>? stats,
    Expression<String>? points,
    Expression<String>? mediaImages,
    Expression<String>? mediaVideos,
    Expression<DateTime>? cachedAt,
    Expression<int>? cacheOwner,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (activityId != null) 'activity_id': activityId,
      if (lentaId != null) 'lenta_id': lentaId,
      if (userId != null) 'user_id': userId,
      if (type != null) 'type': type,
      if (dateStart != null) 'date_start': dateStart,
      if (dateEnd != null) 'date_end': dateEnd,
      if (userName != null) 'user_name': userName,
      if (userAvatar != null) 'user_avatar': userAvatar,
      if (userGroup != null) 'user_group': userGroup,
      if (likes != null) 'likes': likes,
      if (comments != null) 'comments': comments,
      if (isLike != null) 'is_like': isLike,
      if (postDateText != null) 'post_date_text': postDateText,
      if (postMediaUrl != null) 'post_media_url': postMediaUrl,
      if (postContent != null) 'post_content': postContent,
      if (equipments != null) 'equipments': equipments,
      if (stats != null) 'stats': stats,
      if (points != null) 'points': points,
      if (mediaImages != null) 'media_images': mediaImages,
      if (mediaVideos != null) 'media_videos': mediaVideos,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (cacheOwner != null) 'cache_owner': cacheOwner,
    });
  }

  CachedActivitiesCompanion copyWith({
    Value<int>? id,
    Value<int>? activityId,
    Value<int>? lentaId,
    Value<int>? userId,
    Value<String>? type,
    Value<DateTime?>? dateStart,
    Value<DateTime?>? dateEnd,
    Value<String>? userName,
    Value<String>? userAvatar,
    Value<int>? userGroup,
    Value<int>? likes,
    Value<int>? comments,
    Value<bool>? isLike,
    Value<String>? postDateText,
    Value<String>? postMediaUrl,
    Value<String>? postContent,
    Value<List<Equipment>>? equipments,
    Value<ActivityStats?>? stats,
    Value<List<Coord>>? points,
    Value<List<String>>? mediaImages,
    Value<List<String>>? mediaVideos,
    Value<DateTime>? cachedAt,
    Value<int>? cacheOwner,
  }) {
    return CachedActivitiesCompanion(
      id: id ?? this.id,
      activityId: activityId ?? this.activityId,
      lentaId: lentaId ?? this.lentaId,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      dateStart: dateStart ?? this.dateStart,
      dateEnd: dateEnd ?? this.dateEnd,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      userGroup: userGroup ?? this.userGroup,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      isLike: isLike ?? this.isLike,
      postDateText: postDateText ?? this.postDateText,
      postMediaUrl: postMediaUrl ?? this.postMediaUrl,
      postContent: postContent ?? this.postContent,
      equipments: equipments ?? this.equipments,
      stats: stats ?? this.stats,
      points: points ?? this.points,
      mediaImages: mediaImages ?? this.mediaImages,
      mediaVideos: mediaVideos ?? this.mediaVideos,
      cachedAt: cachedAt ?? this.cachedAt,
      cacheOwner: cacheOwner ?? this.cacheOwner,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (activityId.present) {
      map['activity_id'] = Variable<int>(activityId.value);
    }
    if (lentaId.present) {
      map['lenta_id'] = Variable<int>(lentaId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<int>(userId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (dateStart.present) {
      map['date_start'] = Variable<DateTime>(dateStart.value);
    }
    if (dateEnd.present) {
      map['date_end'] = Variable<DateTime>(dateEnd.value);
    }
    if (userName.present) {
      map['user_name'] = Variable<String>(userName.value);
    }
    if (userAvatar.present) {
      map['user_avatar'] = Variable<String>(userAvatar.value);
    }
    if (userGroup.present) {
      map['user_group'] = Variable<int>(userGroup.value);
    }
    if (likes.present) {
      map['likes'] = Variable<int>(likes.value);
    }
    if (comments.present) {
      map['comments'] = Variable<int>(comments.value);
    }
    if (isLike.present) {
      map['is_like'] = Variable<bool>(isLike.value);
    }
    if (postDateText.present) {
      map['post_date_text'] = Variable<String>(postDateText.value);
    }
    if (postMediaUrl.present) {
      map['post_media_url'] = Variable<String>(postMediaUrl.value);
    }
    if (postContent.present) {
      map['post_content'] = Variable<String>(postContent.value);
    }
    if (equipments.present) {
      map['equipments'] = Variable<String>(
        $CachedActivitiesTable.$converterequipments.toSql(equipments.value),
      );
    }
    if (stats.present) {
      map['stats'] = Variable<String>(
        $CachedActivitiesTable.$converterstats.toSql(stats.value),
      );
    }
    if (points.present) {
      map['points'] = Variable<String>(
        $CachedActivitiesTable.$converterpoints.toSql(points.value),
      );
    }
    if (mediaImages.present) {
      map['media_images'] = Variable<String>(
        $CachedActivitiesTable.$convertermediaImages.toSql(mediaImages.value),
      );
    }
    if (mediaVideos.present) {
      map['media_videos'] = Variable<String>(
        $CachedActivitiesTable.$convertermediaVideos.toSql(mediaVideos.value),
      );
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (cacheOwner.present) {
      map['cache_owner'] = Variable<int>(cacheOwner.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedActivitiesCompanion(')
          ..write('id: $id, ')
          ..write('activityId: $activityId, ')
          ..write('lentaId: $lentaId, ')
          ..write('userId: $userId, ')
          ..write('type: $type, ')
          ..write('dateStart: $dateStart, ')
          ..write('dateEnd: $dateEnd, ')
          ..write('userName: $userName, ')
          ..write('userAvatar: $userAvatar, ')
          ..write('userGroup: $userGroup, ')
          ..write('likes: $likes, ')
          ..write('comments: $comments, ')
          ..write('isLike: $isLike, ')
          ..write('postDateText: $postDateText, ')
          ..write('postMediaUrl: $postMediaUrl, ')
          ..write('postContent: $postContent, ')
          ..write('equipments: $equipments, ')
          ..write('stats: $stats, ')
          ..write('points: $points, ')
          ..write('mediaImages: $mediaImages, ')
          ..write('mediaVideos: $mediaVideos, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('cacheOwner: $cacheOwner')
          ..write(')'))
        .toString();
  }
}

class $CachedProfilesTable extends CachedProfiles
    with TableInfo<$CachedProfilesTable, CachedProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<int> userId = GeneratedColumn<int>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _avatarMeta = const VerificationMeta('avatar');
  @override
  late final GeneratedColumn<String> avatar = GeneratedColumn<String>(
    'avatar',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _userGroupMeta = const VerificationMeta(
    'userGroup',
  );
  @override
  late final GeneratedColumn<int> userGroup = GeneratedColumn<int>(
    'user_group',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _cityMeta = const VerificationMeta('city');
  @override
  late final GeneratedColumn<String> city = GeneratedColumn<String>(
    'city',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ageMeta = const VerificationMeta('age');
  @override
  late final GeneratedColumn<int> age = GeneratedColumn<int>(
    'age',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _followersMeta = const VerificationMeta(
    'followers',
  );
  @override
  late final GeneratedColumn<int> followers = GeneratedColumn<int>(
    'followers',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _followingMeta = const VerificationMeta(
    'following',
  );
  @override
  late final GeneratedColumn<int> following = GeneratedColumn<int>(
    'following',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalDistanceMeta = const VerificationMeta(
    'totalDistance',
  );
  @override
  late final GeneratedColumn<int> totalDistance = GeneratedColumn<int>(
    'total_distance',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalActivitiesMeta = const VerificationMeta(
    'totalActivities',
  );
  @override
  late final GeneratedColumn<int> totalActivities = GeneratedColumn<int>(
    'total_activities',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalTimeMeta = const VerificationMeta(
    'totalTime',
  );
  @override
  late final GeneratedColumn<int> totalTime = GeneratedColumn<int>(
    'total_time',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    name,
    avatar,
    userGroup,
    city,
    age,
    followers,
    following,
    totalDistance,
    totalActivities,
    totalTime,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedProfile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('avatar')) {
      context.handle(
        _avatarMeta,
        avatar.isAcceptableOrUnknown(data['avatar']!, _avatarMeta),
      );
    }
    if (data.containsKey('user_group')) {
      context.handle(
        _userGroupMeta,
        userGroup.isAcceptableOrUnknown(data['user_group']!, _userGroupMeta),
      );
    }
    if (data.containsKey('city')) {
      context.handle(
        _cityMeta,
        city.isAcceptableOrUnknown(data['city']!, _cityMeta),
      );
    }
    if (data.containsKey('age')) {
      context.handle(
        _ageMeta,
        age.isAcceptableOrUnknown(data['age']!, _ageMeta),
      );
    }
    if (data.containsKey('followers')) {
      context.handle(
        _followersMeta,
        followers.isAcceptableOrUnknown(data['followers']!, _followersMeta),
      );
    }
    if (data.containsKey('following')) {
      context.handle(
        _followingMeta,
        following.isAcceptableOrUnknown(data['following']!, _followingMeta),
      );
    }
    if (data.containsKey('total_distance')) {
      context.handle(
        _totalDistanceMeta,
        totalDistance.isAcceptableOrUnknown(
          data['total_distance']!,
          _totalDistanceMeta,
        ),
      );
    }
    if (data.containsKey('total_activities')) {
      context.handle(
        _totalActivitiesMeta,
        totalActivities.isAcceptableOrUnknown(
          data['total_activities']!,
          _totalActivitiesMeta,
        ),
      );
    }
    if (data.containsKey('total_time')) {
      context.handle(
        _totalTimeMeta,
        totalTime.isAcceptableOrUnknown(data['total_time']!, _totalTimeMeta),
      );
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedProfile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}user_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      avatar: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar'],
      )!,
      userGroup: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}user_group'],
      )!,
      city: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}city'],
      ),
      age: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}age'],
      ),
      followers: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}followers'],
      ),
      following: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}following'],
      ),
      totalDistance: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_distance'],
      )!,
      totalActivities: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_activities'],
      )!,
      totalTime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_time'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $CachedProfilesTable createAlias(String alias) {
    return $CachedProfilesTable(attachedDatabase, alias);
  }
}

class CachedProfile extends DataClass implements Insertable<CachedProfile> {
  final int id;
  final int userId;
  final String name;
  final String avatar;
  final int userGroup;
  final String? city;
  final int? age;
  final int? followers;
  final int? following;
  final int totalDistance;
  final int totalActivities;
  final int totalTime;
  final DateTime cachedAt;
  const CachedProfile({
    required this.id,
    required this.userId,
    required this.name,
    required this.avatar,
    required this.userGroup,
    this.city,
    this.age,
    this.followers,
    this.following,
    required this.totalDistance,
    required this.totalActivities,
    required this.totalTime,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['user_id'] = Variable<int>(userId);
    map['name'] = Variable<String>(name);
    map['avatar'] = Variable<String>(avatar);
    map['user_group'] = Variable<int>(userGroup);
    if (!nullToAbsent || city != null) {
      map['city'] = Variable<String>(city);
    }
    if (!nullToAbsent || age != null) {
      map['age'] = Variable<int>(age);
    }
    if (!nullToAbsent || followers != null) {
      map['followers'] = Variable<int>(followers);
    }
    if (!nullToAbsent || following != null) {
      map['following'] = Variable<int>(following);
    }
    map['total_distance'] = Variable<int>(totalDistance);
    map['total_activities'] = Variable<int>(totalActivities);
    map['total_time'] = Variable<int>(totalTime);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CachedProfilesCompanion toCompanion(bool nullToAbsent) {
    return CachedProfilesCompanion(
      id: Value(id),
      userId: Value(userId),
      name: Value(name),
      avatar: Value(avatar),
      userGroup: Value(userGroup),
      city: city == null && nullToAbsent ? const Value.absent() : Value(city),
      age: age == null && nullToAbsent ? const Value.absent() : Value(age),
      followers: followers == null && nullToAbsent
          ? const Value.absent()
          : Value(followers),
      following: following == null && nullToAbsent
          ? const Value.absent()
          : Value(following),
      totalDistance: Value(totalDistance),
      totalActivities: Value(totalActivities),
      totalTime: Value(totalTime),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedProfile(
      id: serializer.fromJson<int>(json['id']),
      userId: serializer.fromJson<int>(json['userId']),
      name: serializer.fromJson<String>(json['name']),
      avatar: serializer.fromJson<String>(json['avatar']),
      userGroup: serializer.fromJson<int>(json['userGroup']),
      city: serializer.fromJson<String?>(json['city']),
      age: serializer.fromJson<int?>(json['age']),
      followers: serializer.fromJson<int?>(json['followers']),
      following: serializer.fromJson<int?>(json['following']),
      totalDistance: serializer.fromJson<int>(json['totalDistance']),
      totalActivities: serializer.fromJson<int>(json['totalActivities']),
      totalTime: serializer.fromJson<int>(json['totalTime']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'userId': serializer.toJson<int>(userId),
      'name': serializer.toJson<String>(name),
      'avatar': serializer.toJson<String>(avatar),
      'userGroup': serializer.toJson<int>(userGroup),
      'city': serializer.toJson<String?>(city),
      'age': serializer.toJson<int?>(age),
      'followers': serializer.toJson<int?>(followers),
      'following': serializer.toJson<int?>(following),
      'totalDistance': serializer.toJson<int>(totalDistance),
      'totalActivities': serializer.toJson<int>(totalActivities),
      'totalTime': serializer.toJson<int>(totalTime),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CachedProfile copyWith({
    int? id,
    int? userId,
    String? name,
    String? avatar,
    int? userGroup,
    Value<String?> city = const Value.absent(),
    Value<int?> age = const Value.absent(),
    Value<int?> followers = const Value.absent(),
    Value<int?> following = const Value.absent(),
    int? totalDistance,
    int? totalActivities,
    int? totalTime,
    DateTime? cachedAt,
  }) => CachedProfile(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    name: name ?? this.name,
    avatar: avatar ?? this.avatar,
    userGroup: userGroup ?? this.userGroup,
    city: city.present ? city.value : this.city,
    age: age.present ? age.value : this.age,
    followers: followers.present ? followers.value : this.followers,
    following: following.present ? following.value : this.following,
    totalDistance: totalDistance ?? this.totalDistance,
    totalActivities: totalActivities ?? this.totalActivities,
    totalTime: totalTime ?? this.totalTime,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  CachedProfile copyWithCompanion(CachedProfilesCompanion data) {
    return CachedProfile(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      name: data.name.present ? data.name.value : this.name,
      avatar: data.avatar.present ? data.avatar.value : this.avatar,
      userGroup: data.userGroup.present ? data.userGroup.value : this.userGroup,
      city: data.city.present ? data.city.value : this.city,
      age: data.age.present ? data.age.value : this.age,
      followers: data.followers.present ? data.followers.value : this.followers,
      following: data.following.present ? data.following.value : this.following,
      totalDistance: data.totalDistance.present
          ? data.totalDistance.value
          : this.totalDistance,
      totalActivities: data.totalActivities.present
          ? data.totalActivities.value
          : this.totalActivities,
      totalTime: data.totalTime.present ? data.totalTime.value : this.totalTime,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedProfile(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('name: $name, ')
          ..write('avatar: $avatar, ')
          ..write('userGroup: $userGroup, ')
          ..write('city: $city, ')
          ..write('age: $age, ')
          ..write('followers: $followers, ')
          ..write('following: $following, ')
          ..write('totalDistance: $totalDistance, ')
          ..write('totalActivities: $totalActivities, ')
          ..write('totalTime: $totalTime, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    name,
    avatar,
    userGroup,
    city,
    age,
    followers,
    following,
    totalDistance,
    totalActivities,
    totalTime,
    cachedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedProfile &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.name == this.name &&
          other.avatar == this.avatar &&
          other.userGroup == this.userGroup &&
          other.city == this.city &&
          other.age == this.age &&
          other.followers == this.followers &&
          other.following == this.following &&
          other.totalDistance == this.totalDistance &&
          other.totalActivities == this.totalActivities &&
          other.totalTime == this.totalTime &&
          other.cachedAt == this.cachedAt);
}

class CachedProfilesCompanion extends UpdateCompanion<CachedProfile> {
  final Value<int> id;
  final Value<int> userId;
  final Value<String> name;
  final Value<String> avatar;
  final Value<int> userGroup;
  final Value<String?> city;
  final Value<int?> age;
  final Value<int?> followers;
  final Value<int?> following;
  final Value<int> totalDistance;
  final Value<int> totalActivities;
  final Value<int> totalTime;
  final Value<DateTime> cachedAt;
  const CachedProfilesCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.name = const Value.absent(),
    this.avatar = const Value.absent(),
    this.userGroup = const Value.absent(),
    this.city = const Value.absent(),
    this.age = const Value.absent(),
    this.followers = const Value.absent(),
    this.following = const Value.absent(),
    this.totalDistance = const Value.absent(),
    this.totalActivities = const Value.absent(),
    this.totalTime = const Value.absent(),
    this.cachedAt = const Value.absent(),
  });
  CachedProfilesCompanion.insert({
    this.id = const Value.absent(),
    required int userId,
    required String name,
    this.avatar = const Value.absent(),
    this.userGroup = const Value.absent(),
    this.city = const Value.absent(),
    this.age = const Value.absent(),
    this.followers = const Value.absent(),
    this.following = const Value.absent(),
    this.totalDistance = const Value.absent(),
    this.totalActivities = const Value.absent(),
    this.totalTime = const Value.absent(),
    this.cachedAt = const Value.absent(),
  }) : userId = Value(userId),
       name = Value(name);
  static Insertable<CachedProfile> custom({
    Expression<int>? id,
    Expression<int>? userId,
    Expression<String>? name,
    Expression<String>? avatar,
    Expression<int>? userGroup,
    Expression<String>? city,
    Expression<int>? age,
    Expression<int>? followers,
    Expression<int>? following,
    Expression<int>? totalDistance,
    Expression<int>? totalActivities,
    Expression<int>? totalTime,
    Expression<DateTime>? cachedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (name != null) 'name': name,
      if (avatar != null) 'avatar': avatar,
      if (userGroup != null) 'user_group': userGroup,
      if (city != null) 'city': city,
      if (age != null) 'age': age,
      if (followers != null) 'followers': followers,
      if (following != null) 'following': following,
      if (totalDistance != null) 'total_distance': totalDistance,
      if (totalActivities != null) 'total_activities': totalActivities,
      if (totalTime != null) 'total_time': totalTime,
      if (cachedAt != null) 'cached_at': cachedAt,
    });
  }

  CachedProfilesCompanion copyWith({
    Value<int>? id,
    Value<int>? userId,
    Value<String>? name,
    Value<String>? avatar,
    Value<int>? userGroup,
    Value<String?>? city,
    Value<int?>? age,
    Value<int?>? followers,
    Value<int?>? following,
    Value<int>? totalDistance,
    Value<int>? totalActivities,
    Value<int>? totalTime,
    Value<DateTime>? cachedAt,
  }) {
    return CachedProfilesCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      userGroup: userGroup ?? this.userGroup,
      city: city ?? this.city,
      age: age ?? this.age,
      followers: followers ?? this.followers,
      following: following ?? this.following,
      totalDistance: totalDistance ?? this.totalDistance,
      totalActivities: totalActivities ?? this.totalActivities,
      totalTime: totalTime ?? this.totalTime,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<int>(userId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (avatar.present) {
      map['avatar'] = Variable<String>(avatar.value);
    }
    if (userGroup.present) {
      map['user_group'] = Variable<int>(userGroup.value);
    }
    if (city.present) {
      map['city'] = Variable<String>(city.value);
    }
    if (age.present) {
      map['age'] = Variable<int>(age.value);
    }
    if (followers.present) {
      map['followers'] = Variable<int>(followers.value);
    }
    if (following.present) {
      map['following'] = Variable<int>(following.value);
    }
    if (totalDistance.present) {
      map['total_distance'] = Variable<int>(totalDistance.value);
    }
    if (totalActivities.present) {
      map['total_activities'] = Variable<int>(totalActivities.value);
    }
    if (totalTime.present) {
      map['total_time'] = Variable<int>(totalTime.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedProfilesCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('name: $name, ')
          ..write('avatar: $avatar, ')
          ..write('userGroup: $userGroup, ')
          ..write('city: $city, ')
          ..write('age: $age, ')
          ..write('followers: $followers, ')
          ..write('following: $following, ')
          ..write('totalDistance: $totalDistance, ')
          ..write('totalActivities: $totalActivities, ')
          ..write('totalTime: $totalTime, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }
}

class $CachedRoutesTable extends CachedRoutes
    with TableInfo<$CachedRoutesTable, CachedRoute> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedRoutesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _activityIdMeta = const VerificationMeta(
    'activityId',
  );
  @override
  late final GeneratedColumn<int> activityId = GeneratedColumn<int>(
    'activity_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<Coord>, String> points =
      GeneratedColumn<String>(
        'points',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<Coord>>($CachedRoutesTable.$converterpoints);
  @override
  late final GeneratedColumnWithTypeConverter<List<Coord>, String> bounds =
      GeneratedColumn<String>(
        'bounds',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<Coord>>($CachedRoutesTable.$converterbounds);
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    activityId,
    points,
    bounds,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_routes';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedRoute> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('activity_id')) {
      context.handle(
        _activityIdMeta,
        activityId.isAcceptableOrUnknown(data['activity_id']!, _activityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_activityIdMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedRoute map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedRoute(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      activityId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}activity_id'],
      )!,
      points: $CachedRoutesTable.$converterpoints.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}points'],
        )!,
      ),
      bounds: $CachedRoutesTable.$converterbounds.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}bounds'],
        )!,
      ),
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $CachedRoutesTable createAlias(String alias) {
    return $CachedRoutesTable(attachedDatabase, alias);
  }

  static TypeConverter<List<Coord>, String> $converterpoints =
      const CoordListConverter();
  static TypeConverter<List<Coord>, String> $converterbounds =
      const CoordListConverter();
}

class CachedRoute extends DataClass implements Insertable<CachedRoute> {
  final int id;
  final int activityId;
  final List<Coord> points;
  final List<Coord> bounds;
  final DateTime cachedAt;
  const CachedRoute({
    required this.id,
    required this.activityId,
    required this.points,
    required this.bounds,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['activity_id'] = Variable<int>(activityId);
    {
      map['points'] = Variable<String>(
        $CachedRoutesTable.$converterpoints.toSql(points),
      );
    }
    {
      map['bounds'] = Variable<String>(
        $CachedRoutesTable.$converterbounds.toSql(bounds),
      );
    }
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CachedRoutesCompanion toCompanion(bool nullToAbsent) {
    return CachedRoutesCompanion(
      id: Value(id),
      activityId: Value(activityId),
      points: Value(points),
      bounds: Value(bounds),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedRoute.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedRoute(
      id: serializer.fromJson<int>(json['id']),
      activityId: serializer.fromJson<int>(json['activityId']),
      points: serializer.fromJson<List<Coord>>(json['points']),
      bounds: serializer.fromJson<List<Coord>>(json['bounds']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'activityId': serializer.toJson<int>(activityId),
      'points': serializer.toJson<List<Coord>>(points),
      'bounds': serializer.toJson<List<Coord>>(bounds),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CachedRoute copyWith({
    int? id,
    int? activityId,
    List<Coord>? points,
    List<Coord>? bounds,
    DateTime? cachedAt,
  }) => CachedRoute(
    id: id ?? this.id,
    activityId: activityId ?? this.activityId,
    points: points ?? this.points,
    bounds: bounds ?? this.bounds,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  CachedRoute copyWithCompanion(CachedRoutesCompanion data) {
    return CachedRoute(
      id: data.id.present ? data.id.value : this.id,
      activityId: data.activityId.present
          ? data.activityId.value
          : this.activityId,
      points: data.points.present ? data.points.value : this.points,
      bounds: data.bounds.present ? data.bounds.value : this.bounds,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedRoute(')
          ..write('id: $id, ')
          ..write('activityId: $activityId, ')
          ..write('points: $points, ')
          ..write('bounds: $bounds, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, activityId, points, bounds, cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedRoute &&
          other.id == this.id &&
          other.activityId == this.activityId &&
          other.points == this.points &&
          other.bounds == this.bounds &&
          other.cachedAt == this.cachedAt);
}

class CachedRoutesCompanion extends UpdateCompanion<CachedRoute> {
  final Value<int> id;
  final Value<int> activityId;
  final Value<List<Coord>> points;
  final Value<List<Coord>> bounds;
  final Value<DateTime> cachedAt;
  const CachedRoutesCompanion({
    this.id = const Value.absent(),
    this.activityId = const Value.absent(),
    this.points = const Value.absent(),
    this.bounds = const Value.absent(),
    this.cachedAt = const Value.absent(),
  });
  CachedRoutesCompanion.insert({
    this.id = const Value.absent(),
    required int activityId,
    this.points = const Value.absent(),
    this.bounds = const Value.absent(),
    this.cachedAt = const Value.absent(),
  }) : activityId = Value(activityId);
  static Insertable<CachedRoute> custom({
    Expression<int>? id,
    Expression<int>? activityId,
    Expression<String>? points,
    Expression<String>? bounds,
    Expression<DateTime>? cachedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (activityId != null) 'activity_id': activityId,
      if (points != null) 'points': points,
      if (bounds != null) 'bounds': bounds,
      if (cachedAt != null) 'cached_at': cachedAt,
    });
  }

  CachedRoutesCompanion copyWith({
    Value<int>? id,
    Value<int>? activityId,
    Value<List<Coord>>? points,
    Value<List<Coord>>? bounds,
    Value<DateTime>? cachedAt,
  }) {
    return CachedRoutesCompanion(
      id: id ?? this.id,
      activityId: activityId ?? this.activityId,
      points: points ?? this.points,
      bounds: bounds ?? this.bounds,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (activityId.present) {
      map['activity_id'] = Variable<int>(activityId.value);
    }
    if (points.present) {
      map['points'] = Variable<String>(
        $CachedRoutesTable.$converterpoints.toSql(points.value),
      );
    }
    if (bounds.present) {
      map['bounds'] = Variable<String>(
        $CachedRoutesTable.$converterbounds.toSql(bounds.value),
      );
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedRoutesCompanion(')
          ..write('id: $id, ')
          ..write('activityId: $activityId, ')
          ..write('points: $points, ')
          ..write('bounds: $bounds, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CachedActivitiesTable cachedActivities = $CachedActivitiesTable(
    this,
  );
  late final $CachedProfilesTable cachedProfiles = $CachedProfilesTable(this);
  late final $CachedRoutesTable cachedRoutes = $CachedRoutesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cachedActivities,
    cachedProfiles,
    cachedRoutes,
  ];
}

typedef $$CachedActivitiesTableCreateCompanionBuilder =
    CachedActivitiesCompanion Function({
      Value<int> id,
      required int activityId,
      required int lentaId,
      required int userId,
      required String type,
      Value<DateTime?> dateStart,
      Value<DateTime?> dateEnd,
      required String userName,
      required String userAvatar,
      required int userGroup,
      Value<int> likes,
      Value<int> comments,
      Value<bool> isLike,
      Value<String> postDateText,
      Value<String> postMediaUrl,
      Value<String> postContent,
      Value<List<Equipment>> equipments,
      Value<ActivityStats?> stats,
      Value<List<Coord>> points,
      Value<List<String>> mediaImages,
      Value<List<String>> mediaVideos,
      Value<DateTime> cachedAt,
      required int cacheOwner,
    });
typedef $$CachedActivitiesTableUpdateCompanionBuilder =
    CachedActivitiesCompanion Function({
      Value<int> id,
      Value<int> activityId,
      Value<int> lentaId,
      Value<int> userId,
      Value<String> type,
      Value<DateTime?> dateStart,
      Value<DateTime?> dateEnd,
      Value<String> userName,
      Value<String> userAvatar,
      Value<int> userGroup,
      Value<int> likes,
      Value<int> comments,
      Value<bool> isLike,
      Value<String> postDateText,
      Value<String> postMediaUrl,
      Value<String> postContent,
      Value<List<Equipment>> equipments,
      Value<ActivityStats?> stats,
      Value<List<Coord>> points,
      Value<List<String>> mediaImages,
      Value<List<String>> mediaVideos,
      Value<DateTime> cachedAt,
      Value<int> cacheOwner,
    });

class $$CachedActivitiesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedActivitiesTable> {
  $$CachedActivitiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lentaId => $composableBuilder(
    column: $table.lentaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dateStart => $composableBuilder(
    column: $table.dateStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dateEnd => $composableBuilder(
    column: $table.dateEnd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userName => $composableBuilder(
    column: $table.userName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userAvatar => $composableBuilder(
    column: $table.userAvatar,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get userGroup => $composableBuilder(
    column: $table.userGroup,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get likes => $composableBuilder(
    column: $table.likes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get comments => $composableBuilder(
    column: $table.comments,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isLike => $composableBuilder(
    column: $table.isLike,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get postDateText => $composableBuilder(
    column: $table.postDateText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get postMediaUrl => $composableBuilder(
    column: $table.postMediaUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get postContent => $composableBuilder(
    column: $table.postContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<Equipment>, List<Equipment>, String>
  get equipments => $composableBuilder(
    column: $table.equipments,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<ActivityStats?, ActivityStats, String>
  get stats => $composableBuilder(
    column: $table.stats,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<Coord>, List<Coord>, String> get points =>
      $composableBuilder(
        column: $table.points,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get mediaImages => $composableBuilder(
    column: $table.mediaImages,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get mediaVideos => $composableBuilder(
    column: $table.mediaVideos,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cacheOwner => $composableBuilder(
    column: $table.cacheOwner,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedActivitiesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedActivitiesTable> {
  $$CachedActivitiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lentaId => $composableBuilder(
    column: $table.lentaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dateStart => $composableBuilder(
    column: $table.dateStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dateEnd => $composableBuilder(
    column: $table.dateEnd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userName => $composableBuilder(
    column: $table.userName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userAvatar => $composableBuilder(
    column: $table.userAvatar,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get userGroup => $composableBuilder(
    column: $table.userGroup,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get likes => $composableBuilder(
    column: $table.likes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get comments => $composableBuilder(
    column: $table.comments,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isLike => $composableBuilder(
    column: $table.isLike,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get postDateText => $composableBuilder(
    column: $table.postDateText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get postMediaUrl => $composableBuilder(
    column: $table.postMediaUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get postContent => $composableBuilder(
    column: $table.postContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get equipments => $composableBuilder(
    column: $table.equipments,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stats => $composableBuilder(
    column: $table.stats,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get points => $composableBuilder(
    column: $table.points,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaImages => $composableBuilder(
    column: $table.mediaImages,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaVideos => $composableBuilder(
    column: $table.mediaVideos,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cacheOwner => $composableBuilder(
    column: $table.cacheOwner,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedActivitiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedActivitiesTable> {
  $$CachedActivitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lentaId =>
      $composableBuilder(column: $table.lentaId, builder: (column) => column);

  GeneratedColumn<int> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<DateTime> get dateStart =>
      $composableBuilder(column: $table.dateStart, builder: (column) => column);

  GeneratedColumn<DateTime> get dateEnd =>
      $composableBuilder(column: $table.dateEnd, builder: (column) => column);

  GeneratedColumn<String> get userName =>
      $composableBuilder(column: $table.userName, builder: (column) => column);

  GeneratedColumn<String> get userAvatar => $composableBuilder(
    column: $table.userAvatar,
    builder: (column) => column,
  );

  GeneratedColumn<int> get userGroup =>
      $composableBuilder(column: $table.userGroup, builder: (column) => column);

  GeneratedColumn<int> get likes =>
      $composableBuilder(column: $table.likes, builder: (column) => column);

  GeneratedColumn<int> get comments =>
      $composableBuilder(column: $table.comments, builder: (column) => column);

  GeneratedColumn<bool> get isLike =>
      $composableBuilder(column: $table.isLike, builder: (column) => column);

  GeneratedColumn<String> get postDateText => $composableBuilder(
    column: $table.postDateText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get postMediaUrl => $composableBuilder(
    column: $table.postMediaUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get postContent => $composableBuilder(
    column: $table.postContent,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<List<Equipment>, String> get equipments =>
      $composableBuilder(
        column: $table.equipments,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<ActivityStats?, String> get stats =>
      $composableBuilder(column: $table.stats, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<Coord>, String> get points =>
      $composableBuilder(column: $table.points, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get mediaImages =>
      $composableBuilder(
        column: $table.mediaImages,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<List<String>, String> get mediaVideos =>
      $composableBuilder(
        column: $table.mediaVideos,
        builder: (column) => column,
      );

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);

  GeneratedColumn<int> get cacheOwner => $composableBuilder(
    column: $table.cacheOwner,
    builder: (column) => column,
  );
}

class $$CachedActivitiesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedActivitiesTable,
          CachedActivity,
          $$CachedActivitiesTableFilterComposer,
          $$CachedActivitiesTableOrderingComposer,
          $$CachedActivitiesTableAnnotationComposer,
          $$CachedActivitiesTableCreateCompanionBuilder,
          $$CachedActivitiesTableUpdateCompanionBuilder,
          (
            CachedActivity,
            BaseReferences<
              _$AppDatabase,
              $CachedActivitiesTable,
              CachedActivity
            >,
          ),
          CachedActivity,
          PrefetchHooks Function()
        > {
  $$CachedActivitiesTableTableManager(
    _$AppDatabase db,
    $CachedActivitiesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedActivitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedActivitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedActivitiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> activityId = const Value.absent(),
                Value<int> lentaId = const Value.absent(),
                Value<int> userId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<DateTime?> dateStart = const Value.absent(),
                Value<DateTime?> dateEnd = const Value.absent(),
                Value<String> userName = const Value.absent(),
                Value<String> userAvatar = const Value.absent(),
                Value<int> userGroup = const Value.absent(),
                Value<int> likes = const Value.absent(),
                Value<int> comments = const Value.absent(),
                Value<bool> isLike = const Value.absent(),
                Value<String> postDateText = const Value.absent(),
                Value<String> postMediaUrl = const Value.absent(),
                Value<String> postContent = const Value.absent(),
                Value<List<Equipment>> equipments = const Value.absent(),
                Value<ActivityStats?> stats = const Value.absent(),
                Value<List<Coord>> points = const Value.absent(),
                Value<List<String>> mediaImages = const Value.absent(),
                Value<List<String>> mediaVideos = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> cacheOwner = const Value.absent(),
              }) => CachedActivitiesCompanion(
                id: id,
                activityId: activityId,
                lentaId: lentaId,
                userId: userId,
                type: type,
                dateStart: dateStart,
                dateEnd: dateEnd,
                userName: userName,
                userAvatar: userAvatar,
                userGroup: userGroup,
                likes: likes,
                comments: comments,
                isLike: isLike,
                postDateText: postDateText,
                postMediaUrl: postMediaUrl,
                postContent: postContent,
                equipments: equipments,
                stats: stats,
                points: points,
                mediaImages: mediaImages,
                mediaVideos: mediaVideos,
                cachedAt: cachedAt,
                cacheOwner: cacheOwner,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int activityId,
                required int lentaId,
                required int userId,
                required String type,
                Value<DateTime?> dateStart = const Value.absent(),
                Value<DateTime?> dateEnd = const Value.absent(),
                required String userName,
                required String userAvatar,
                required int userGroup,
                Value<int> likes = const Value.absent(),
                Value<int> comments = const Value.absent(),
                Value<bool> isLike = const Value.absent(),
                Value<String> postDateText = const Value.absent(),
                Value<String> postMediaUrl = const Value.absent(),
                Value<String> postContent = const Value.absent(),
                Value<List<Equipment>> equipments = const Value.absent(),
                Value<ActivityStats?> stats = const Value.absent(),
                Value<List<Coord>> points = const Value.absent(),
                Value<List<String>> mediaImages = const Value.absent(),
                Value<List<String>> mediaVideos = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                required int cacheOwner,
              }) => CachedActivitiesCompanion.insert(
                id: id,
                activityId: activityId,
                lentaId: lentaId,
                userId: userId,
                type: type,
                dateStart: dateStart,
                dateEnd: dateEnd,
                userName: userName,
                userAvatar: userAvatar,
                userGroup: userGroup,
                likes: likes,
                comments: comments,
                isLike: isLike,
                postDateText: postDateText,
                postMediaUrl: postMediaUrl,
                postContent: postContent,
                equipments: equipments,
                stats: stats,
                points: points,
                mediaImages: mediaImages,
                mediaVideos: mediaVideos,
                cachedAt: cachedAt,
                cacheOwner: cacheOwner,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedActivitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedActivitiesTable,
      CachedActivity,
      $$CachedActivitiesTableFilterComposer,
      $$CachedActivitiesTableOrderingComposer,
      $$CachedActivitiesTableAnnotationComposer,
      $$CachedActivitiesTableCreateCompanionBuilder,
      $$CachedActivitiesTableUpdateCompanionBuilder,
      (
        CachedActivity,
        BaseReferences<_$AppDatabase, $CachedActivitiesTable, CachedActivity>,
      ),
      CachedActivity,
      PrefetchHooks Function()
    >;
typedef $$CachedProfilesTableCreateCompanionBuilder =
    CachedProfilesCompanion Function({
      Value<int> id,
      required int userId,
      required String name,
      Value<String> avatar,
      Value<int> userGroup,
      Value<String?> city,
      Value<int?> age,
      Value<int?> followers,
      Value<int?> following,
      Value<int> totalDistance,
      Value<int> totalActivities,
      Value<int> totalTime,
      Value<DateTime> cachedAt,
    });
typedef $$CachedProfilesTableUpdateCompanionBuilder =
    CachedProfilesCompanion Function({
      Value<int> id,
      Value<int> userId,
      Value<String> name,
      Value<String> avatar,
      Value<int> userGroup,
      Value<String?> city,
      Value<int?> age,
      Value<int?> followers,
      Value<int?> following,
      Value<int> totalDistance,
      Value<int> totalActivities,
      Value<int> totalTime,
      Value<DateTime> cachedAt,
    });

class $$CachedProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedProfilesTable> {
  $$CachedProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatar => $composableBuilder(
    column: $table.avatar,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get userGroup => $composableBuilder(
    column: $table.userGroup,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get city => $composableBuilder(
    column: $table.city,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get age => $composableBuilder(
    column: $table.age,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get followers => $composableBuilder(
    column: $table.followers,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get following => $composableBuilder(
    column: $table.following,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalDistance => $composableBuilder(
    column: $table.totalDistance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalActivities => $composableBuilder(
    column: $table.totalActivities,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalTime => $composableBuilder(
    column: $table.totalTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedProfilesTable> {
  $$CachedProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatar => $composableBuilder(
    column: $table.avatar,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get userGroup => $composableBuilder(
    column: $table.userGroup,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get city => $composableBuilder(
    column: $table.city,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get age => $composableBuilder(
    column: $table.age,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get followers => $composableBuilder(
    column: $table.followers,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get following => $composableBuilder(
    column: $table.following,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalDistance => $composableBuilder(
    column: $table.totalDistance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalActivities => $composableBuilder(
    column: $table.totalActivities,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalTime => $composableBuilder(
    column: $table.totalTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedProfilesTable> {
  $$CachedProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get avatar =>
      $composableBuilder(column: $table.avatar, builder: (column) => column);

  GeneratedColumn<int> get userGroup =>
      $composableBuilder(column: $table.userGroup, builder: (column) => column);

  GeneratedColumn<String> get city =>
      $composableBuilder(column: $table.city, builder: (column) => column);

  GeneratedColumn<int> get age =>
      $composableBuilder(column: $table.age, builder: (column) => column);

  GeneratedColumn<int> get followers =>
      $composableBuilder(column: $table.followers, builder: (column) => column);

  GeneratedColumn<int> get following =>
      $composableBuilder(column: $table.following, builder: (column) => column);

  GeneratedColumn<int> get totalDistance => $composableBuilder(
    column: $table.totalDistance,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalActivities => $composableBuilder(
    column: $table.totalActivities,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalTime =>
      $composableBuilder(column: $table.totalTime, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CachedProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedProfilesTable,
          CachedProfile,
          $$CachedProfilesTableFilterComposer,
          $$CachedProfilesTableOrderingComposer,
          $$CachedProfilesTableAnnotationComposer,
          $$CachedProfilesTableCreateCompanionBuilder,
          $$CachedProfilesTableUpdateCompanionBuilder,
          (
            CachedProfile,
            BaseReferences<_$AppDatabase, $CachedProfilesTable, CachedProfile>,
          ),
          CachedProfile,
          PrefetchHooks Function()
        > {
  $$CachedProfilesTableTableManager(
    _$AppDatabase db,
    $CachedProfilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> userId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> avatar = const Value.absent(),
                Value<int> userGroup = const Value.absent(),
                Value<String?> city = const Value.absent(),
                Value<int?> age = const Value.absent(),
                Value<int?> followers = const Value.absent(),
                Value<int?> following = const Value.absent(),
                Value<int> totalDistance = const Value.absent(),
                Value<int> totalActivities = const Value.absent(),
                Value<int> totalTime = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
              }) => CachedProfilesCompanion(
                id: id,
                userId: userId,
                name: name,
                avatar: avatar,
                userGroup: userGroup,
                city: city,
                age: age,
                followers: followers,
                following: following,
                totalDistance: totalDistance,
                totalActivities: totalActivities,
                totalTime: totalTime,
                cachedAt: cachedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int userId,
                required String name,
                Value<String> avatar = const Value.absent(),
                Value<int> userGroup = const Value.absent(),
                Value<String?> city = const Value.absent(),
                Value<int?> age = const Value.absent(),
                Value<int?> followers = const Value.absent(),
                Value<int?> following = const Value.absent(),
                Value<int> totalDistance = const Value.absent(),
                Value<int> totalActivities = const Value.absent(),
                Value<int> totalTime = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
              }) => CachedProfilesCompanion.insert(
                id: id,
                userId: userId,
                name: name,
                avatar: avatar,
                userGroup: userGroup,
                city: city,
                age: age,
                followers: followers,
                following: following,
                totalDistance: totalDistance,
                totalActivities: totalActivities,
                totalTime: totalTime,
                cachedAt: cachedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedProfilesTable,
      CachedProfile,
      $$CachedProfilesTableFilterComposer,
      $$CachedProfilesTableOrderingComposer,
      $$CachedProfilesTableAnnotationComposer,
      $$CachedProfilesTableCreateCompanionBuilder,
      $$CachedProfilesTableUpdateCompanionBuilder,
      (
        CachedProfile,
        BaseReferences<_$AppDatabase, $CachedProfilesTable, CachedProfile>,
      ),
      CachedProfile,
      PrefetchHooks Function()
    >;
typedef $$CachedRoutesTableCreateCompanionBuilder =
    CachedRoutesCompanion Function({
      Value<int> id,
      required int activityId,
      Value<List<Coord>> points,
      Value<List<Coord>> bounds,
      Value<DateTime> cachedAt,
    });
typedef $$CachedRoutesTableUpdateCompanionBuilder =
    CachedRoutesCompanion Function({
      Value<int> id,
      Value<int> activityId,
      Value<List<Coord>> points,
      Value<List<Coord>> bounds,
      Value<DateTime> cachedAt,
    });

class $$CachedRoutesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedRoutesTable> {
  $$CachedRoutesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<Coord>, List<Coord>, String> get points =>
      $composableBuilder(
        column: $table.points,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<List<Coord>, List<Coord>, String> get bounds =>
      $composableBuilder(
        column: $table.bounds,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedRoutesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedRoutesTable> {
  $$CachedRoutesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get points => $composableBuilder(
    column: $table.points,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bounds => $composableBuilder(
    column: $table.bounds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedRoutesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedRoutesTable> {
  $$CachedRoutesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<List<Coord>, String> get points =>
      $composableBuilder(column: $table.points, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<Coord>, String> get bounds =>
      $composableBuilder(column: $table.bounds, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CachedRoutesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedRoutesTable,
          CachedRoute,
          $$CachedRoutesTableFilterComposer,
          $$CachedRoutesTableOrderingComposer,
          $$CachedRoutesTableAnnotationComposer,
          $$CachedRoutesTableCreateCompanionBuilder,
          $$CachedRoutesTableUpdateCompanionBuilder,
          (
            CachedRoute,
            BaseReferences<_$AppDatabase, $CachedRoutesTable, CachedRoute>,
          ),
          CachedRoute,
          PrefetchHooks Function()
        > {
  $$CachedRoutesTableTableManager(_$AppDatabase db, $CachedRoutesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedRoutesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedRoutesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedRoutesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> activityId = const Value.absent(),
                Value<List<Coord>> points = const Value.absent(),
                Value<List<Coord>> bounds = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
              }) => CachedRoutesCompanion(
                id: id,
                activityId: activityId,
                points: points,
                bounds: bounds,
                cachedAt: cachedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int activityId,
                Value<List<Coord>> points = const Value.absent(),
                Value<List<Coord>> bounds = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
              }) => CachedRoutesCompanion.insert(
                id: id,
                activityId: activityId,
                points: points,
                bounds: bounds,
                cachedAt: cachedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedRoutesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedRoutesTable,
      CachedRoute,
      $$CachedRoutesTableFilterComposer,
      $$CachedRoutesTableOrderingComposer,
      $$CachedRoutesTableAnnotationComposer,
      $$CachedRoutesTableCreateCompanionBuilder,
      $$CachedRoutesTableUpdateCompanionBuilder,
      (
        CachedRoute,
        BaseReferences<_$AppDatabase, $CachedRoutesTable, CachedRoute>,
      ),
      CachedRoute,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CachedActivitiesTableTableManager get cachedActivities =>
      $$CachedActivitiesTableTableManager(_db, _db.cachedActivities);
  $$CachedProfilesTableTableManager get cachedProfiles =>
      $$CachedProfilesTableTableManager(_db, _db.cachedProfiles);
  $$CachedRoutesTableTableManager get cachedRoutes =>
      $$CachedRoutesTableTableManager(_db, _db.cachedRoutes);
}
