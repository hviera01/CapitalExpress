import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/prestamo_repository.dart';

final prestamoRepositoryProvider = Provider<PrestamoRepository>((ref) => PrestamoRepository());
