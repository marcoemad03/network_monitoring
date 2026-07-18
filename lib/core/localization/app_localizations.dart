import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('en', 'US'),
    Locale('es', 'ES'),
  ];

  String get appName => _translate('appName');
  String get dashboard => _translate('dashboard');
  String get devices => _translate('devices');
  String get alerts => _translate('alerts');
  String get network => _translate('network');
  String get settings => _translate('settings');
  String get auditLog => _translate('auditLog');
  String get users => _translate('users');
  String get login => _translate('login');
  String get logout => _translate('logout');
  String get username => _translate('username');
  String get password => _translate('password');
  String get forgotPassword => _translate('forgotPassword');
  String get rememberMe => _translate('rememberMe');
  String get search => _translate('search');
  String get filter => _translate('filter');
  String get apply => _translate('apply');
  String get cancel => _translate('cancel');
  String get confirm => _translate('confirm');
  String get save => _translate('save');
  String get delete => _translate('delete');
  String get edit => _translate('edit');
  String get create => _translate('create');
  String get loading => _translate('loading');
  String get noData => _translate('noData');
  String get errorOccurred => _translate('errorOccurred');
  String get retry => _translate('retry');
  String get online => _translate('online');
  String get offline => _translate('offline');
  String get degraded => _translate('degraded');
  String get maintenance => _translate('maintenance');
  String get unknown => _translate('unknown');
  String get critical => _translate('critical');
  String get high => _translate('high');
  String get medium => _translate('medium');
  String get low => _translate('low');
  String get info => _translate('info');
  String get deviceName => _translate('deviceName');
  String get ipAddress => _translate('ipAddress');
  String get macAddress => _translate('macAddress');
  String get deviceType => _translate('deviceType');
  String get status => _translate('status');
  String get lastSeen => _translate('lastSeen');
  String get uptime => _translate('uptime');
  String get interfaces => _translate('interfaces');
  String get traffic => _translate('traffic');
  String get bandwidth => _translate('bandwidth');
  String get latency => _translate('latency');
  String get packetLoss => _translate('packetLoss');
  String get cpuUsage => _translate('cpuUsage');
  String get memoryUsage => _translate('memoryUsage');
  String get diskUsage => _translate('diskUsage');
  String get temperature => _translate('temperature');
  String get networkMap => _translate('networkMap');
  String get scanNetwork => _translate('scanNetwork');
  String get scanResults => _translate('scanResults');
  String get acknowledgeAlert => _translate('acknowledgeAlert');
  String get resolveAlert => _translate('resolveAlert');
  String get alertDetails => _translate('alertDetails');
  String get alertHistory => _translate('alertHistory');
  String get darkMode => _translate('darkMode');
  String get lightMode => _translate('lightMode');
  String get systemMode => _translate('systemMode');
  String get language => _translate('language');
  String get about => _translate('about');
  String get version => _translate('version');
  String get help => _translate('help');

  String _translate(String key) {
    return _translations[locale.languageCode]?[key] ?? _translations['en']![key] ?? key;
  }

  static final Map<String, Map<String, String>> _translations = {
    'en': {
      'appName': 'Hospital NMS',
      'dashboard': 'Dashboard',
      'devices': 'Devices',
      'alerts': 'Alerts',
      'network': 'Network',
      'settings': 'Settings',
      'auditLog': 'Audit Log',
      'users': 'Users',
      'login': 'Login',
      'logout': 'Logout',
      'username': 'Username',
      'password': 'Password',
      'forgotPassword': 'Forgot Password',
      'rememberMe': 'Remember Me',
      'search': 'Search',
      'filter': 'Filter',
      'apply': 'Apply',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'save': 'Save',
      'delete': 'Delete',
      'edit': 'Edit',
      'create': 'Create',
      'loading': 'Loading...',
      'noData': 'No data available',
      'errorOccurred': 'An error occurred',
      'retry': 'Retry',
      'online': 'Online',
      'offline': 'Offline',
      'degraded': 'Degraded',
      'maintenance': 'Maintenance',
      'unknown': 'Unknown',
      'critical': 'Critical',
      'high': 'High',
      'medium': 'Medium',
      'low': 'Low',
      'info': 'Info',
      'deviceName': 'Device Name',
      'ipAddress': 'IP Address',
      'macAddress': 'MAC Address',
      'deviceType': 'Device Type',
      'status': 'Status',
      'lastSeen': 'Last Seen',
      'uptime': 'Uptime',
      'interfaces': 'Interfaces',
      'traffic': 'Traffic',
      'bandwidth': 'Bandwidth',
      'latency': 'Latency',
      'packetLoss': 'Packet Loss',
      'cpuUsage': 'CPU Usage',
      'memoryUsage': 'Memory Usage',
      'diskUsage': 'Disk Usage',
      'temperature': 'Temperature',
      'networkMap': 'Network Map',
      'scanNetwork': 'Scan Network',
      'scanResults': 'Scan Results',
      'acknowledgeAlert': 'Acknowledge',
      'resolveAlert': 'Resolve',
      'alertDetails': 'Alert Details',
      'alertHistory': 'Alert History',
      'darkMode': 'Dark Mode',
      'lightMode': 'Light Mode',
      'systemMode': 'System Mode',
      'language': 'Language',
      'about': 'About',
      'version': 'Version',
      'help': 'Help',
    },
    'es': {
      'appName': 'NMS Hospital',
      'dashboard': 'Panel Principal',
      'devices': 'Dispositivos',
      'alerts': 'Alertas',
      'network': 'Red',
      'settings': 'Configuración',
      'auditLog': 'Registro de Auditoría',
      'users': 'Usuarios',
      'login': 'Iniciar Sesión',
      'logout': 'Cerrar Sesión',
      'username': 'Nombre de Usuario',
      'password': 'Contraseña',
      'forgotPassword': 'Olvidé mi Contraseña',
      'rememberMe': 'Recordarme',
      'search': 'Buscar',
      'filter': 'Filtrar',
      'apply': 'Aplicar',
      'cancel': 'Cancelar',
      'confirm': 'Confirmar',
      'save': 'Guardar',
      'delete': 'Eliminar',
      'edit': 'Editar',
      'create': 'Crear',
      'loading': 'Cargando...',
      'noData': 'Sin datos disponibles',
      'errorOccurred': 'Ocurrió un error',
      'retry': 'Reintentar',
      'online': 'En Línea',
      'offline': 'Fuera de Línea',
      'degraded': 'Degradado',
      'maintenance': 'Mantenimiento',
      'unknown': 'Desconocido',
      'critical': 'Crítico',
      'high': 'Alto',
      'medium': 'Medio',
      'low': 'Bajo',
      'info': 'Información',
      'deviceName': 'Nombre del Dispositivo',
      'ipAddress': 'Dirección IP',
      'macAddress': 'Dirección MAC',
      'deviceType': 'Tipo de Dispositivo',
      'status': 'Estado',
      'lastSeen': 'Última Vista',
      'uptime': 'Tiempo Activo',
      'interfaces': 'Interfaces',
      'traffic': 'Tráfico',
      'bandwidth': 'Ancho de Banda',
      'latency': 'Latencia',
      'packetLoss': 'Pérdida de Paquetes',
      'cpuUsage': 'Uso de CPU',
      'memoryUsage': 'Uso de Memoria',
      'diskUsage': 'Uso de Disco',
      'temperature': 'Temperatura',
      'networkMap': 'Mapa de Red',
      'scanNetwork': 'Escanear Red',
      'scanResults': 'Resultados de Escaneo',
      'acknowledgeAlert': 'Reconocer',
      'resolveAlert': 'Resolver',
      'alertDetails': 'Detalles de Alerta',
      'alertHistory': 'Historial de Alertas',
      'darkMode': 'Modo Oscuro',
      'lightMode': 'Modo Claro',
      'systemMode': 'Modo Sistema',
      'language': 'Idioma',
      'about': 'Acerca de',
      'version': 'Versión',
      'help': 'Ayuda',
    },
  };
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales.any(
        (l) => l.languageCode == locale.languageCode,
      );

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('en', 'US'));

  Future<void> loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(AppConstants.localeKey);
    if (value != null) {
      final parts = value.split('_');
      if (parts.length == 2) {
        state = Locale(parts[0], parts[1]);
      }
    }
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.localeKey, '${locale.languageCode}_${locale.countryCode}');
  }
}
