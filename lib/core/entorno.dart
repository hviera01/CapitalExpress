const bool esPruebas = String.fromEnvironment('ENTORNO') == 'pruebas';

const String proyectoFirebaseId =
    esPruebas ? 'capital-ef124' : 'capitalexpressapp-c03c5';
