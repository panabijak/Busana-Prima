# Requirements Document: Fashion Try-On & Booking MVP

## Introduction

This document specifies the requirements for the Busana Prima MVP - a fashion try-on and booking platform for small tailor businesses. The system enables customers to virtually try on clothing using 2D-overlay AR, get body measurements via Mediapipe, and book tailoring appointments, while providing a Tailor Dashboard for order management.

**Business Goals**:
1. Enable Kak Dah to accept digital measurements and bookings
2. Reduce in-person measurement appointments by 50%
3. Increase booking conversion through virtual try-on
4. Streamline order management for single tailor operation

**Success Metrics**:
- 20+ bookings in first month
- 80%+ measurement accuracy satisfaction
- < 5 minute average booking completion time
- 90%+ tailor dashboard usability satisfaction

## Requirements

## Functional Requirements

### FR1: User Authentication & Profiles

**ID**: FR1.0  
**Description**: Users can register, login, and manage profiles with role-based access via Firebase Authentication  
**Priority**: High  

**User Story:** As a user, I want to register and login to the application with my email and password, so that I can access personalized features and maintain my session securely.

#### Acceptance Criteria

1. WHEN a new user submits a valid email and password on the registration screen, THE Authentication_Service SHALL create a new Firebase Authentication account and assign the "customer" role by default
2. WHEN a registered user submits valid credentials on the login screen, THE Authentication_Service SHALL authenticate the user via Firebase Authentication and establish a persistent session
3. WHILE a user session is active, THE Authentication_Service SHALL maintain the session token and automatically refresh it before expiration
4. WHEN a user navigates to the profile screen, THE Profile_Service SHALL display the user's editable profile information including display name and email
5. WHEN a user updates their profile information and saves, THE Profile_Service SHALL persist the changes to Firebase and confirm the update to the user
6. WHEN a user with the "tailor" role logs in, THE Authentication_Service SHALL grant access to the Tailor Dashboard and admin booking management features
7. WHEN a user with the "customer" role attempts to access tailor-restricted features, THE Authentication_Service SHALL deny access and display an unauthorized message
8. IF Firebase Authentication returns an error during registration, THEN THE Authentication_Service SHALL display a descriptive error message to the user (e.g., email already in use, weak password, invalid email format)
9. IF Firebase Authentication returns an error during login, THEN THE Authentication_Service SHALL display a descriptive error message to the user (e.g., invalid credentials, account disabled, network error)
10. IF the user session expires or becomes invalid, THEN THE Authentication_Service SHALL redirect the user to the login screen and clear local session data

**Dependencies**: Firebase Authentication, Firebase Firestore (for role storage)

### FR2: Clothing Catalog Browsing

**ID**: FR2.0  
**Description**: Customers can browse available clothing items  
**Priority**: High  
**Acceptance Criteria**:
- Display clothing items with images, descriptions, and prices
- Filter by clothing type (shirt, pants, dress, etc.)
- View item details including estimated production time
- Mark items as available/unavailable (tailor only)

**Dependencies**: Firebase Firestore for catalog data

### FR3: Body Measurement Capture

**ID**: FR3.0  
**Description**: System captures body measurements using device camera  
**Priority**: High  
**Acceptance Criteria**:
- Uses device camera to capture front-facing body image
- Processes image with Mediapipe to detect pose landmarks
- Extracts key measurements: chest, waist, hips, shoulder width, arm length, leg length, height
- Displays measurement confidence score (≥ 0.5 required)
- Allows retake if confidence is low

**Dependencies**: Mediapipe Flutter plugin, device camera

### FR4: Virtual Try-On (2D Overlay)

**ID**: FR4.0  
**Description**: Customers can virtually try on selected clothing  
**Priority**: Medium  
**Acceptance Criteria**:
- Overlays 2D clothing image on body image
- Scales clothing based on body measurements
- Adjusts positioning for different clothing types
- Shows try-on result with adjustable opacity
- Allows saving try-on image

**Dependencies**: Image processing libraries, clothing images

### FR5: Booking Creation & Management

**ID**: FR5.0  
**Description**: Customers can create and manage tailoring bookings  
**Priority**: High  
**Acceptance Criteria**:
- Create booking with selected clothing item and measurements
- Select preferred appointment date (future dates only)
- Add custom notes/requests for tailor
- View booking status (pending, confirmed, in progress, ready, completed, cancelled)
- Cancel bookings before confirmation

**Dependencies**: Firebase Firestore, Booking workflow logic

### FR6: Tailor Dashboard

**ID**: FR6.0  
**Description**: Tailor can manage all bookings and operations  
**Priority**: High  
**Acceptance Criteria**:
- View all bookings with filtering by status
- Update booking status following workflow rules
- View customer measurements and try-on images
- Add tailor notes and final pricing
- View dashboard statistics (pending bookings, weekly revenue)
- Manage work schedule/availability

**Dependencies**: Firebase Firestore, Admin authentication

### FR7: Notifications

**ID**: FR7.0  
**Description**: System sends notifications for important events  
**Priority**: Medium  
**Acceptance Criteria**:
- Customers notified when booking status changes
- Tailor notified of new bookings
- Reminder notifications for upcoming appointments
- Offline notification queue with retry logic

**Dependencies**: Firebase Cloud Messaging, local notifications

## Non-Functional Requirements

### NFR1: Performance

**ID**: NFR1.0  
**Description**: Application performance requirements  
**Metrics**:
- App launch time: < 3 seconds
- Measurement processing: < 10 seconds per image
- Image overlay: < 5 seconds
- UI responsiveness: 60 FPS for animations
- Offline operation: Basic functionality without network

**Priority**: High

### NFR2: Reliability & Availability

**ID**: NFR2.0  
**Description**: System reliability and uptime requirements  
**Metrics**:
- Measurement accuracy: ≥ 80% compared to manual measurements
- Data persistence: 99.9% successful Firestore operations
- Error recovery: Graceful degradation for failed operations
- Offline support: Cache last 10 bookings locally

**Priority**: High

### NFR3: Security & Privacy

**ID**: NFR3.0  
**Description**: Security and data protection requirements  
**Requirements**:
- Body images processed locally when possible
- Measurement data encrypted at rest
- Firebase Authentication for user management
- Minimal PII collection (email, name only)
- Camera usage requires explicit user permission

**Priority**: High

### NFR4: Usability

**ID**: NFR4.0  
**Description**: User experience and accessibility requirements  
**Requirements**:
- Intuitive booking flow (< 5 steps to complete)
- Clear measurement guidance with visual aids
- Tailor dashboard usable with basic digital literacy
- Support for Indonesian language (basic)
- WCAG 2.1 AA compliance for accessibility

**Priority**: Medium

### NFR5: Cross-Platform Compatibility

**ID**: NFR5.0  
**Description**: Support for target platforms  
**Requirements**:
- iOS 13+ and Android 8+ support
- Consistent experience across platforms
- Responsive design for various screen sizes
- Flutter Web for tailor dashboard

**Priority**: High

## Technical Constraints

### TC1: Budget Constraint

**Description**: $0 budget for development and operations  
**Implications**:
- Use only open-source libraries and services
- Leverage Firebase free tier (1GB storage, 50K reads/day)
- No paid APIs or services
- Client-side processing to avoid server costs

### TC2: Timeline Constraint

**Description**: 8-week development timeline  
**Implications**:
- Prioritize core features over polish
- Accept technical debt for speed
- Simple 2D AR instead of complex 3D
- Basic UI with Flutter Material components

### TC3: Technology Stack

**Description**: Flutter-based cross-platform development  
**Implications**:
- Single codebase for iOS, Android, and Web
- Dart programming language throughout
- Flutter plugin ecosystem dependencies
- Potential performance trade-offs for web

### TC4: Measurement Accuracy

**Description**: Mediapipe-based body measurement  
**Implications**:
- "Good enough" accuracy vs professional tools
- Requires good lighting and frontal pose
- Confidence scoring to indicate reliability
- Manual measurement override option

## User Stories

### Customer User Stories

**US1: As a customer, I want to browse available clothing items so I can see what tailoring services are offered**
- **Given** I'm on the home screen
- **When** I browse the catalog
- **Then** I see clothing items with images, prices, and descriptions

**US2: As a customer, I want to measure my body using my phone camera so I don't need to visit for measurements**
- **Given** I've selected a clothing item
- **When** I follow the measurement guide and take a photo
- **Then** I get my body measurements with confidence score

**US3: As a customer, I want to see how clothing would look on me before booking so I can make better decisions**
- **Given** I have my measurements
- **When** I try on a clothing item virtually
- **Then** I see a 2D overlay of the clothing on my body image

**US4: As a customer, I want to book a tailoring appointment online so I can schedule at my convenience**
- **Given** I've selected an item and have measurements
- **When** I choose a date and add notes
- **Then** my booking is created and I get confirmation

**US5: As a customer, I want to track my booking status so I know when to expect my garment**
- **Given** I have an active booking
- **When** I check my bookings
- **Then** I see current status and any tailor notes

### Tailor User Stories

**US6: As Kak Dah (tailor), I want to see all pending bookings so I can plan my work**
- **Given** I'm logged into the dashboard
- **When** I view the bookings page
- **Then** I see all bookings sorted by status with customer details

**US7: As Kak Dah, I want to update booking status so customers know progress**
- **Given** I'm viewing a booking
- **When** I change the status and add notes
- **Then** the booking is updated and customer is notified

**US8: As Kak Dah, I want to view customer measurements so I can plan garment construction**
- **Given** I'm viewing a booking
- **When** I check the measurements tab
- **Then** I see all body measurements with confidence scores

**US9: As Kak Dah, I want to see my weekly schedule and revenue so I can manage my business**
- **Given** I'm on the dashboard
- **When** I view the summary
- **Then** I see pending bookings count and estimated revenue

## Data Requirements

### DR1: User Data
- Email address (required)
- Display name (optional)
- Profile photo (optional)
- Account creation date
- Last login date

### DR2: Measurement Data
- Customer ID (reference)
- Measurement timestamp
- Key measurements (chest, waist, hips, etc.)
- Confidence score (0.0 to 1.0)
- Original image reference (temporary)
- Notes (optional)

### DR3: Clothing Catalog Data
- Item ID
- Name and description
- Clothing type (enum)
- Image URLs (multiple)
- Base price
- Size adjustment pricing rules
- Estimated production days
- Availability status

### DR4: Booking Data
- Booking ID
- Customer ID
- Tailor ID (hardcoded to "kak_dah" for MVP)
- Clothing item ID
- Measurement data (embedded or reference)
- Dates (created, preferred, confirmed)
- Status (enum with workflow)
- Notes (customer and tailor)
- Pricing (estimated and final)

## Interface Requirements

### IR1: Mobile App Interfaces
- **Home Screen**: Catalog browsing, quick try-on
- **Measurement Screen**: Camera guide, capture, results
- **Try-On Screen**: Image overlay, adjustments, save
- **Booking Screen**: Date selection, notes, confirmation
- **Profile Screen**: User info, booking history, measurements

### IR2: Tailor Dashboard Interfaces
- **Login Screen**: Email/password authentication
- **Dashboard Home**: Summary statistics, quick actions
- **Bookings Management**: List view, filtering, status updates
- **Measurement Viewer**: Detailed measurements with visuals
- **Schedule Management**: Calendar view, availability settings

### IR3: External Interfaces
- **Firebase Authentication**: User management
- **Firebase Firestore**: Data persistence
- **Firebase Storage**: Image storage
- **Mediapipe Service**: Body measurement processing
- **Device Camera**: Image capture
- **Local Notifications**: Event alerts

## Validation Rules

### VR1: Measurement Validation
- Confidence score must be ≥ 0.5 for valid measurements
- All numeric measurements must be positive
- Measurements must be within physiological ranges (e.g., chest 30-200cm)
- Image must contain detectable human pose

### VR2: Booking Validation
- Preferred date must be in the future
- Clothing item must be available
- Measurements must be valid
- Customer must be authenticated
- Status transitions must follow defined workflow

### VR3: User Input Validation
- Email must be valid format
- Names cannot be empty or contain special characters
- Notes have maximum length of 500 characters
- Dates must be in correct format and range

## Dependencies

### External Dependencies
1. **Flutter Framework**: UI development
2. **Firebase Services**: Backend, auth, storage
3. **Mediapipe**: Body measurement ML models
4. **Device Hardware**: Camera, storage, network

### Internal Dependencies
1. **Measurement Service** depends on Mediapipe initialization
2. **Booking Service** depends on User Authentication
3. **Try-On Service** depends on Measurement Service
4. **Tailor Dashboard** depends on Booking Service

## Assumptions

### A1: User Assumptions
- Customers have smartphones with cameras
- Basic digital literacy for app usage
- Willingness to provide body measurements digitally
- Trust in "good enough" measurement accuracy

### A2: Technical Assumptions
- Firebase free tier sufficient for MVP scale
- Mediapipe works reliably on target devices
- Flutter provides adequate performance for 2D image processing
- Internet connectivity available for booking operations

### A3: Business Assumptions
- Kak Dah operates as single tailor business
- Cash-based payments (no online payment integration)
- Basic garment types sufficient for initial offering
- Market exists for digital tailoring services

## Risks & Mitigations

### R1: Measurement Accuracy Risk
- **Risk**: Mediapipe measurements insufficiently accurate for tailoring
- **Impact**: High - could result in poorly fitting garments
- **Mitigation**: Include confidence scoring, allow manual override, provide measurement guidance

### R2: User Adoption Risk
- **Risk**: Customers unwilling to use digital measurement
- **Impact**: Medium - could limit booking volume
- **Mitigation**: Clear value proposition, easy process, try-on incentive

### R3: Technical Complexity Risk
- **Risk**: 8-week timeline insufficient for complete implementation
- **Impact**: High - could miss launch deadline
- **Mitigation**: Prioritize core features, accept technical debt, simple solutions

### R4: Firebase Limits Risk
- **Risk**: Exceed Firebase free tier limits
- **Impact**: Medium - could incur costs or require migration
- **Mitigation**: Optimize queries, cache aggressively, monitor usage

## Open Issues

### OI1: Measurement Calibration
- Need to validate Mediapipe measurements against manual measurements
- May require calibration factor for local population

### OI2: Clothing Image Standards
- Need consistent photography standards for try-on overlay
- Background removal requirements for clothing images

### OI3: Offline Operation
- Extent of offline functionality needs definition
- Data synchronization strategy for intermittent connectivity

### OI4: Internationalization
- Full Indonesian language support vs basic labels
- Date/time format localization requirements

## Glossary

- **MVP**: Minimum Viable Product
- **AR**: Augmented Reality
- **Mediapipe**: Google's open-source framework for perceptual computing
- **Firebase**: Google's mobile and web application development platform
- **Firebase Authentication**: Firebase service for user identity management supporting email/password, OAuth, and session management
- **Flutter**: Google's UI toolkit for building natively compiled applications
- **2D Overlay**: Simple image compositing technique for virtual try-on
- **Body Landmarks**: Key points on human body detected by pose estimation
- **Confidence Score**: Measurement reliability indicator (0.0 to 1.0)
- **Booking Workflow**: Defined states and transitions for tailoring orders
- **Authentication_Service**: The application component responsible for user registration, login, session management, and role-based access control via Firebase Authentication
- **Profile_Service**: The application component responsible for managing user profile data (display name, email, measurement history)
- **Role-Based Access**: Access control mechanism distinguishing between "customer" and "tailor" user roles, restricting features accordingly