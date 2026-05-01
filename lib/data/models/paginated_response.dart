class PaginatedResponse<T> {
  final List<T> data;
  final String? nextCursor;
  final String? prevCursor;
  final int perPage;
  final bool hasMore;

  PaginatedResponse({
    required this.data,
    this.nextCursor,
    this.prevCursor,
    required this.perPage,
    required this.hasMore,
  });

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    final dataList = (json['data'] as List<dynamic>?)
            ?.map((item) => fromJsonT(item as Map<String, dynamic>))
            .toList() ??
        [];

    return PaginatedResponse(
      data: dataList,
      nextCursor: json['next_cursor'] as String?,
      prevCursor: json['prev_cursor'] as String?,
      perPage: json['per_page'] as int? ?? 20,
      hasMore: json['next_cursor'] != null,
    );
  }
}
