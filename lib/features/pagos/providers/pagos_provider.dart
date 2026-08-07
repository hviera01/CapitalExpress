import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/pago_repository.dart';

final pagoRepositoryProvider = Provider<PagoRepository>((ref) => PagoRepository());
