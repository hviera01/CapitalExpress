import 'package:cloud_firestore/cloud_firestore.dart';

/// Espejo del doc `clientes` en Firestore (ui/models/ClienteModel.kt).
class ClienteModel {
  final String id;
  final String nombre;
  final String identidad;
  final String telefono;
  final String direccionCasa;
  final String direccionNegocio;
  final String estadoCivil;
  final String nombreConyuge;
  final String identidadConyuge;
  final String telefonoConyuge;
  final String referencia1Nombre;
  final String referencia1Identidad;
  final String referencia1Telefono;
  final String referencia1Parentesco;
  final String referencia1Direccion;
  final String referencia2Nombre;
  final String referencia2Identidad;
  final String referencia2Telefono;
  final String referencia2Parentesco;
  final String referencia2Direccion;
  final String fotoCasaUrl;
  final String fotoNegocioUrl;
  final String fotoClienteUrl;
  final String fotoIdentidadFrenteUrl;
  final String fotoIdentidadReversoUrl;
  final String fotoReciboLuzUrl;
  final String garantiaTexto;
  final String garantiaFotoUrl;
  final String estado;
  final bool tienePrestamo;
  final String cobradorAsignado;
  final Timestamp? fechaCreacion;
  final Timestamp? ultimaActividad;

  const ClienteModel({
    required this.id,
    this.nombre = '',
    this.identidad = '',
    this.telefono = '',
    this.direccionCasa = '',
    this.direccionNegocio = '',
    this.estadoCivil = '',
    this.nombreConyuge = '',
    this.identidadConyuge = '',
    this.telefonoConyuge = '',
    this.referencia1Nombre = '',
    this.referencia1Identidad = '',
    this.referencia1Telefono = '',
    this.referencia1Parentesco = '',
    this.referencia1Direccion = '',
    this.referencia2Nombre = '',
    this.referencia2Identidad = '',
    this.referencia2Telefono = '',
    this.referencia2Parentesco = '',
    this.referencia2Direccion = '',
    this.fotoCasaUrl = '',
    this.fotoNegocioUrl = '',
    this.fotoClienteUrl = '',
    this.fotoIdentidadFrenteUrl = '',
    this.fotoIdentidadReversoUrl = '',
    this.fotoReciboLuzUrl = '',
    this.garantiaTexto = '',
    this.garantiaFotoUrl = '',
    this.estado = 'activo',
    this.tienePrestamo = false,
    this.cobradorAsignado = '',
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
      direccionCasa: s('direccionCasa'),
      direccionNegocio: s('direccionNegocio'),
      estadoCivil: s('estadoCivil'),
      nombreConyuge: s('nombreConyuge'),
      identidadConyuge: s('identidadConyuge'),
      telefonoConyuge: s('telefonoConyuge'),
      referencia1Nombre: s('referencia1Nombre'),
      referencia1Identidad: s('referencia1Identidad'),
      referencia1Telefono: s('referencia1Telefono'),
      referencia1Parentesco: s('referencia1Parentesco'),
      referencia1Direccion: s('referencia1Direccion'),
      referencia2Nombre: s('referencia2Nombre'),
      referencia2Identidad: s('referencia2Identidad'),
      referencia2Telefono: s('referencia2Telefono'),
      referencia2Parentesco: s('referencia2Parentesco'),
      referencia2Direccion: s('referencia2Direccion'),
      fotoCasaUrl: s('fotoCasaUrl'),
      fotoNegocioUrl: s('fotoNegocioUrl'),
      fotoClienteUrl: s('fotoClienteUrl'),
      fotoIdentidadFrenteUrl: s('fotoIdentidadFrenteUrl'),
      fotoIdentidadReversoUrl: s('fotoIdentidadReversoUrl'),
      fotoReciboLuzUrl: s('fotoReciboLuzUrl'),
      garantiaTexto: s('garantiaTexto'),
      garantiaFotoUrl: s('garantiaFotoUrl'),
      estado: d['estado'] == null ? 'activo' : s('estado'),
      tienePrestamo: (d['tienePrestamo'] ?? false) as bool,
      cobradorAsignado: s('cobradorAsignado'),
      fechaCreacion: d['fechaCreacion'] as Timestamp?,
      ultimaActividad: d['ultimaActividad'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'identidad': identidad,
        'telefono': telefono,
        'direccionCasa': direccionCasa,
        'direccionNegocio': direccionNegocio,
        'estadoCivil': estadoCivil,
        'nombreConyuge': nombreConyuge,
        'identidadConyuge': identidadConyuge,
        'telefonoConyuge': telefonoConyuge,
        'referencia1Nombre': referencia1Nombre,
        'referencia1Identidad': referencia1Identidad,
        'referencia1Telefono': referencia1Telefono,
        'referencia1Parentesco': referencia1Parentesco,
        'referencia1Direccion': referencia1Direccion,
        'referencia2Nombre': referencia2Nombre,
        'referencia2Identidad': referencia2Identidad,
        'referencia2Telefono': referencia2Telefono,
        'referencia2Parentesco': referencia2Parentesco,
        'referencia2Direccion': referencia2Direccion,
        'fotoCasaUrl': fotoCasaUrl,
        'fotoNegocioUrl': fotoNegocioUrl,
        'fotoClienteUrl': fotoClienteUrl,
        'fotoIdentidadFrenteUrl': fotoIdentidadFrenteUrl,
        'fotoIdentidadReversoUrl': fotoIdentidadReversoUrl,
        'fotoReciboLuzUrl': fotoReciboLuzUrl,
        'garantiaTexto': garantiaTexto,
        'garantiaFotoUrl': garantiaFotoUrl,
        'estado': estado,
        'tienePrestamo': tienePrestamo,
        'cobradorAsignado': cobradorAsignado,
      };
}
