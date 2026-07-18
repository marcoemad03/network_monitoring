enum Environment {
  development('development', 'dev'),
  staging('staging', 'stg'),
  production('production', 'prod');

  final String name;
  final String shortName;

  const Environment(this.name, this.shortName);

  bool get isDevelopment => this == Environment.development;
  bool get isStaging => this == Environment.staging;
  bool get isProduction => this == Environment.production;
}
