# 👗 Busana Prima

### Smart Digital Tailoring Experience

Busana Prima is a Flutter-based customer application developed as part of the **Busana Prima digital tailoring ecosystem**.

The application is designed to support customers throughout their tailoring journey — from exploring available products and fabrics to managing measurements, communicating with the tailor, and managing their orders.

Busana Prima works together with **BP Tailor**, a separate tailor-facing application. Both applications operate within the same ecosystem and share the same Firebase backend and database.

> 🎓 Developed as a Final Year Project at **Universiti Kebangsaan Malaysia (UKM)**.

---

## 📌 Project Overview

Traditional tailoring services often involve a combination of face-to-face communication, manual measurements, product selection, order tracking, and coordination between customers and tailors.

**Busana Prima** aims to bring these processes into a connected digital experience through a mobile application.

The system consists of two connected applications:

| Application         | Primary User | Purpose                                                                            |
| ------------------- | ------------ | ---------------------------------------------------------------------------------- |
| 👗 **Busana Prima** | Customer     | Browse services, manage measurements, place orders and communicate with the tailor |
| 🧵 **BP Tailor**    | Tailor       | Manage customers, products, orders and tailoring operations                        |

Although the applications are maintained in separate GitHub repositories, they are part of the same **Busana Prima ecosystem** and use a shared Firebase backend/database.

🔗 **Related Repository:** [BP Tailor](https://github.com/panabijak/BP-Tailor)

---

## 🎯 Problem

Traditional tailoring workflows can involve several disconnected processes.

Customers may need to:

* communicate requirements through different channels
* provide or record measurements manually
* browse available designs and fabrics separately
* repeatedly provide their measurements
* communicate order changes directly with the tailor
* manually follow up on order progress

From the tailor's perspective, customer information, orders and tailoring progress also need to be coordinated efficiently.

This creates an opportunity for a connected digital platform that supports both sides of the tailoring workflow.

---

## 💡 Solution

Busana Prima provides a centralized customer-facing mobile application for interacting with a tailoring service.

The application combines customer-oriented functionality with supporting technologies such as:

* 📱 Cross-platform mobile development
* 🔐 Firebase authentication
* ☁️ Cloud-based data storage
* 📏 Camera-based body measurement assistance
* 🤳 Pose detection
* 🧍 Body segmentation
* 👗 2D AR clothing visualization
* 💬 Customer–tailor communication
* 🔔 Notifications
* 📦 Digital order management

The customer application communicates with the same backend used by **BP Tailor**, allowing customer-side activities and tailor-side operations to remain connected.

---

# ✨ Key Features

## 👗 Product & Fabric Browsing

Customers can explore available tailoring products and view relevant product information.

The application supports product imagery and cloud-based product data, allowing available tailoring options to be presented within the application.

---

## 📏 Body Measurement Assistance

Busana Prima incorporates camera-based body measurement assistance using **Google ML Kit Pose Detection**.

The measurement workflow includes camera capture and body landmark detection to support the estimation of body measurements.

Supporting technologies in the implementation include:

* Google ML Kit Pose Detection
* Google ML Kit Selfie Segmentation
* Camera
* Sensors
* Image processing
* Vector mathematics

---

## 🤳 2D AR Visualization

The application includes a **2D AR visualization** concept for helping customers visualize selected clothing designs through the camera.

Rather than implementing a full 3D AR fitting system, the project focuses on a lightweight 2D approach suitable for the application's scope.

---

## 🛒 Order Management

The customer application supports the customer-side ordering workflow, including product selection and order-related information.

The order workflow is designed to connect with the tailor-side operations managed through **BP Tailor**.

---

## 📏 Saved Measurements

Customer measurements can be retained for use in future interactions and orders, reducing the need to repeatedly provide measurement information.

---

## 💬 Customer–Tailor Communication

The application supports communication between customers and the tailor.

The project also integrates **ZEGOCLOUD** functionality for real-time communication features.

---

## 🔔 Notifications

Firebase Cloud Messaging is integrated to support application notifications and updates.

---

## 🔐 Authentication

The application uses Firebase Authentication for user authentication.

Google Sign-In is also included in the project's dependencies.

---

# 🏗️ System Architecture

Busana Prima is designed as the **customer-facing application** within a two-application ecosystem.

```text
                         BUSANA PRIMA ECOSYSTEM

       CUSTOMER SIDE                              TAILOR SIDE
            │                                         │
            ▼                                         ▼
 ┌─────────────────────┐                   ┌─────────────────────┐
 │    Busana Prima     │                   │      BP Tailor      │
 │   Customer App      │                   │   Tailor App        │
 │                     │                   │                     │
 │ • Products          │                   │ • Orders            │
 │ • Measurements      │                   │ • Customers         │
 │ • 2D AR             │                   │ • Products          │
 │ • Orders            │                   │ • Workflow          │
 │ • Communication     │                   │ • Communication     │
 └──────────┬──────────┘                   └──────────┬──────────┘
            │                                         │
            └────────────────┬────────────────────────┘
                             │
                             ▼
                 ┌─────────────────────────┐
                 │     Firebase Backend    │
                 │                         │
                 │ • Authentication        │
                 │ • Cloud Firestore       │
                 │ • Firebase Storage      │
                 │ • Cloud Messaging       │
                 │ • Cloud Functions*      │
                 └─────────────────────────┘

```

### Architecture Concept

The system separates the two user roles into different applications while keeping their data connected through a shared backend.

This approach allows each application to provide a focused experience:

* **Busana Prima → Customer experience**
* **BP Tailor → Tailor operations**

---

# 🛠️ Tech Stack

## Mobile Development

* **Flutter**
* **Dart**
* **Riverpod**
* **GoRouter**

## Backend & Cloud

* **Firebase Authentication**
* **Cloud Firestore**
* **Firebase Storage**
* **Firebase Cloud Messaging**

## Computer Vision & Camera

* **Google ML Kit Pose Detection**
* **Google ML Kit Selfie Segmentation**
* Flutter Camera
* Image Processing
* Sensors Plus
* Vector Math

## Communication

* **ZEGOCLOUD**
* Zego UIKit Prebuilt Call

## UI & Supporting Packages

* Google Fonts
* Flutter SVG
* Cached Network Image
* Flutter Animate
* Shimmer
* Flutter Local Notifications
* Shared Preferences
* Secure Storage

---

# 📱 Screenshots and short video

### 🏠 Home & Product Discovery

<img width="280" alt="Home bp" src="https://github.com/user-attachments/assets/d65042af-a343-4187-91c9-f736867a35ad" />


### 👗 Product Details

<p align="center">
  <img src="https://github.com/user-attachments/assets/f2964948-671a-4d74-acfc-7272835e1471" alt="Front image measurement" width="280"/>
  <img src="https://github.com/user-attachments/assets/cf06d285-5bd7-4772-9d2e-1261b08f0541" alt="Side image measurement" width="280"/>
</p>

### 📏 Body Measurement

<p align="center">
  <img src="https://github.com/user-attachments/assets/2a144ed2-22c8-4dfe-bbe3-b2bf4f0dba07" alt="Front image measurement" width="280"/>
  <img src="https://github.com/user-attachments/assets/a353fc56-39bd-4d25-b827-9c89518b7dc4" alt="Side image measurement" width="280"/>
</p>

<p align="center">
  <img src="https://github.com/user-attachments/assets/3b173956-0103-4d0a-a773-2f59403ef45b" alt="Measurement extraction result" width="280"/>
  <img src="https://github.com/user-attachments/assets/e9cc8971-121d-4d13-9a49-2e79f39aba27" alt="Save measurement" width="280"/>
</p>

### 🤳 2D AR Visualization

<p align="center">
  <img src="https://github.com/user-attachments/assets/9b8b2faa-31ab-4e57-9f2b-f8df9ec5ada8" alt="AR try on look2" width="280"/>
  <img src="https://github.com/user-attachments/assets/e3c0b0fd-ebb8-4491-8feb-bda60d36f03c" alt="AR try on look1" width="280"/>
</p>

### 🛒 Order

https://github.com/user-attachments/assets/5b315156-7f6a-4c12-ad6a-a706ddeaf1c6


https://github.com/user-attachments/assets/22ebb316-293a-4cd3-8a38-20e7c616ea19


### 💬 Communication

https://github.com/user-attachments/assets/f49c33e9-a28a-452a-b8a3-b7cf75c76d2d

---

# ⚙️ Installation & Setup

## Prerequisites

Before running the project, make sure you have:

* Flutter SDK
* Dart SDK
* Android Studio or VS Code
* Android SDK / emulator or a physical device
* Firebase project configuration

The project currently targets Dart SDK `^3.11.0`.

---

## 1. Clone the Repository

```bash
git clone https://github.com/panabijak/Busana-Prima.git

cd Busana-Prima
```

## 2. Install Dependencies

```bash
flutter pub get
```

## 3. Configure Firebase

Configure the project with the appropriate Firebase configuration for your development environment.

Do **not** commit private credentials, API keys, `.env` files, or other sensitive configuration to the repository.

## 4. Run the Application

```bash
flutter run
```

---

# 📂 Project Structure

The project follows a Flutter-based structure with dedicated areas for application logic, UI, assets, Firebase functionality and platform configuration.

```text
Busana-Prima/
│
├── android/
├── ios/
├── linux/
├── macos/
├── web/
├── windows/
│
├── assets/
│   ├── images/
│   ├── icons/
│   └── fonts/
│
├── docs/
│
├── functions/
│
├── lib/
│
├── test/
│
├── firebase.json
├── firestore.indexes.json
├── firestore.rules
├── pubspec.yaml
└── README.md
```

---

# 👩🏻‍💻 My Contribution

I contributed to the design and development of the **Busana Prima customer application** as part of my Final Year Project.

My contribution included work across both application functionality and technical implementation, including:

* Flutter mobile application development
* UI and user-flow implementation
* Firebase integration
* Authentication
* Product and fabric presentation
* Customer order workflow
* Customer measurement functionality
* Google ML Kit Pose Detection integration
* Body segmentation functionality
* 2D AR visualization
* Saved measurement functionality
* Customer–tailor communication
* Notification integration
* Application testing and debugging
* Integration with the shared Busana Prima ecosystem

The project also required coordination between the **customer application and BP Tailor application**, which use separate repositories but operate using the same backend/database.

---

# 🔗 Related Repository

## 🧵 BP Tailor

**BP Tailor** is the tailor-facing application within the Busana Prima ecosystem.

It is maintained separately so that the customer and tailor applications can provide different interfaces and workflows while remaining connected through the shared backend.

👉 **[View BP Tailor Repository](https://github.com/panabijak/BP-Tailor)**

---

# 🎓 Project Context

This project was developed as part of my **Final Year Project at Universiti Kebangsaan Malaysia (UKM)**.

The project explores how mobile technology, computer vision and 2D AR visualization can be combined with a digital tailoring workflow to support interactions between customers and a tailor.

---

# 🚧 Project Status

**Status: Completed Final Year Project**

The repository represents the implementation developed for the project's academic scope.

Future improvements may include further refinement of the measurement algorithm, AR visualization accuracy, production deployment, and additional tailoring workflow automation.

---

## 👩🏻‍💻 Developer

**Siti Farhana Binti Marzuki**

Software Engineering Student
Universiti Kebangsaan Malaysia (UKM)

[GitHub](https://github.com/panabijak)
