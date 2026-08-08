import 'package:flutter/material.dart';

import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/ce_menu_card.dart';
import '../../../../core/widgets/ce_scaffold.dart';
import '../../../../core/widgets/ce_web_nav.dart';
import '../../../clientes/presentation/screens/reporte_clientes_screen.dart';
import '../../../dashboard/presentation/screens/dashboard_screen.dart';
import '../../../pagos/presentation/screens/reporte_cobros_screen.dart';
import '../../../prestamos/presentation/screens/reporte_prestamos_screen.dart';

class ReportesScreen extends StatelessWidget {
  const ReportesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CeScaffold(
      maxWidth: 900,
      appBar: AppBar(
        leading: const BackButton(),title: const Text('Reportes')),
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
                onTap: () => irAPantalla(context,
                    ruta: '/clientes/reporte', pantalla: const ReporteClientesScreen()),
              ),
              CeMenuCard(
                icono: Icons.account_balance_outlined,
                titulo: 'Reporte de Préstamos',
                subtitulo: 'Estado y montos',
                onTap: () => irAPantalla(context,
                    ruta: '/reportes/prestamos', pantalla: const ReportePrestamosScreen()),
              ),
              CeMenuCard(
                icono: Icons.payments_outlined,
                titulo: 'Reporte de Cobros',
                subtitulo: 'Pagos y saldados',
                onTap: () => irAPantalla(context,
                    ruta: '/reportes/cobros', pantalla: const ReporteCobrosScreen()),
              ),
              CeMenuCard(
                oscuro: true,
                icono: Icons.dashboard_outlined,
                titulo: 'Dashboard General',
                subtitulo: 'Métricas y gráficos',
                onTap: () => irAPantalla(context,
                    ruta: '/reportes/dashboard', pantalla: const DashboardScreen()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
