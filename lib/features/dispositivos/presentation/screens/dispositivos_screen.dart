import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/actualizacion_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/ce_card.dart';
import '../../../../core/widgets/ce_data_table_style.dart';
import '../../../../core/widgets/ce_scaffold.dart';
import '../../providers/dispositivos_provider.dart';

/// Ver Dispositivos (solo admin): que equipos han accedido, con que
/// usuario, cuando y con que version de la app -- cada dispositivo
/// actualiza su propio registro solo al iniciar sesion (ver
/// DispositivoRepository.reportar, llamado desde InactividadGuard), asi
/// que si alguien no abre la app hace tiempo su fila queda vieja.
class DispositivosScreen extends ConsumerStatefulWidget {
  const DispositivosScreen({super.key});

  @override
  ConsumerState<DispositivosScreen> createState() => _DispositivosScreenState();
}

class _DispositivosScreenState extends ConsumerState<DispositivosScreen> {
  int? _ultimaVersionPublicada;

  @override
  void initState() {
    super.initState();
    ActualizacionService.obtenerUltimaVersionPublicada().then((v) {
      if (mounted) setState(() => _ultimaVersionPublicada = v);
    });
  }

  bool _desactualizado(int versionApp) =>
      _ultimaVersionPublicada != null && versionApp < _ultimaVersionPublicada!;

  @override
  Widget build(BuildContext context) {
    final dispositivosAsync = ref.watch(dispositivosStreamProvider);

    return CeScaffold(
      maxWidth: 1000,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Dispositivos'),
        actions: [
          if (_ultimaVersionPublicada != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Última versión: v$_ultimaVersionPublicada',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
        ],
      ),
      body: dispositivosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error al cargar: $e')),
        data: (dispositivos) {
          if (dispositivos.isEmpty) {
            return const Center(child: Text('Todavía no hay dispositivos registrados'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Cada equipo actualiza este registro solo al iniciar sesión: si alguien no ha '
                'abierto la app en un tiempo, su fila va a quedar vieja.',
                style: TextStyle(fontSize: 12, color: CEColors.textSecondary),
              ),
              const SizedBox(height: 16),
              if (esEscritorioWeb(context))
                _TablaDispositivos(dispositivos: dispositivos, desactualizado: _desactualizado)
              else
                ...dispositivos.map((d) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _CardDispositivo(dispositivo: d, desactualizado: _desactualizado(d.versionApp)),
                    )),
            ],
          );
        },
      ),
    );
  }
}

class _TablaDispositivos extends StatelessWidget {
  final List dispositivos;
  final bool Function(int) desactualizado;

  const _TablaDispositivos({required this.dispositivos, required this.desactualizado});

  @override
  Widget build(BuildContext context) {
    final f = DateFormat('dd/MM/yyyy hh:mm a');
    return CeDataTableCard(
      columns: const [
        DataColumn(label: Text('Dispositivo')),
        DataColumn(label: Text('Plataforma')),
        DataColumn(label: Text('Versión')),
        DataColumn(label: Text('Último usuario')),
        DataColumn(label: Text('Última conexión')),
      ],
      rows: dispositivos.map<DataRow>((d) {
        final vieja = desactualizado(d.versionApp);
        return DataRow(cells: [
          DataCell(Text(d.id, style: const TextStyle(fontWeight: FontWeight.w600))),
          DataCell(Text(d.plataforma)),
          DataCell(ceTableBadge('v${d.versionApp}', vieja ? CEColors.danger : CEColors.success)),
          DataCell(Text(d.usuario.isEmpty ? '—' : d.usuario)),
          DataCell(Text(d.ultimaConexion != null ? f.format(d.ultimaConexion!) : '—')),
        ]);
      }).toList(),
    );
  }
}

class _CardDispositivo extends StatelessWidget {
  final dynamic dispositivo;
  final bool desactualizado;

  const _CardDispositivo({required this.dispositivo, required this.desactualizado});

  @override
  Widget build(BuildContext context) {
    final d = dispositivo;
    final f = DateFormat('dd/MM/yyyy hh:mm a');
    return CeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(d.id,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              ceTableBadge('v${d.versionApp}', desactualizado ? CEColors.danger : CEColors.success),
            ],
          ),
          const SizedBox(height: 6),
          Text(d.plataforma, style: const TextStyle(fontSize: 12, color: CEColors.textSecondary)),
          const SizedBox(height: 4),
          Text('Usuario: ${d.usuario.isEmpty ? 'Sin registrar' : d.usuario}',
              style: const TextStyle(fontSize: 12, color: CEColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            d.ultimaConexion != null
                ? 'Última conexión: ${f.format(d.ultimaConexion!)}'
                : 'Última conexión: —',
            style: const TextStyle(fontSize: 12, color: CEColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
