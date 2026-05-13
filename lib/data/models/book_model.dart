import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';
import 'page_model.dart';

part 'book_model.g.dart';

@HiveType(typeId: 0)
class BookModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  final DateTime createdAt;

  @HiveField(3)
  DateTime updatedAt;

  @HiveField(4)
  List<PageModel> pages;

  @HiveField(5)
  int currentPageIndex;

  @HiveField(6)
  String? customCoverPath;

  BookModel({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.pages,
    this.currentPageIndex = 0,
    this.customCoverPath,
  });

  String? get coverImagePath {
    if (customCoverPath != null) return customCoverPath;
    if (pages.isEmpty) return null;
    return pages.first.imagePath;
  }

  int get pageCount => pages.length;

  BookModel copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<PageModel>? pages,
    int? currentPageIndex,
    String? customCoverPath,
    bool clearCustomCover = false,
  }) {
    return BookModel(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pages: pages ?? this.pages,
      currentPageIndex: currentPageIndex ?? this.currentPageIndex,
      customCoverPath: clearCustomCover ? null : (customCoverPath ?? this.customCoverPath),
    );
  }

  void addPage(PageModel page) {
    pages.add(page);
    updatedAt = DateTime.now();
    save();
  }

  void removePage(int index) {
    if (index >= 0 && index < pages.length) {
      pages.removeAt(index);
      if (currentPageIndex >= pages.length && pages.isNotEmpty) {
        currentPageIndex = pages.length - 1;
      }
      updatedAt = DateTime.now();
      save();
    }
  }

  void updatePage(int index, PageModel newPage) {
    if (index >= 0 && index < pages.length) {
      debugPrint('=== BookModel.updatePage ===');
      debugPrint('更新索引: $index');
      debugPrint('旧页面textBlocks:');
      for (int i = 0; i < pages[index].textBlocks.length; i++) {
        debugPrint('  old[$i]: text="${pages[index].textBlocks[i].text}", isDeleted=${pages[index].textBlocks[i].isDeleted}');
      }
      debugPrint('新页面textBlocks:');
      for (int i = 0; i < newPage.textBlocks.length; i++) {
        debugPrint('  new[$i]: text="${newPage.textBlocks[i].text}", isDeleted=${newPage.textBlocks[i].isDeleted}');
      }
      
      pages[index] = newPage;
      updatedAt = DateTime.now();
      
      debugPrint('更新后pages[$index].textBlocks:');
      for (int i = 0; i < pages[index].textBlocks.length; i++) {
        debugPrint('  updated[$i]: text="${pages[index].textBlocks[i].text}", isDeleted=${pages[index].textBlocks[i].isDeleted}');
      }
      
      save();
      debugPrint('已调用save()');
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'pages': pages.map((page) => page.toJson()).toList(),
      'currentPageIndex': currentPageIndex,
      'customCoverPath': customCoverPath,
    };
  }

  static BookModel fromJson(Map<String, dynamic> json) {
    return BookModel(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      pages: (json['pages'] as List).map((pageJson) {
        return PageModel.fromJson(pageJson as Map<String, dynamic>);
      }).toList(),
      currentPageIndex: json['currentPageIndex'] as int,
      customCoverPath: json['customCoverPath'] as String?,
    );
  }
}