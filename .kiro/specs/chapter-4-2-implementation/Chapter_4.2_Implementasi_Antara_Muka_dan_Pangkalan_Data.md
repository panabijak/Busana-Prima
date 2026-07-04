# 4.2 Implementasi Antara Muka dan Pangkalan Data

## 4.2.1 Gambaran Keseluruhan Implementasi

Aplikasi Sokongan Jahitan Pintar (Busana Prima) merupakan sistem pengurusan tempahan jahitan bespoke yang dibangunkan menggunakan framework Flutter dengan Firebase sebagai platform backend. Implementasi sistem ini direka bentuk khusus untuk pasaran perniagaan jahitan tempahan di Malaysia, di mana model harga adalah dinamik berdasarkan ukuran badan pelanggan, jenis kain, dan kerumitan reka bentuk.

### Pendekatan Pembangunan

Pembangunan aplikasi ini mengguna pakai pendekatan **feature-first architecture** di mana setiap modul fungsi diasingkan mengikut domain perniagaan. Struktur folder projek distrukturkan secara sistematik di bawah direktori `lib/features/` dengan setiap modul mengandungi subdirektori tersendiri untuk `screens/`, `providers/`, `services/`, `models/`, dan `widgets/`. Pendekatan ini memudahkan penyelenggaraan kod dan membolehkan pengembangan modular pada masa hadapan.

### Teknologi dan Alat Pembangunan

Berdasarkan analisis fail `pubspec.yaml`, teknologi utama yang digunakan adalah seperti berikut:

| Komponen | Teknologi | Versi | Kegunaan |
|----------|-----------|-------|----------|
| Framework | Flutter | SDK ^3.11.0 | Pembangunan aplikasi cross-platform |
| State Management | flutter_riverpod | ^2.6.1 | Pengurusan state reaktif |
| Navigation | go_router | ^14.8.1 | Routing deklaratif dengan deep linking |
| Authentication | firebase_auth | ^5.5.4 | Pengesahan pengguna |
| Database | cloud_firestore | ^5.6.7 | Pangkalan data NoSQL real-time |
| Storage | firebase_storage | ^12.4.0 | Penyimpanan fail media |
| Messaging | firebase_messaging | ^15.0.0 | Notifikasi push |
| Camera & ML | camera, google_mlkit_pose_detection | ^0.11.0+2, ^0.12.0 | Pengimbasan ukuran badan |
| Voice/Video Call | zego_uikit_prebuilt_call | ^4.17.0 | Komunikasi waktu nyata |

### Seni Bina Tiga Lapisan

Sistem ini mengimplementasikan seni bina tiga lapisan (three-tier architecture) yang memisahkan tanggungjawab antara lapisan persembahan, logik perniagaan, dan akses data:

1. **Lapisan Persembahan (Presentation Layer)**: Terdiri daripada skrin Flutter (Widget) yang bertanggungjawab untuk memaparkan antara muka pengguna dan menerima input.

2. **Lapisan Logik Perniagaan (Business Logic Layer)**: Diimplementasikan melalui `StateNotifierProvider` dan `Provider` yang mengurus state aplikasi secara reaktif.

3. **Lapisan Akses Data (Data Access Layer)**: Diwakili oleh kelas `Service` yang berkomunikasi terus dengan Firebase.

## 4.2.2 Seni Bina Antara Muka

### Struktur Navigasi

Aplikasi ini menggunakan **go_router** sebagai enjin navigasi deklaratif. Semua laluan navigasi ditakrifkan dalam fail `lib/core/router/app_router.dart` dengan 24 laluan yang merangkumi keseluruhan aliran pengguna dari pendaftaran sehingga pengurusan tempahan.

Navigasi distrukturkan mengikut lima domain utama:

```
/ (Root)
├── Auth Flow (/login, /register, /email-verification)
├── Main Shell (/home with bottom navigation)
├── Product Catalog (/product/:id)
├── Shopping & Checkout (/cart, /checkout/*)
├── Order Management (/orders/*)
├── Profile Management (/profile/*)
└── Digital Tailor (/digital-tailor/*)
```

### Pengurusan State dengan Riverpod

Sistem menggunakan **Riverpod** sebagai penyelesaian pengurusan state reaktif. Pemilihan Riverpod adalah berdasarkan kelebihannya dalam aspek compile-time safety, testability, dan performance.

Tiga corak provider utama yang digunakan:

- `Provider`: Untuk dependency injection (contoh: `authServiceProvider`)
- `StreamProvider`: Untuk mendengar perubahan data real-time dari Firestore
- `StateNotifierProvider`: Untuk mengurus state UI dengan tindakan

## 4.2.3 Pemetaan Modul Antara Muka dan Pangkalan Data

Jadual berikut memetakan setiap modul fungsi kepada komponen Flutter, provider, service, dan koleksi Firestore yang terlibat:

| ID | Nama Modul | Skrin | Provider | Service | Koleksi Firestore |
|----|------------|-------|----------|---------|-------------------|
| M01 | Autentikasi | LoginScreen, RegisterScreen | authStateProvider | AuthService | users |
| M02 | Katalog Produk | HomeScreen, ProductDetailsScreen | productsStreamProvider | ProductService | products, categories |
| M03 | Troli Belian | ShoppingCartScreen | cartProvider | CartService | users/{uid}/cart |
| M04 | Checkout | CheckoutDropoffScreen, CheckoutShippingScreen | checkoutProvider | OrderService | orders |
| M05 | Pengurusan Tempahan | OrderPageScreen, OrderStatusScreen | userOrdersProvider | OrderService | orders, order_events |
| M06 | Chat | ChatScreen, ConversationListScreen | chatProvider | ChatService | conversations, messages |
| M07 | Profil | ProfileScreen, EditProfileScreen | profileProvider | ProfileService | users, addresses |
| M08 | Digital Tailor | ScannerScreen, ResultsScreen | digitalTailorProvider | MeasurementService | users/{uid}/measurements |
| M09 | Notifikasi | - | notificationProvider | NotificationService | - |

## 4.2.4 Analisis Implementasi Setiap Modul

### M01: Modul Autentikasi Pengguna

#### Tujuan
Modul autentikasi bertanggungjawab untuk mengurus identiti pengguna melalui proses pendaftaran, log masuk, pengesahan e-mel, dan pemulihan kata laluan.

#### Skrin Log Masuk (LoginScreen)

Skrin ini memaparkan borang dengan dua medan input (e-mel dan kata laluan) serta dua pilihan kaedah pengesahan:

1. **E-mel/Kata Laluan**: Pengguna memasukkan kredensial yang didaftarkan
2. **Google Sign-In**: Pengguna boleh log masuk menggunakan akaun Google

**Aliran Pelaksanaan:**
```
Pengguna tekan "Sign In"
    → Validasi input (Form validation)
    → AuthNotifier.signInWithEmail()
    → AuthService.signInWithEmail()
    → FirebaseAuth.signInWithEmailAndPassword()
    → Jika berjaya: context.go(AppRoutes.home)
```

**Kod Penting (AuthService.dart):**
```dart
Future<AuthResult> signInWithEmail({
  required String email,
  required String password,
}) async {
  try {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email, password: password,
    );
    return AuthResult.ok(credential.user!);
  } on FirebaseAuthException catch (e) {
    return AuthResult.error(_mapAuthError(e.code));
  }
}
```

#### Struktur Dokumen Firestore (users/{uid})

```json
{
  "email": "user@example.com",
  "fullName": "Ahmad bin Ali",
  "phone": "",
  "address": "",
  "role": "customer",
  "createdAt": "2024-01-15T10:30:00Z",
  "measurement_data": {}
}
```

### M02: Modul Katalog Produk

#### Tujuan
Modul katalog produk memaparkan senarai reka bentuk jahitan dengan penapisan mengikut kategori. Setiap produk memaparkan harga asas dalam format "From RMXXX".

#### Skrin Utama (HomeScreen)

Terdiri daripada empat bahagian:
1. Header Salam dengan nama pengguna
2. Karusel Promosi dari koleksi `banners`
3. Tab Kategori untuk penapisan
4. Grid Produk dalam format 2 lajur

**Aliran Data:**
```
HomeScreen → watch(productsStreamProvider)
    → ProductService.activeProductsStream()
    → Firestore snapshots()
    → Stream<List<Product>>
    → ProductGrid widget
```

**Kod Stream Produk:**
```dart
Stream<List<Product>> activeProductsStream() {
  return _firestore.collection('products').snapshots().map((snap) {
    final products = snap.docs.map((doc) => Product.fromFirestore(doc)).toList();
    products.sort((a, b) => a.order.compareTo(b.order));
    return products;
  });
}
```

### M03: Modul Troli Belian

#### Tujuan
Modul troli membolehkan pelanggan mengumpulkan item yang ingin ditempah sebelum membuat bayaran.

#### Struktur Data Troli

**Laluan Firestore:** `users/{uid}/cart/{cartItemId}`

```json
{
  "productId": "abc123",
  "productName": "Kurung Pahang Pastel",
  "productImageUrl": "https://...",
  "fabricType": "own",
  "selectedColor": "Pastel Pink",
  "measurementProfileId": "profile_001",
  "sizeLabel": "M",
  "quantity": 1,
  "unitPrice": 199.00,
  "addedAt": "2024-01-15T14:20:00Z"
}
```

Setiap item troli mengandungi konfigurasi lengkap: produk, jenis kain, warna, profil ukuran, dan kuantiti.

### M04: Modul Proses Checkout

#### Tujuan
Modul checkout mengurus aliran tempahan dari pengesahan item sehingga penciptaan rekod tempahan.

#### Simulasi Pembayaran

Sistem mengimplementasikan simulasi pembayaran untuk tujuan demonstrasi FYP:

```dart
Future<PaymentRecord> simulatePayment({
  required double amount,
  required PaymentMethod paymentMethod,
}) async {
  await Future.delayed(const Duration(milliseconds: 1500)); // Processing
  await Future.delayed(const Duration(milliseconds: 1000)); // Validating
  
  return PaymentRecord(
    transactionId: _generateTransactionId(), // Format: TXN-XXXXXXXXXXXXXXXX
    referenceNumber: _generateReferenceNumber(), // Format: YYYYMMDD-XXXXXX
    amount: amount,
    status: 'approved',
    paidAt: DateTime.now(),
  );
}
```

### M05: Modul Pengurusan Tempahan

#### Tujuan
Modul ini membolehkan pelanggan memantau status tempahan dan kemajuan jahitan setiap pakaian secara real-time.

#### Model Status Item

Setiap item dalam tempahan mempunyai status individu:

```dart
enum ItemStatus {
  newOrder,         // Baru ditempah
  waitingFabric,    // Menunggu kain
  cutting,          // Potongan
  sewing,           // Jahitan
  fitting,          // Cubaan (opsyenal)
  adjustment,       // Pelarasan (opsyenal)
  qc,               // Pemeriksaan kualiti
  ready,            // Sedia untuk diambil
  delivered;        // Sudah diserahkan
}
```

#### Aliran Data Real-Time

```dart
final orderStreamProvider = StreamProvider.family<BusanaOrder?, String>((ref, orderId) {
  return FirebaseFirestore.instance
      .collection('orders')
      .doc(orderId)
      .snapshots()
      .map((doc) => doc.exists ? BusanaOrder.fromFirestore(doc) : null);
});
```

### M06: Modul Sistem Chat

#### Tujuan
Modul chat menyediakan saluran komunikasi masa nyata antara pelanggan dan tukang jahit. Setiap tempahan mempunyai perbualan tersendiri.

#### Struktur Data Perbualan

**Koleksi Utama:** `conversations/{conversationId}`

```json
{
  "orderId": "order_abc123",
  "orderNumber": "BP-2024-1001",
  "customerId": "user_xyz",
  "customerName": "Ahmad bin Ali",
  "tailorId": "ZF6sJA84xjgLdWZ4RVbnapPuozc2",
  "tailorName": "Busana Prima Tailor",
  "lastMessage": {
    "text": "Baik, saya akan siapkan dalam 2 minggu",
    "senderId": "ZF6sJA84xjgLdWZ4RVbnapPuozc2",
    "type": "text",
    "timestamp": "2024-01-15T14:30:00Z"
  },
  "unreadCount": { "user_xyz": 0, "ZF6sJA84xjgLdWZ4RVbnapPuozc2": 3 },
  "status": "active"
}
```

**Subkoleksi Mesej:** `conversations/{id}/messages/{messageId}`

```json
{
  "senderId": "user_xyz",
  "senderRole": "customer",
  "type": "text",
  "content": "Bila boleh siap?",
  "status": "sent",
  "createdAt": "2024-01-15T14:25:00Z"
}
```

#### Perkhidmatan Panggilan Video

Sistem menyepadukan **ZEGOCLOUD** untuk panggilan suara dan video.

### M07: Modul Profil Pengguna

#### Tujuan
Modul profil mengurus maklumat peribadi pelanggan, alamat penghantaran, dan senarai kegemaran.

#### Struktur Data Alamat

**Laluan:** `users/{uid}/addresses/{addressId}`

```json
{
  "label": "Home",
  "recipientName": "Ahmad bin Ali",
  "phone": "0123456789",
  "addressLine1": "123, Jalan Merdeka",
  "city": "Kuala Lumpur",
  "state": "WP Kuala Lumpur",
  "postcode": "50000",
  "isDefault": true
}
```

### M08: Modul Digital Tailor (Ukuran Badan)

#### Tujuan
Modul ini menggunakan kamera telefon dan Google ML Kit Pose Detection untuk mengukur badan pelanggan secara digital.

#### Proses Pengimbasan

1. **Kalibrasi**: Pengguna meletakkan objek rujukan (kad A4) untuk menentukan skala
2. **Pengimbasan**: Pengguna berdiri dalam pose T, ML Kit mengesan titik-titik badan
3. **Pengiraan**: Ukuran dikira berdasarkan jarak antara titik pose
4. **Penyimpanan**: Profil disimpan untuk kegunaan masa hadapan

#### Algoritma Pengiraan Ukuran

```dart
class MeasurementCalculator {
  static double calculateChestWidth(List<PoseLandmark> landmarks, double scale) {
    final leftShoulder = landmarks.firstWhere((l) => l.type == PoseLandmarkType.leftShoulder);
    final rightShoulder = landmarks.firstWhere((l) => l.type == PoseLandmarkType.rightShoulder);
    final distance = _distanceBetween(leftShoulder, rightShoulder);
    return distance * scale * _chestMultiplier;
  }
}
```

#### Struktur Data Profil Ukuran

**Laluan:** `users/{uid}/measurements/{profileId}`

```json
{
  "profile_name": "Baju Nikah",
  "size_category": "M",
  "measurements": {
    "bahu": { "label": "Bahu", "value_cm": 42.5, "value_inch": 16.73, "region": "atas" },
    "dada": { "label": "Dada", "value_cm": 96.0, "value_inch": 37.80, "region": "tengah" },
    "pinggang": { "label": "Pinggang", "value_cm": 82.0, "value_inch": 32.28, "region": "tengah" }
  },
  "scan_metadata": {
    "confidence_score": 0.85,
    "scan_version": "1.0.0",
    "scanned_at": "2024-01-15T15:00:00Z"
  }
}
```

### M09: Modul Sistem Notifikasi

#### Tujuan
Modul ini mengurus penerimaan dan paparan notifikasi push dari Firebase Cloud Messaging.

#### Pengurusan Token FCM

```dart
Future<void> _registerFcmToken() async {
  final user = FirebaseAuth.instance.currentUser;
  final token = await FirebaseMessaging.instance.getToken();
  
  await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('fcmTokens')
      .doc('primary')
      .set({
        'token': token,
        'updatedAt': FieldValue.serverTimestamp(),
        'platform': 'android',
      });
}
```

## 4.2.5 Analisis Integrasi Front-End dan Back-End

### Seni Bina Komunikasi

Integrasi antara front-end Flutter dan back-end Firebase mengguna pakai corak **Repository Pattern** yang dimeterai melalui kelas Service.

```
┌─────────────────────────────────────────────┐
│           PRESENTATION LAYER                 │
│  (Screens, Widgets, Providers)               │
└────────────────────┬────────────────────────┘
                     │ watch/read/notify
                     ▼
┌─────────────────────────────────────────────┐
│         BUSINESS LOGIC LAYER                 │
│  (StateNotifier, Providers)                  │
└────────────────────┬────────────────────────┘
                     │ method calls
                     ▼
┌─────────────────────────────────────────────┐
│          DATA ACCESS LAYER                   │
│  (Service classes)                           │
└────────────────────┬────────────────────────┘
                     │ Firebase SDK calls
                     ▼
┌─────────────────────────────────────────────┐
│            FIREBASE BACKEND                  │
│  (Auth, Firestore, Storage, Messaging)       │
└─────────────────────────────────────────────┘
```

### Contoh Aliran Data: Penciptaan Tempahan

```
User taps "Place Order"
    ↓
CheckoutProvider.processCheckout()
    ↓
OrderService.createOrder()
    ↓
OrderService.simulatePayment() → Generate transaction ID
    ↓
Firestore.collection('orders').add(orderData)
    ↓
Firestore.collection('users/{uid}/orders').add(reference)
    ↓
Return BusanaOrder object
    ↓
Provider updates state
    ↓
UI navigates to OrderConfirmationScreen
```

## 4.2.6 Analisis Struktur Firestore

### Koleksi Utama

Berdasarkan analisis `firestore.rules`, struktur pangkalan data terdiri daripada koleksi-koleksi berikut:

| Koleksi | Tujuan | Operasi Pelanggan | Operasi Tailor |
|---------|--------|-------------------|----------------|
| `users` | Profil pengguna | Read (own), Update (own) | Read (all) |
| `products` | Katalog produk | Read | Write |
| `categories` | Kategori produk | Read | Write |
| `banners` | Banner promosi | Read | Write |
| `reviews` | Ulasan produk | Read, Create | Update, Delete |
| `orders` | Rekod tempahan | Read (own), Create | Read (all), Update |
| `conversations` | Perbualan | Read (own), Create, Update | Read, Update |
| `call_logs` | Log panggilan | Read (own), Create | Update |

### Subkoleksi

| Subkoleksi | Laluan | Tujuan |
|------------|--------|--------|
| `cart` | `users/{uid}/cart` | Item troli pelanggan |
| `orders` | `users/{uid}/orders` | Rujukan pantas tempahan |
| `measurements` | `users/{uid}/measurements` | Profil ukuran badan |
| `addresses` | `users/{uid}/addresses` | Alamat penghantaran |
| `favourites` | `users/{uid}/favourites` | Produk kegemaran |
| `fcmTokens` | `users/{uid}/fcmTokens` | Token notifikasi |
| `messages` | `conversations/{id}/messages` | Mesej perbualan |

## 4.2.7 Aliran Data Sistem

### Aliran Autentikasi

```
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│  Login   │────▶│ Firebase │────▶│ Firestore│────▶│  Home    │
│  Screen  │     │   Auth   │     │  (users) │     │  Screen  │
└──────────┘     └──────────┘     └──────────┘     └──────────┘
                      │
                      ▼
               ┌──────────┐
               │  Google  │
               │ Sign-In  │
               └──────────┘
```

### Aliran Tempahan

```
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│ Product  │────▶│   Cart   │────▶│ Checkout │────▶│  Order   │
│ Details  │     │  Screen  │     │  Flow    │     │  Created │
└──────────┘     └──────────┘     └──────────┘     └──────────┘
                                       │
                                       ▼
                               ┌──────────────┐
                               │  Payment     │
                               │  Simulation  │
                               └──────────────┘
```

### Aliran Chat

```
┌──────────┐     ┌──────────────┐     ┌──────────┐
│  Order   │────▶│ Conversation │────▶│  Chat    │
│  Screen  │     │   Created    │     │  Screen  │
└──────────┘     └──────────────┘     └──────────┘
                       │
                       ▼
               ┌──────────────┐
               │  Real-time   │
               │   Messages   │
               └──────────────┘
```

### Aliran Digital Tailor

```
┌────────────┐     ┌────────────┐     ┌────────────┐     ┌────────────┐
│Calibration │────▶│  Scanner   │────▶│ Processing │────▶│  Results   │
│   Screen   │     │   Screen   │     │  (ML Kit)  │     │   Screen   │
└────────────┘     └────────────┘     └────────────┘     └────────────┘
                                                                │
                                                                ▼
                                                        ┌────────────┐
                                                        │  Save to   │
                                                        │  Firestore │
                                                        └────────────┘
```

## 4.2.8 Rumusan

Implementasi antara muka dan pangkalan data aplikasi Sokongan Jahitan Pintar telah berjaya direalisasikan dengan mengintegrasikan sembilan modul utama yang merangkumi keseluruhan aliran perniagaan jahitan tempahan. Pendekatan feature-first architecture yang diguna pakai memudahkan penyelenggaraan dan pengembangan sistem.

Penggunaan Firebase sebagai platform backend menyediakan infrastruktur yang mantap untuk pengesahan pengguna, penyimpanan data real-time, dan notifikasi push. Integrasi dengan Google ML Kit membolehkan pengimbasan ukuran badan secara digital, manakala ZEGOCLOUD menyediakan kemudahan komunikasi masa nyata.

Seni bina tiga lapisan yang diimplementasikan memastikan pemisahan tanggungjawab yang jelas antara komponen persembahan, logik perniagaan, dan akses data. Penggunaan Riverpod sebagai penyelesaian pengurusan state menyediakan platform yang type-safe dan boleh diuji untuk pengurusan state aplikasi.

Struktur pangkalan data Firestore yang direka dengan koleksi utama dan subkoleksi membolehkan pengambilan data yang cekap dan selamat dengan peraturan keselamatan yang menghadkan akses berdasarkan peranan pengguna. Sistem ini bersedia untuk dilaksanakan dalam persekitaran produksi dengan penambahbaikan yang berterusan.
