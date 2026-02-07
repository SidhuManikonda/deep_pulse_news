class Article {
  final String id;
  final String title;
  final String description;
  final String content;
  final String url;
  final String urlToImage;
  final String publishedAt;
  final String author;
  final Source source;
  final String category;

  Article({
    required this.id,
    required this.title,
    required this.description,
    required this.content,
    required this.url,
    required this.urlToImage,
    required this.publishedAt,
    required this.author,
    required this.source,
    required this.category,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      content: json['content'] ?? '',
      url: json['url'] ?? '',
      urlToImage: json['urlToImage'] ?? '',
      publishedAt: json['publishedAt'] ?? '',
      author: json['author'] ?? '',
      source: Source.fromJson(json['source'] ?? {}),
      category: json['category'] ?? 'general',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'content': content,
      'url': url,
      'urlToImage': urlToImage,
      'publishedAt': publishedAt,
      'author': author,
      'source': source.toJson(),
      'category': category,
    };
  }

  Article copyWith({
    String? id,
    String? title,
    String? description,
    String? content,
    String? url,
    String? urlToImage,
    String? publishedAt,
    String? author,
    Source? source,
    String? category,
  }) {
    return Article(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      content: content ?? this.content,
      url: url ?? this.url,
      urlToImage: urlToImage ?? this.urlToImage,
      publishedAt: publishedAt ?? this.publishedAt,
      author: author ?? this.author,
      source: source ?? this.source,
      category: category ?? this.category,
    );
  }
}

class Source {
  final String id;
  final String name;

  Source({
    required this.id,
    required this.name,
  });

  factory Source.fromJson(Map<String, dynamic> json) {
    return Source(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}
