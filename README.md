# Travel Route Optimizer

Travel Route Optimizer is a cross-platform mobile application built with Flutter for planning and optimizing multi-day travel routes.

The project focuses on generating efficient travel itineraries based on multiple locations, route distances, user preferences and trip constraints.

## Features

- Add multiple travel destinations
- Create multi-day trip plans
- Optimize route order between locations
- Calculate route distances using OSRM
- Generate distance matrices for multiple destinations
- Support multi-criteria route planning
- Track trip budget information
- Create and manage travel itineraries
- Cross-platform mobile interface with Flutter

## Tech Stack

### Mobile
- Flutter
- Dart
- BLoC / Cubit
- Dio
- REST APIs

### Backend
- Python
- FastAPI
- OSRM
- Route optimization algorithms

## Architecture

The application separates the mobile client and backend service.

The Flutter application is responsible for:

- User interface
- State management
- Trip and destination management
- API communication
- Displaying optimized routes

The backend is responsible for:

- Distance matrix generation
- Route calculations
- Multi-criteria optimization
- Itinerary generation

Backend repository:

[travel-route-optimizer-backend](https://github.com/hasancan2004/travel-route-optimizer-backend)

## Route Optimization

The optimization process uses distance information between selected destinations to determine a more efficient visit order.

OSRM is used to generate real road distances between locations instead of relying only on straight-line distance.

The generated distance matrix is then used by the route optimization logic to calculate the itinerary.

## Project Structure

```text
lib/
├── core/
├── data/
├── features/
├── models/
├── services/
└── presentation/
