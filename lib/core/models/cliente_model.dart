import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/firestore_parse.dart';

/// Una referencia personal (ref1/ref2 en Firestore son un mapa anidado,
/// no campos planos referencia1Nombre/etc. como se habia asumido al
/// principio -- verificado contra un documento real).
class ReferenciaPersonal {
  final String nombre;
  final String identidad;
  final String telefono;
  final String parentesco;
  final String direccion;

  const ReferenciaPersonal({
    this.nombre = '',
    this.identidad = '',
    this.telefono = '',
    this.parentesco = '',
    this.direccion = '',
  });

  bool get estaVacia =>
      nombre.isEmpty && identidad.isEmpty && telefono.isEmpty && parentesco.isEmpty && direccion.isEmpty;

  factory ReferenciaPersonal.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const ReferenciaPersonal();
    String s(String k) => (m[k] ?? '') as String;
    return ReferenciaPersonal(
      nombre: s('nombre'),
      identidad: s('identidad'),
      telefono: s('telefono'),
      parentesco: s('parentesco'),
      direccion: s('direccion'),
    );
  }

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'identidad': identidad,
        'telefono': telefono,
        'parentesco': parentesco,
        'direccion': direccion,
      };
}

/// Espejo del doc `clientes` en Firestore -- nombres de campo verificados
/// contra un documento real (no contra el data class Kotlin, que estaba
/// desactualizado respecto a lo que CrearClienteScreen.kt realmente
/// escribe).
class ClienteModel {
  final String id;
  final String nombre;
  final String identidad;
  final String telefono;
  final String nombreEmpresa;
  final String direccionCasa;
  final String direccionNegocio;
  final String estadoCivil;
  final ReferenciaPersonal ref1;
  final ReferenciaPersonal ref2;
  final String fotoCasaUrl;
  final String fotoNegocioUrl;
  final String fotoPersonaUrl;
  final String fotoIdentidadFrenteUrl;
  final String fotoIdentidadReversoUrl;
  final String fotoReciboLuzUrl;
  final String fotoExtra1;
  final String fotoExtra2;
  final String fotoExtra3;
  final String garantia;
  final String fotoGarantiaUrl;
  final String estado;
  final bool tienePrestamo;
  final String? prestamoActivoId;
  final String cobradorAsignado;
  final String cobrador;
  final Timestamp? fechaCreacion;
  final Timestamp? ultimaActividad;

  const ClienteModel({
    required this.id,
    this.nombre = '',
    this.identidad = '',
    this.telefono = '',
    this.nombreEmpresa = '',
    this.direccionCasa = '',
    this.direccionNegocio = '',
    this.estadoCivil = '',
    this.ref1 = const ReferenciaPersonal(),
    this.ref2 = const ReferenciaPersonal(),
    this.fotoCasaUrl = '',
    this.fotoNegocioUrl = '',
    this.fotoPersonaUrl = '',
    this.fotoIdentidadFrenteUrl = '',
    this.fotoIdentidadReversoUrl = '',
    this.fotoReciboLuzUrl = '',
    this.fotoExtra1 = '',
    this.fotoExtra2 = '',
    this.fotoExtra3 = '',
    this.garantia = '',
    this.fotoGarantiaUrl = '',
    this.estado = 'activo',
    this.tienePrestamo = false,
    this.prestamoActivoId,
    this.cobradorAsignado = '',
    this.cobrador = '',
    this.fechaCreacion,
    this.ultimaActividad,
  });

  factory ClienteModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    String s(String k) => (d[k] ?? '') as String;
    return ClienteModel(
      id: doc.id,
      nombre: s('nombre'),
      identidad: s('identidad'),
      telefono: s('telefono'),
      nombreEmpresa: s('nombreEmpresa'),
      direccionCasa: s('direccionCasa'),
      direccionNegocio: s('direccionNegocio'),
      estadoCivil: s('estadoCivil'),
      ref1: ReferenciaPersonal.fromMap((d['ref1'] as Map?)?.cast<String, dynamic>()),
      ref2: ReferenciaPersonal.fromMap((d['ref2'] as Map?)?.cast<String, dynamic>()),
      fotoCasaUrl: s('fotoCasaUrl'),
      fotoNegocioUrl: s('fotoNegocioUrl'),
      fotoPersonaUrl: s('fotoPersonaUrl'),
      fotoIdentidadFrenteUrl: s('fotoIdentidadFrenteUrl'),
      fotoIdentidadReversoUrl: s('fotoIdentidadReversoUrl'),
      fotoReciboLuzUrl: s('fotoReciboLuzUrl'),
      fotoExtra1: s('fotoExtra1'),
      fotoExtra2: s('fotoExtra2'),
      fotoExtra3: s('fotoExtra3'),
      garantia: s('garantia'),
      fotoGarantiaUrl: s('fotoGarantiaUrl'),
      estado: d['estado'] == null ? 'activo' : s('estado'),
      tienePrestamo: (d['tienePrestamo'] ?? false) as bool,
      prestamoActivoId: d['prestamoActivoId'] as String?,
      cobradorAsignado: s('cobradorAsignado'),
      cobrador: s('cobrador'),
      fechaCreacion: asTimestamp(d['fechaCreacion']),
      ultimaActividad: asTimestamp(d['ultimaActividad']),
    );
  }

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'identidad': identidad,
        'telefono': telefono,
        'nombreEmpresa': nombreEmpresa,
        'direccionCasa': direccionCasa,
        'direccionNegocio': direccionNegocio,
        'estadoCivil': estadoCivil,
        'ref1': ref1.toMap(),
        'ref2': ref2.toMap(),
        'fotoCasaUrl': fotoCasaUrl,
        'fotoNegocioUrl': fotoNegocioUrl,
        'fotoPersonaUrl': fotoPersonaUrl,
        'fotoIdentidadFrenteUrl': fotoIdentidadFrenteUrl,
        'fotoIdentidadReversoUrl': fotoIdentidadReversoUrl,
        'fotoReciboLuzUrl': fotoReciboLuzUrl,
        'fotoExtra1': fotoExtra1,
        'fotoExtra2': fotoExtra2,
        'fotoExtra3': fotoExtra3,
        'garantia': garantia,
        'fotoGarantiaUrl': fotoGarantiaUrl,
        'estado': estado,
        'tienePrestamo': tienePrestamo,
        'cobradorAsignado': cobradorAsignado,
        'cobrador': cobrador,
      };
}
