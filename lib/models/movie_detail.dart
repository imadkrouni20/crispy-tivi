class MovieDetail {
  final String id;
  final String name;
  final String? plot;
  final String? poster;
  final String? year;
  final String? duration;
  final String? rating;
  final String? genre;
  final String? director;
  final String? cast;
  final String streamUrl;

  MovieDetail({
    required this.id,
    required this.name,
    required this.streamUrl,
    this.plot,
    this.poster,
    this.year,
    this.duration,
    this.rating,
    this.genre,
    this.director,
    this.cast,
  });

  factory MovieDetail.fromJson(
    Map<String, dynamic> data,
    String base,
    String username,
    String password,
    String vodId,
  ) {
    final info = (data['info'] as Map?) ?? {};
    final movieData = (data['movie_data'] as Map?) ?? {};

    final ext = movieData['container_extension'] ?? 'mp4';
    final streamUrl = '$base/movie/$username/$password/$vodId.$ext';

    return MovieDetail(
      id: vodId,
      name: (info['name'] ?? movieData['name'] ?? 'فيلم').toString(),
      plot: info['plot']?.toString(),
      poster: (info['movie_image'] ?? info['cover'])?.toString(),
      year: info['releasedate']?.toString() ?? info['releaseDate']?.toString(),
      duration: info['duration']?.toString(),
      rating: info['rating']?.toString(),
      genre: info['genre']?.toString(),
      director: info['director']?.toString(),
      cast: info['cast']?.toString(),
      streamUrl: streamUrl,
    );
  }
}
