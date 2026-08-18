import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/solicitud_edicion_repository.dart';

final solicitudEdicionRepositoryProvider =
    Provider<SolicitudEdicionRepository>((ref) => SolicitudEdicionRepository());
