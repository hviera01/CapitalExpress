import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/cliente_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ce_card.dart';
import '../../../../core/widgets/ce_scaffold.dart';
import '../../../../core/widgets/imagen_red_network.dart';
import '../../../../core/widgets/visor_foto_zoom.dart';
import '../../providers/clientes_provider.dart';

class ClienteDetalleScreen extends ConsumerStatefulWidget {
  final String clienteId;

  const ClienteDetalleScreen({super.key, required this.clienteId});

  @override
  ConsumerState<ClienteDetalleScreen> createState() => _ClienteDetalleScreenState();
}

class _ClienteDetalleScreenState extends ConsumerState<ClienteDetalleScreen> {
  ClienteModel? _cliente;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    ref.read(clienteRepositoryProvider).obtenerPorId(widget.clienteId).then((c) {
      if (mounted) {
        setState(() {
          _cliente = c;
          _cargando = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final c = _cliente;
    if (c == null) {
      return const Scaffold(body: Center(child: Text('Cliente no encontrado')));
    }

    return CeScaffold(
      maxWidth: 720,
      appBar: AppBar(
        leading: const BackButton(),title: const Text('Detalle del Cliente')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Titulo('Datos Personales', Icons.badge_outlined),
                _fila('Nombre', c.nombre),
                _fila('Identidad', c.identidad),
                _fila('Teléfono', c.telefono),
                _fila('Estado', c.estado),
              ],
            ),
          ),
          const SizedBox(height: 14),
          CeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Titulo('Datos de Trabajo', Icons.work_outline),
                if (c.nombreEmpresa.isNotEmpty) _fila('Empresa', c.nombreEmpresa),
                _fila('Garantía', c.garantia),
                _fila('Dirección Casa', c.direccionCasa),
                _fila('Dirección Negocio', c.direccionNegocio),
              ],
            ),
          ),
          if (c.estadoCivil.isNotEmpty) ...[
            const SizedBox(height: 14),
            CeCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Titulo('Estado Civil', Icons.favorite_outline),
                  _fila('Estado civil', c.estadoCivil),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          CeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Titulo('Referencias Personales', Icons.contacts_outlined),
                if (!c.ref1.estaVacia) ...[
                  const Text('Referencia 1', style: TextStyle(fontWeight: FontWeight.w700)),
                  _fila('Nombre', c.ref1.nombre),
                  _fila('Identidad', c.ref1.identidad),
                  _fila('Teléfono', c.ref1.telefono),
                  _fila('Parentesco', c.ref1.parentesco),
                  _fila('Dirección', c.ref1.direccion),
                  const Divider(height: 24),
                ],
                if (!c.ref2.estaVacia) ...[
                  const Text('Referencia 2', style: TextStyle(fontWeight: FontWeight.w700)),
                  _fila('Nombre', c.ref2.nombre),
                  _fila('Identidad', c.ref2.identidad),
                  _fila('Teléfono', c.ref2.telefono),
                  _fila('Parentesco', c.ref2.parentesco),
                  _fila('Dirección', c.ref2.direccion),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          CeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Titulo('Fotos', Icons.photo_library_outlined),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    c.fotoPersonaUrl,
                    c.fotoCasaUrl,
                    c.fotoNegocioUrl,
                    c.fotoIdentidadFrenteUrl,
                    c.fotoIdentidadReversoUrl,
                    c.fotoReciboLuzUrl,
                    c.fotoGarantiaUrl,
                    c.fotoExtra1,
                    c.fotoExtra2,
                    c.fotoExtra3,
                  ]
                      .where((u) => u.isNotEmpty)
                      .map((u) => GestureDetector(
                            onTap: () => abrirFotoZoom(context, u),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child:
                                  SizedBox(width: 90, height: 90, child: ImagenRedNetwork(url: u)),
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _fila(String label, String valor) {
    if (valor.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: CEColors.textSecondary, fontSize: 13)),
          Flexible(
            child: Text(valor,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  final String texto;
  final IconData icono;

  const _Titulo(this.texto, this.icono);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icono, size: 18, color: CEColors.primary),
          const SizedBox(width: 8),
          Text(texto, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }
}
