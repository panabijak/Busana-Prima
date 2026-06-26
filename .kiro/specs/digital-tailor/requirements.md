# Requirements Document: Digital Tailor

## Introduction

The Digital Tailor module enables customers of the Busana Prima app to capture their body measurements using the device camera and MediaPipe Pose detection. The system guides users through a structured scanning process (front and side photos), extracts 33+ pose landmarks, and applies anthropometric formulas to derive 90+ tailoring measurements (Bahu, Dada, Pinggang, etc.). Results are stored in Firestore under the user's profile for use in tailoring bookings.

**Business Goals**:
1. Eliminate the need for in-person measurement sessions for standard garments
2. Provide accurate, repeatable digital measurements using smartphone cameras
3. Reduce measurement errors through device orientation validation
4. Support the Indonesian tailoring workflow with culturally appropriate measurement names

**Success Metrics**:
- 90%+ of customers complete the scanning flow without abandoning
- Measurement deviation within ±2 cm compared to manual tape measurements
- Average scanning session completes in under 3 minutes
- 95%+ of scans produce valid landmark detection on first attempt

## Glossary

- **Digital_Tailor_Module**: The application feature responsible for guiding users through body scanning, extracting pose landmarks, computing anthropometric measurements, and persisting results to Firestore
- **Scanner_UI**: The camera-based interface that displays the live viewfinder, silhouette overlay, and leveling indicator during the scanning process
- **Leveling_System**: The component that reads device accelerometer data and determines whether the phone is held at exactly 90° vertical orientation
- **Pose_Detector**: The component that uses the google_mlkit_pose_detection package to identify 33+ body landmarks from captured images
- **Measurement_Calculator**: The component that applies anthropometric formulas (including ellipse circumference approximation) to convert 2D landmark coordinates into real-world body measurements
- **Silhouette_Overlay**: A visual guide displayed on the camera viewfinder showing the expected body outline for correct positioning
- **Landmark**: A specific anatomical point on the human body identified by MediaPipe Pose (e.g., left shoulder, right hip, nose)
- **Ellipse_Circumference_Formula**: The Ramanujan approximation formula used to estimate circumference from front-width and side-depth: C ≈ π × (3(a+b) - √((3a+b)(a+3b))) where a = front half-width, b = side half-depth
- **Measurement_Profile**: The section of the user profile screen that displays stored measurement data or prompts the user to begin scanning
- **Reference_Object**: A known-size object (e.g., A4 paper or credit card) used for pixel-to-centimeter calibration
- **Anthropometric_Measurement**: A body dimension relevant to garment construction (e.g., Bahu/shoulder width, Dada/chest circumference, Pinggang/waist circumference)

## Requirements

### Requirement 1: Measurement Profile Display

**User Story:** As a customer, I want to see my stored body measurements in my profile, so that I can verify my data before placing a tailoring order.

#### Acceptance Criteria

1. WHEN the user navigates to the profile screen AND the `measurementData` map in Firestore is empty, THE Measurement_Profile SHALL display a "Mulai Scanning Digital" (Start Digital Scanning) call-to-action button
2. WHEN the user navigates to the profile screen AND the `measurementData` map in Firestore contains data, THE Measurement_Profile SHALL display a scrollable list of all stored measurements with their Indonesian names and values shown in both centimeters and inches, each rounded to 1 decimal place
3. WHEN the user taps the "Mulai Scanning Digital" call-to-action, THE Digital_Tailor_Module SHALL navigate the user to the Scanner_UI
4. WHEN the user has existing measurement data, THE Measurement_Profile SHALL display the date and time of the last scan session formatted as "dd MMM yyyy, HH:mm" using the device locale
5. WHEN the user has existing measurement data, THE Measurement_Profile SHALL provide a "Scan Ulang" (Re-scan) button that, upon tap, presents a confirmation dialog before initiating a new scanning session that overwrites previous data
6. WHILE the Measurement_Profile is loading measurement data from Firestore, THE Measurement_Profile SHALL display a loading indicator
7. IF the Firestore stream returns an error while loading measurement data, THEN THE Measurement_Profile SHALL display an error message indicating that measurements could not be loaded and provide a retry option to re-subscribe to the stream

### Requirement 2: Device Orientation Leveling

**User Story:** As a customer, I want the app to guide me to hold my phone perfectly vertical, so that the measurement accuracy is maximized.

#### Acceptance Criteria

1. WHILE the Scanner_UI is active, THE Leveling_System SHALL read the device accelerometer sensor at a minimum rate of 30 samples per second to determine the phone's tilt angle relative to vertical (90° from horizontal)
2. WHEN the Scanner_UI first activates, THE Scanner_UI SHALL display the Silhouette_Overlay border in red color and disable the capture button until the device tilt is confirmed within the acceptable range
3. WHILE the device tilt deviates more than 5° from vertical, THE Scanner_UI SHALL display the Silhouette_Overlay border in red color and show a textual hint indicating the axis and direction of correction needed (e.g., "Miringkan ke kiri" / tilt left, "Miringkan ke depan" / tilt forward)
4. WHILE the device tilt is within 5° of vertical, THE Scanner_UI SHALL display the Silhouette_Overlay border in green color indicating readiness to capture
5. WHILE the device tilt deviates more than 5° from vertical, THE Scanner_UI SHALL disable the capture button to prevent photo capture at incorrect angles
6. WHEN the device tilt transitions from out-of-range to within-range and remains within range for at least 300 milliseconds, THE Scanner_UI SHALL enable the capture button and provide a single short haptic vibration pulse to confirm readiness
7. WHEN the device tilt transitions from within-range to out-of-range, THE Scanner_UI SHALL immediately disable the capture button and switch the Silhouette_Overlay border to red color

### Requirement 3: Silhouette Overlay and Visual Guidance

**User Story:** As a customer, I want to see a body outline on the camera screen, so that I know how to position myself correctly for the scan.

#### Acceptance Criteria

1. WHILE the Scanner_UI is in front-capture mode, THE Scanner_UI SHALL display a front-facing human silhouette outline centered on the camera viewfinder, occupying between 70% and 85% of the viewfinder height
2. WHILE the Scanner_UI is in side-capture mode, THE Scanner_UI SHALL display a side-profile human silhouette outline centered on the camera viewfinder, occupying between 70% and 85% of the viewfinder height
3. THE Silhouette_Overlay SHALL maintain its original aspect ratio while scaling to fit the camera viewfinder dimensions across different device screen sizes with a minimum supported width of 320 logical pixels
4. WHILE the Scanner_UI is in front-capture mode, THE Scanner_UI SHALL display the instruction text "Berdiri menghadap kamera, 2 meter dari kamera" (Stand facing the camera, 2 meters from camera)
5. WHILE the Scanner_UI is in side-capture mode, THE Scanner_UI SHALL display the instruction text "Berdiri menyamping, 2 meter dari kamera" (Stand sideways, 2 meters from camera)
6. THE Silhouette_Overlay SHALL be rendered as a semi-transparent outline with sufficient contrast to remain visible against the live camera feed while allowing the user to see their own body through the overlay

### Requirement 4: Photo Capture Workflow

**User Story:** As a customer, I want to capture front and side photos in a guided sequence, so that the system has the data needed to calculate all measurements.

#### Acceptance Criteria

1. WHEN the user initiates a scanning session, THE Digital_Tailor_Module SHALL guide the user through a two-step capture sequence: front photo first, then side photo, displaying a step indicator showing the current step and total steps (e.g., "1/2" or "2/2")
2. WHEN the user captures the front photo while the capture button is enabled (device leveling within valid range), THE Digital_Tailor_Module SHALL store the captured image and transition to the side-capture mode with updated silhouette and instructions within 2 seconds
3. WHEN the user captures both front and side photos, THE Digital_Tailor_Module SHALL proceed to the pose detection and measurement calculation phase
4. WHILE the Scanner_UI is in side-capture mode, THE Scanner_UI SHALL display a "Kembali" (Back) button that, when tapped, discards the previously captured front photo and returns the user to the front-capture mode with the camera viewfinder active
5. IF the device camera is unavailable or permission is denied, THEN THE Digital_Tailor_Module SHALL display an error message explaining that camera access is required and provide a button to open device settings
6. WHILE the scanning session is active on any capture step, THE Scanner_UI SHALL provide a close or cancel control that returns the user to the profile screen without saving any captured data

### Requirement 5: Pose Landmark Detection

**User Story:** As a customer, I want the system to automatically detect my body landmarks from the photos, so that measurements can be calculated without manual input.

#### Acceptance Criteria

1. WHEN front and side photos are captured, THE Pose_Detector SHALL process each image using the google_mlkit_pose_detection package to identify 33 body landmarks within 10 seconds per image
2. WHEN the Pose_Detector identifies all required landmarks (left/right shoulders, left/right hips, left/right elbows, left/right wrists, left/right knees, left/right ankles, nose, and neck approximation point) with a confidence score of 0.5 or higher for each, THE Pose_Detector SHALL pass the landmark coordinates to the Measurement_Calculator
3. IF the Pose_Detector fails to detect one or more required landmarks with a confidence score of 0.5 or higher from the front photo, THEN THE Digital_Tailor_Module SHALL prompt the user to retake the front photo with guidance on improving detection (better lighting, full body visible, plain background)
4. IF the Pose_Detector fails to detect one or more required landmarks with a confidence score of 0.5 or higher from the side photo, THEN THE Digital_Tailor_Module SHALL prompt the user to retake the side photo with the same guidance
5. WHILE pose detection is in progress, THE Digital_Tailor_Module SHALL display a loading indicator with the message "Menganalisis pose tubuh..." (Analyzing body pose...)
6. IF the Pose_Detector does not complete processing within 10 seconds for a single image, THEN THE Digital_Tailor_Module SHALL cancel the detection, display an error message indicating detection timed out, and prompt the user to retake the photo
7. IF the user fails pose detection retake attempts 3 consecutive times for the same photo (front or side), THEN THE Digital_Tailor_Module SHALL display a message suggesting the user try in a different environment with better lighting and more space, and provide a button to return to the profile screen

### Requirement 6: Measurement Calculation

**User Story:** As a customer, I want the system to calculate my body measurements from the detected landmarks, so that I receive accurate tailoring dimensions.

#### Acceptance Criteria

1. WHEN valid landmarks are available from both front and side photos, THE Measurement_Calculator SHALL compute the following anthropometric measurements: Bahu (shoulder width), Dada (chest circumference), Pinggang (waist circumference), Pinggul (hip circumference), Panjang Lengan (arm length), Panjang Kaki (leg length), and Lingkar Leher (neck circumference)
2. THE Measurement_Calculator SHALL use the Ellipse_Circumference_Formula to derive circumference measurements (Dada, Pinggang, Pinggul, Lingkar Leher) from front-width and side-depth landmark distances, and SHALL use linear Euclidean distance for length measurements (Bahu, Panjang Lengan, Panjang Kaki)
3. THE Measurement_Calculator SHALL require a Reference_Object or user-provided height input to establish the pixel-to-centimeter conversion ratio
4. THE Measurement_Calculator SHALL produce each measurement in both centimeters (CM) and inches (IN), using the conversion factor 1 inch = 2.54 cm, with all output values rounded to 1 decimal place
5. WHEN all measurements are calculated, THE Digital_Tailor_Module SHALL display a results screen showing all measurements grouped by body region (Atas/Upper: Bahu, Lingkar Leher; Tengah/Middle: Dada, Pinggang, Pinggul, Panjang Lengan; Bawah/Lower: Panjang Kaki)
6. THE Measurement_Calculator SHALL ensure that calculating in CM then converting to inches produces the same result as calculating directly in inches, within a tolerance of 0.1 units after rounding
7. IF the Measurement_Calculator cannot compute one or more individual measurements due to insufficient or low-confidence landmarks for that body region, THEN THE Measurement_Calculator SHALL mark those specific measurements as unavailable, compute all remaining measurements, and indicate to the user which measurements could not be determined

### Requirement 7: Measurement Results and Confirmation

**User Story:** As a customer, I want to review my calculated measurements before saving, so that I can verify the results look reasonable.

#### Acceptance Criteria

1. WHEN the measurement calculation completes, THE Digital_Tailor_Module SHALL display all calculated measurements in a reviewable list with Indonesian measurement names and dual-unit values (CM and inches)
2. WHEN the measurement calculation completes, THE Digital_Tailor_Module SHALL highlight any measurement whose value falls outside the defined physiological range for that measurement (e.g., Pinggang/waist: 40–200 cm, Bahu/shoulder: 20–70 cm, Dada/chest: 50–180 cm, Pinggul/hip: 50–180 cm, Lingkar Leher/neck: 20–60 cm) with a visible warning indicator adjacent to the flagged measurement
3. WHEN the user taps "Simpan" (Save), THE Digital_Tailor_Module SHALL persist all measurements to Firestore under the user's profile document
4. WHEN the user taps "Scan Ulang" (Re-scan) on the results screen, THE Digital_Tailor_Module SHALL discard the current results and restart the scanning session from the front-capture step
5. THE Digital_Tailor_Module SHALL display a confidence indicator labeled "Tinggi" (High) when the average landmark detection confidence score across both photos is 0.8 or above, "Sedang" (Medium) when the score is 0.6 or above but below 0.8, and "Rendah" (Low) when the score is below 0.6
6. WHILE the results screen is displayed, THE Digital_Tailor_Module SHALL disable the "Simpan" (Save) button until the user has scrolled through or viewed the complete measurement list for at least 2 seconds

### Requirement 8: Firestore Persistence

**User Story:** As a customer, I want my measurements saved to my profile automatically, so that they are available when I place a tailoring order.

#### Acceptance Criteria

1. WHEN the user confirms saving measurements, THE Digital_Tailor_Module SHALL write all measurement values atomically to the `measurement_data` map field in the user's Firestore document in the `users` collection, such that either all measurements are saved or none are saved
2. THE Digital_Tailor_Module SHALL store each measurement as a nested map containing `value_cm` (double, rounded to 1 decimal place), `value_inch` (double, rounded to 1 decimal place), and `label` (String, Indonesian name, maximum 50 characters) fields
3. THE Digital_Tailor_Module SHALL store metadata including `scanned_at` (Timestamp), `confidence_score` (double, range 0.0 to 1.0), and `scan_version` (String) as fields within the `measurement_data` map alongside the individual measurement entries
4. WHILE the Firestore write is in progress, THE Digital_Tailor_Module SHALL display a loading indicator and disable the save button to prevent duplicate submissions
5. WHEN the Firestore write completes successfully, THE Digital_Tailor_Module SHALL navigate the user back to the profile screen where the updated measurements are displayed via the existing StreamProvider
6. IF the Firestore write fails due to network error or permission issue, THEN THE Digital_Tailor_Module SHALL retain the calculated measurements in memory, display an error message indicating the save failed, and provide a "Coba Lagi" (Retry) button
7. IF the Firestore write does not complete within 15 seconds, THEN THE Digital_Tailor_Module SHALL treat the operation as failed and display the same error state with the "Coba Lagi" (Retry) button
8. IF the user has attempted retry 3 times without success, THEN THE Digital_Tailor_Module SHALL continue displaying the retry option and additionally offer a "Kembali" (Back) button to return to the profile screen without saving

### Requirement 9: Calibration via Reference Input

**User Story:** As a customer, I want to provide my height or use a reference object so that the system can convert pixel distances to real-world measurements accurately.

#### Acceptance Criteria

1. WHEN the scanning session begins, THE Digital_Tailor_Module SHALL prompt the user to enter their height in centimeters (whole numbers only) as the primary calibration method
2. IF the user enters a height value outside the range of 100 cm to 250 cm, THEN THE Digital_Tailor_Module SHALL display an error message indicating the acceptable range and prevent the user from proceeding until a valid height is entered or the alternative calibration method is selected
3. WHEN the user provides a valid height, THE Measurement_Calculator SHALL use the ratio between the detected full-body landmark height (vertical pixel distance from the top-of-head landmark to the ankle midpoint landmark) and the user-provided height (in cm) to establish the pixel-to-centimeter conversion factor
4. IF the user does not provide height input, THEN THE Digital_Tailor_Module SHALL offer an alternative calibration method using a Reference_Object (A4 paper held at waist level) visible in the photo, using the longer dimension (29.7 cm) of the detected paper rectangle as the reference length
5. IF the user selects the Reference_Object calibration method AND the system cannot detect the A4 paper edges in the captured photo, THEN THE Digital_Tailor_Module SHALL display an error message instructing the user to ensure the full A4 paper is visible against a contrasting background and prompt a retake
6. THE Measurement_Calculator SHALL compute the calibration factor once from the front photo and apply that single factor to all landmark distance calculations for both front and side photos within the same scan session

### Requirement 10: Error Handling and Recovery

**User Story:** As a customer, I want clear error messages and recovery options when something goes wrong during scanning, so that I can complete the process without frustration.

#### Acceptance Criteria

1. IF the device does not have an accelerometer sensor, THEN THE Digital_Tailor_Module SHALL skip the leveling validation, allow capture without orientation checking, and display a persistent non-blocking warning indicating that measurement accuracy may be reduced due to the absence of orientation validation
2. IF the google_mlkit_pose_detection package fails to initialize, THEN THE Digital_Tailor_Module SHALL display an error message indicating the feature is unavailable on the current device and suggest updating the app or trying a different device
3. IF the Pose_Detector returns a confidence score below 0.5 for any required landmark due to poor lighting conditions, THEN THE Digital_Tailor_Module SHALL inform the user that the image is too dark or too bright for reliable detection and prompt a retake before proceeding
4. WHEN any error occurs during the scanning flow, THE Digital_Tailor_Module SHALL provide a navigation option to return to the profile screen without losing previously saved measurement data in Firestore
5. IF the measurement calculation produces values outside physiological ranges (e.g., waist circumference below 40 cm or above 200 cm, shoulder width below 20 cm or above 80 cm, height below 100 cm or above 250 cm), THEN THE Measurement_Calculator SHALL flag those specific measurements with a visible warning indicator on the results screen rather than discarding the entire scan
6. IF the Pose_Detector does not return a result within 30 seconds of processing initiation, THEN THE Digital_Tailor_Module SHALL cancel the operation, display an error message indicating that pose analysis timed out, and offer the user the option to retake the photo or return to the profile screen
