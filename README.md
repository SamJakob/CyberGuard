# CyberGuard
_Helping Users to Help Themselves to Cyber Security_

A protected, mobile, account manager that enables 

## Directory Structure
- [`lib/`](./lib)
  - [`const/`](./lib/const) - Compile-time settings for application (configuration)
  - [`domain/`](./lib/domain) - Application domain code (essentially, business logic)
    - [`data/`](./lib/domain/data) - Data layer - generally intended for use by services layer - might request data from REST APIs, or local filesystem, for example.
    - [`services/`](./lib/domain/services) - Classes that uniformly expose specialized features.
    - [`struct/`](./lib/domain/struct) - Classes that represent individual models (entities) within the system.
  - [`interface/`](./lib/interface) - All user-interface related code.
    - [`components/`](./lib/interface/components) - Non-application specific custom components (widgets, generalized such that they may be copied between applications).
    - [`partials/`](./lib/interface/partials) - Application-specific 'parts' that may be re-used across the app for greater consistency (widgets that achieve some application-specific goal or interact with application-specific data).
    - [`screens/`](./lib/interface/screens) - Widgets that implement an entire screen that will be pushed onto the navigation stack (and may render nested widgets).
  - [`app.dart`](./lib/app.dart) - Root-level definition of the MaterialApp. Contains core application configuration.
  - [`main.dart`](./lib/main.dart) - The main entry point of the application.
