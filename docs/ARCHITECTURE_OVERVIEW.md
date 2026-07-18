# Hospital NMS - Architecture Overview

## System Architecture

```
┌─────────────────────────────────────────────────────┐
│                  Flutter Desktop (Win)              │
│  ┌───────────────────────────────────────────────┐  │
│  │           Presentation Layer                  │  │
│  │  Screens  |  Widgets  |  Providers  |  Router │  │
│  └──────────────────────┬────────────────────────┘  │
│  ┌──────────────────────┴────────────────────────┐  │
│  │             Domain Layer                      │  │
│  │  Entities  |  Use Cases  |  Repository Intf.  │  │
│  └──────────────────────┬────────────────────────┘  │
│  ┌──────────────────────┴────────────────────────┐  │
│  │              Data Layer                       │  │
│  │  Models  |  Datasources  |  Repository Impl.  │  │
│  └──────────────────────┬────────────────────────┘  │
│  ┌──────────────────────┴────────────────────────┐  │
│  │              Core Layer                       │  │
│  │  DI  |  Network  |  Errors  |  Theme  |  L10n │  │
│  └───────────────────────────────────────────────┘  │
└──────────────────────┬──────────────────────────────┘
                       │ REST + WebSocket
┌──────────────────────┴──────────────────────────────┐
│              Go Backend (Gin Framework)              │
│  ┌───────────────────────────────────────────────┐  │
│  │  Handlers  |  Services  |  Repository  |  DB  │  │
│  └───────────────────────────────────────────────┘  │
└──────────────────────┬──────────────────────────────┘
                       │
┌──────────────────────┴──────────────────────────────┐
│              PostgreSQL + TimescaleDB                │
└─────────────────────────────────────────────────────┘
```

## Clean Architecture Layers

### Presentation Layer
- **Screens**: Organized by feature (auth, devices, alerts, network, settings, audit)
- **Widgets**: Reusable UI components (common + layout)
- **Providers**: Riverpod state management (feature-based)
- **Router**: Go Router with shell routes for authenticated layout

### Domain Layer
- **Entities**: Core business objects (Device, Alert, User, NetworkScan, AuditLog)
- **Use Cases**: Single-responsibility business operations
- **Repository Interfaces**: Abstract contracts for data access

### Data Layer
- **Models**: JSON-serializable DTOs with `fromEntity`/`toEntity` mapping
- **Datasources**: Remote (API) and Local (cache) data sources
- **Repository Implementations**: Bridge between domain and datasources

### Core Layer
- **Config**: Environment-based configuration (dev/staging/prod)
- **Network**: Dio client, interceptors (auth, logging, retry), WebSocket
- **Errors**: Failure/Exception hierarchy with centralized error handler
- **Theme**: Dark/Light/System theme with Material 3
- **Localization**: English/Spanish with ARB files
- **Security**: JWT management, secure storage
- **DI**: Dependency injection container (Riverpod providers)
- **Utils**: Logger, validators, date formatters

## Key Design Decisions

1. **State Management**: Riverpod for compile-safe, testable dependency injection and state management
2. **Functional Error Handling**: dartz `Either<Failure, Success>` pattern for explicit error propagation
3. **Offline-First**: Local caching with SharedPreferences for devices, capability-based UI
4. **Real-Time Updates**: WebSocket for live alerts, metrics, and scan progress
5. **Security**: JWT with automatic refresh, encrypted storage, correlation IDs
6. **Performance**: TimescaleDB hypertables for metrics, pagination, query optimization

## Application Lifecycle

```
App Start
  ↓
WidgetsFlutterBinding.ensureInitialized()
  ↓
BuildConfig.initialize(environment)
  ↓
Window Manager Configuration
  ↓
ProviderScope (Riverpod)
  ↓
  ├── SharedPreferences initialized
  ├── Theme preference loaded
  ├── Locale preference loaded
  └── Auth state checked
  ↓
MaterialApp.router (GoRouter)
  ↓
Splash Screen → Auth Check
  ├── Authenticated → Dashboard
  └── Unauthenticated → Login
```
