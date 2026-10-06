class SeriesEpisode {
  final String id;
  final String title;
  final int season;
  final int episode;
  final String streamUrl;
  final String? plot;
  final String? duration;
  final String? poster;

  SeriesEpisode({
    required this.id,
    required this.title,
    required this.season,
    required this.episode,
    required this.streamUrl,
    this.plot,
    this.duration,
    this.poster,
  });
}

class SeriesDetail {
  final String id;
  final String name;
  final String? plot;
  final String? poster;
  final String? year;
  final String? rating;
  final String? genre;
  final String? cast;
  final String? director;
  final Map<int, List<SeriesEpisode>> episodes; // season → episodes

  SeriesDetail({
    required this.id,
    required this.name,
    required this.episodes,
    this.plot,
    this.poster,
    this.year,
    this.rating,
    this.genre,
    this.cast,
    this.director,
  });

  List<int> get seasons => episodes.keys.toList()..sort();

  factory SeriesDetail.fromJson(
    Map<String, dynamic> data,
    String base,
    String username,
    String password,
  ) {
    final info = (data['info'] as Map?) ?? {};
    final eps = <int, List<SeriesEpisode>>{};

    final episodesRaw = data['episodes'];
    if (episodesRaw is Map) {
      episodesRaw.forEach((seasonKey, epList) {
        final season = int.tryParse(seasonKey.toString()) ?? 1;
        if (epList is List) {
          final list = <SeriesEpisode>[];
          for (final e in epList) {
            final id = e['id']?.toString() ?? '';
            final epNum =
                int.tryParse(e['episode_num']?.toString() ?? '0') ?? 0;
            final ext = e['container_extension'] ?? 'mp4';
            final title = e['title']?.toString() ?? 'حلقة $epNum';
            list.add(SeriesEpisode(
              id: id,
              title: title,
              season: season,
              episode: epNum,
              streamUrl: '$base/series/$username/$password/$id.$ext',
              plot: e['plot']?.toString(),
              duration: e['duration']?.toString(),
              poster: e['movie_image']?.toString() ??
                  info['cover']?.toString(),
            ));
          }
          list.sort((a, b) => a.episode.compareTo(b.episode));
          eps[season] = list;
        }
      });
    }

    return SeriesDetail(
      id: info['series_id']?.toString() ?? '',
      name: info['name']?.toString() ?? 'مسلسل',
      plot: info['plot']?.toString(),
      poster: (info['cover'] ?? info['movie_image'])?.toString(),
      year:
          info['releaseDate']?.toString() ?? info['releasedate']?.toString(),
      rating: info['rating']?.toString(),
      genre: info['genre']?.toString(),
      cast: info['cast']?.toString(),
      director: info['director']?.toString(),
      episodes: eps,
    );
  }
}
