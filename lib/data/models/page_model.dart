import 'package:hive/hive.dart';
import 'text_block_model.dart';

part 'page_model.g.dart';

@HiveType(typeId: 1)
class PageModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String imagePath;

  @HiveField(2)
  final List<TextBlockModel> textBlocks;

  @HiveField(3)
  final int pageIndex;

  @HiveField(4)
  final DateTime createdAt;
  
  @HiveField(5)
  final double imageWidth;
  
  @HiveField(6)
  final double imageHeight;

  PageModel({
    required this.id,
    required this.imagePath,
    required this.textBlocks,
    required this.pageIndex,
    required this.createdAt,
    this.imageWidth = 0.0,
    this.imageHeight = 0.0,
  });

  PageModel copyWith({
    String? id,
    String? imagePath,
    List<TextBlockModel>? textBlocks,
    int? pageIndex,
    DateTime? createdAt,
    double? imageWidth,
    double? imageHeight,
  }) {
    return PageModel(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      textBlocks: textBlocks ?? this.textBlocks,
      pageIndex: pageIndex ?? this.pageIndex,
      createdAt: createdAt ?? this.createdAt,
      imageWidth: imageWidth ?? this.imageWidth,
      imageHeight: imageHeight ?? this.imageHeight,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imagePath': imagePath,
      'textBlocks': textBlocks.map((block) => {
        'left': block.left,
        'top': block.top,
        'right': block.right,
        'bottom': block.bottom,
        'text': block.text,
        'isDeleted': block.isDeleted,
      }).toList(),
      'pageIndex': pageIndex,
      'createdAt': createdAt.toIso8601String(),
      'imageWidth': imageWidth,
      'imageHeight': imageHeight,
    };
  }

  static PageModel fromJson(Map<String, dynamic> json) {
    return PageModel(
      id: json['id'] as String,
      imagePath: json['imagePath'] as String,
      textBlocks: (json['textBlocks'] as List).map((blockJson) {
        return TextBlockModel(
          left: blockJson['left'] as double,
          top: blockJson['top'] as double,
          right: blockJson['right'] as double,
          bottom: blockJson['bottom'] as double,
          text: blockJson['text'] as String,
          isDeleted: blockJson['isDeleted'] as bool,
        );
      }).toList(),
      pageIndex: json['pageIndex'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      imageWidth: json['imageWidth'] as double? ?? 0.0,
      imageHeight: json['imageHeight'] as double? ?? 0.0,
    );
  }
}