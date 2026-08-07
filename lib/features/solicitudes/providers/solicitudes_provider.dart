import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/solicitud_repository.dart';

final solicitudRepositoryProvider = Provider<SolicitudRepository>((ref) => SolicitudRepository());
