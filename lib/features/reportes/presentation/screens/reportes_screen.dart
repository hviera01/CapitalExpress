import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/ce_menu_card.dart';
import '../../../../core/widgets/ce_scaffold.dart';

class ReportesScreen extends StatelessWidget {
  const ReportesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CeScaffold(
      maxWidth: 900,
      appBar: AppBar(title: const Text('Reportes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GridView.count(
            crossAxisCount: esEscritorio(context) ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.05,
            children: [
              CeMenuCard(
                icono: Icons.people_outline,
                titulo: 'Reporte de Clientes',
                subtitulo: 'Cartera y saldos',
                onTap: () => context.push('/clientes/reporte'),
              ),
              CeMenuCard(
                icono: Icons.account_balance_outlined,
                titulo: 'Reporte de Préstamos',
                subtitulo: 'Estado y montos',
                onTap: () => context.push('/reportes/prestamos'),
              ),
              CeMenuCard(
                icono: Icons.payments_outlined,
                titulo: 'Reporte de Cobros',
                subtitulo: 'Pagos y saldados',
                onTap: () => context.push('/reportes/cobros'),
              ),
              CeMenuCard(
                oscuro: true,
                icono: Icons.dashboard_outlined,
                titulo: 'Dashboard General',
                subtitulo: 'Métricas y gráficos',
                onTap: () => context.push('/reportes/dashboard'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
