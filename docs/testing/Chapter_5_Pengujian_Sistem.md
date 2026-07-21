# BAB V: PENGUJIAN SISTEM

## 5.1 Pengenalan

Bab ini membincangkan aktiviti pengujian sistem (system testing) yang dijalankan ke atas aplikasi Sokongan Jahitan Pintar (Busana Prima). Pengujian sistem merupakan peringkat pengujian yang mengesahkan bahawa keseluruhan sistem yang telah disepadukan berfungsi selaras dengan keperluan yang ditetapkan dalam Bab III dan implementasi yang dihuraikan dalam Bab IV. Berbeza dengan pengujian unit atau pengujian integrasi, pengujian sistem menilai tingkah laku sistem secara menyeluruh dari perspektif pengguna akhir, iaitu Pelanggan dan Tukang Jahit.

Aplikasi ini dibangunkan menggunakan framework Flutter dengan bahasa Dart, disokong oleh perkhidmatan backend Firebase (Authentication, Cloud Firestore, Storage dan Cloud Messaging), serta mengguna pakai seni bina Model-View-ViewModel (MVVM) yang dilaksanakan melalui corak tiga lapisan (three-tier architecture). Oleh itu, pengujian sistem tertumpu kepada pengesahan aliran fungsi merentasi lapisan persembahan, lapisan logik perniagaan, dan lapisan akses data sehingga ke pangkalan data Firestore.

Skop pengujian dalam bab ini dihadkan kepada dua kategori utama, iaitu pengujian fungsian (functional testing) dan pengujian bukan fungsian (non-functional testing). Pengujian unit dan pengujian integrasi tidak diliputi dalam bab ini kerana kedua-duanya berada di luar skop pengesahan peringkat sistem. Setiap kes ujian yang dibentangkan adalah berasaskan implementasi sebenar kod sumber Flutter dan struktur pangkalan data Firestore, dan boleh diuji semula (repeatable) serta dibuktikan melalui tangkapan skrin.

Susunan bab ini adalah seperti berikut. Bahagian 5.2 membentangkan perancangan pengujian yang merangkumi objektif, asas pengujian, kriteria keluar, teknik pengujian, dan matriks kebolehjejakan. Bahagian 5.3 memaparkan reka bentuk kes ujian bagi pengujian sistem dan pengujian penerimaan pengguna. Bahagian 5.4 menghuraikan persekitaran serta pelaksanaan pengujian. Bahagian 5.5 melaporkan hasil pengujian beserta analisis kadar kelulusan. Akhir sekali, Bahagian 5.6 merumuskan penemuan pengujian sistem.

---

## 5.2 Perancangan Pengujian

Perancangan pengujian menetapkan hala tuju dan piawaian bagi keseluruhan aktiviti pengujian sistem. Perancangan ini disusun berdasarkan piawaian antarabangsa ISO/IEC/IEEE 29119 bagi proses pengujian perisian, dengan menetapkan objektif pengujian, asas pengujian (test basis), kriteria keluar (exit criteria), teknik pengujian yang dipilih, dan matriks kebolehjejakan.

### 5.2.1 Objektif Pengujian

Objektif utama pengujian sistem aplikasi Sokongan Jahitan Pintar adalah seperti berikut:

a. Mengesahkan bahawa setiap Keperluan Fungsian (KF) yang ditetapkan dalam Bab III telah dilaksanakan dan berfungsi dengan betul dalam sistem sebenar.

b. Memastikan aliran proses utama bagi kedua-dua aktor, iaitu Pelanggan dan Tukang Jahit, dapat diselesaikan tanpa ralat kritikal.

c. Mengesahkan bahawa data yang dijana melalui antara muka disimpan dengan tepat ke dalam koleksi dan subkoleksi Firestore yang berkaitan.

d. Menilai pematuhan sistem terhadap Keperluan Bukan Fungsian (KNF) yang meliputi aspek kebolehgunaan, prestasi, keselamatan, kebolehpercayaan, dan kebolehcapaian.

e. Mengenal pasti sebarang kecacatan (defect) supaya dapat diperbetulkan sebelum sistem diserahkan.

### 5.2.2 Asas Pengujian dan Analisis Sistem

Asas pengujian (test basis) merujuk kepada dokumen dan artifak yang menjadi rujukan untuk membentuk kes ujian. Bagi projek ini, asas pengujian terdiri daripada Objektif Projek (Bab I), Keperluan Fungsian, Keperluan Bukan Fungsian, gambar rajah Use Case beserta spesifikasinya (Bab III), dokumen implementasi antara muka dan pangkalan data (Bab IV), serta kod sumber Flutter yang sebenar.

Berdasarkan analisis kod sumber di bawah direktori `lib/features/`, sistem terbahagi kepada sembilan modul utama seperti yang diringkaskan dalam Jadual 5.1. Setiap modul dipetakan kepada Use Case dan Keperluan Fungsian yang berkaitan.

**Jadual 5.1: Pemetaan Modul, Use Case dan Keperluan Fungsian**

| ID Modul | Nama Modul | Skrin Utama (Kod Sumber) | Use Case | KF Berkaitan |
|----------|------------|--------------------------|----------|--------------|
| M01 | Autentikasi | `LoginScreen`, `RegisterScreen`, `ForgotPasswordScreen`, `EmailVerificationScreen` | Daftar Akaun, Log Masuk | KF01, KF02, KF03 |
| M02 | Katalog Produk | `HomeScreen`, `ProductDetailsScreen` | Layari Katalog, Lihat Maklumat Rekaan | KF04, KF05 |
| M03 | Visualisasi 2D AR | `TryOnScreen` | Lihat Visualisasi Rekaan 2D AR | KF06 |
| M04 | Imbasan Badan | `CalibrationScreen`, `ScannerScreen`, `ResultsScreen`, `ProfileListScreen` | Tambah Ukuran Profil | KF07 |
| M05 | Troli Belian | `ShoppingCartScreen` | Tambah Rekaan ke Troli | KF08 |
| M06 | Checkout & Tempahan | `CheckoutDropoffScreen`, `CheckoutShippingScreen`, `OrderConfirmationScreen` | Membuat Tempahan | KF09 |
| M07 | Pengurusan Tempahan | `OrderPageScreen`, `OrderStatusScreen`, `OutfitDetailsScreen` | Jejak Status, Lihat Sejarah, Lihat Perincian, Kemaskini Status, Akses Rekod | KF10, KF11, KF14, KF15, KF16 |
| M08 | Chat & Panggilan | `ConversationListScreen`, `ChatScreen`, `CallScreen` | Mula Perbualan | KF12 |
| M09 | Profil & Alamat | `ProfileScreen`, `EditProfileScreen`, `AddressListScreen` | (Sokongan) | KF13 |

Senarai Keperluan Fungsian yang menjadi sasaran pengujian diringkaskan dalam Jadual 5.2. Senarai ini diselaraskan dengan gambar rajah Use Case yang mempunyai dua aktor, iaitu Pelanggan dan Tukang Jahit.

**Jadual 5.2: Senarai Keperluan Fungsian (KF)**

| ID KF | Keperluan Fungsian | Aktor |
|-------|--------------------|-------|
| KF01 | Sistem membenarkan pengguna mendaftar akaun baharu | Pelanggan |
| KF02 | Sistem membenarkan pengguna log masuk melalui e-mel/kata laluan dan Google Sign-In | Pelanggan, Tukang Jahit |
| KF03 | Sistem membenarkan pengesahan e-mel dan pemulihan kata laluan | Pelanggan |
| KF04 | Sistem membenarkan pengguna melayari katalog dan menapis mengikut kategori | Pelanggan |
| KF05 | Sistem memaparkan maklumat terperinci sesuatu rekaan | Pelanggan |
| KF06 | Sistem membenarkan pelanggan melihat visualisasi rekaan secara 2D AR | Pelanggan |
| KF07 | Sistem membenarkan pelanggan mengukur badan dan menyimpan profil ukuran | Pelanggan |
| KF08 | Sistem membenarkan pelanggan menambah rekaan ke dalam troli | Pelanggan |
| KF09 | Sistem membenarkan pelanggan membuat tempahan melalui proses checkout | Pelanggan |
| KF10 | Sistem membenarkan pelanggan menjejak status tempahan secara masa nyata | Pelanggan |
| KF11 | Sistem membenarkan pelanggan melihat sejarah tempahan | Pelanggan |
| KF12 | Sistem membenarkan pelanggan memulakan perbualan dengan tukang jahit | Pelanggan, Tukang Jahit |
| KF13 | Sistem membenarkan pelanggan mengurus profil dan alamat penghantaran | Pelanggan |
| KF14 | Sistem membenarkan tukang jahit melihat perincian tempahan | Tukang Jahit |
| KF15 | Sistem membenarkan tukang jahit mengemas kini status tempahan | Tukang Jahit |
| KF16 | Sistem membenarkan tukang jahit mengakses rekod tempahan pelanggan | Tukang Jahit |

Analisis risiko turut dijalankan bagi menentukan keutamaan pengujian. Modul berisiko tinggi ialah M01 (Autentikasi), M06 (Checkout & Tempahan), dan M04 (Imbasan Badan), kerana kegagalan pada modul ini memberi kesan langsung terhadap keselamatan akaun, ketepatan rekod tempahan, dan ketepatan ukuran badan. Modul ini diberi keutamaan pengujian yang lebih tinggi.

Selain keperluan fungsian, sistem turut perlu memenuhi lima Keperluan Bukan Fungsian (KNF) yang menjadi asas kepada pengujian bukan fungsian dalam Bahagian 5.3.3. Senarai KNF diringkaskan dalam Jadual 5.3.

**Jadual 5.3: Senarai Keperluan Bukan Fungsian (KNF)**

| Kod | Kategori | Spesifikasi Keperluan Bukan Fungsian |
|-----|----------|--------------------------------------|
| KNF1 | Kebolehgunaan | Sistem hendaklah mempunyai antara muka mesra pengguna dan mudah difahami oleh tukang jahit. |
| KNF2 | Prestasi | Sistem hendaklah memproses imbasan badan dan visualisasi AR dalam tempoh masa yang munasabah. |
| KNF3 | Keselamatan | Sistem hendaklah melaksanakan pengesahan pengguna dan melindungi data pelanggan. |
| KNF4 | Kebolehpercayaan | Sistem hendaklah menyimpan data secara konsisten tanpa kehilangan maklumat. |
| KNF5 | Kebolehcapaian | Sistem hendaklah boleh digunakan pada peranti mudah alih dan menyokong pengguna dengan keperluan khas. |

### 5.2.3 Skop dan Kriteria Keluar (Exit Criteria)

Skop pengujian dihadkan kepada pengujian fungsian dan pengujian bukan fungsian pada peringkat sistem. Pengujian dilaksanakan melalui kaedah kotak hitam (black-box testing) yang menilai output berdasarkan input tanpa memeriksa struktur dalaman kod.

Kriteria keluar (exit criteria) yang perlu dipenuhi sebelum pengujian sistem dianggap selesai adalah seperti berikut:

a. Kesemua Keperluan Fungsian (KF01 hingga KF16) mempunyai sekurang-kurangnya satu kes ujian yang telah dilaksanakan.

b. Kadar kelulusan (pass rate) bagi kes ujian fungsian kritikal mencapai sekurang-kurangnya 95%.

c. Tiada kecacatan bertahap kritikal (critical) atau utama (major) yang masih belum diselesaikan.

d. Kesemua kes ujian bukan fungsian yang dirancang telah dinilai dan didokumenkan.

### 5.2.4 Teknik Pengujian yang Dipilih

Pemilihan teknik pengujian dibuat berdasarkan kesesuaian dengan ciri setiap modul. Lima teknik reka bentuk kes ujian kotak hitam dipilih seperti yang dihuraikan di bawah.

a. **Use Case Testing.** Teknik ini membentuk kes ujian berdasarkan aliran interaksi sebenar antara aktor dengan sistem sebagaimana yang ditakrifkan dalam Use Case Specification. Teknik ini dipilih kerana sistem ini berpusatkan aliran tugasan pengguna (contoh: melayari katalog, membuat tempahan, menjejak status). Teknik ini digunakan pada modul M02, M05, M06, M07 dan M08. Kelebihannya ialah ia mengesahkan aliran perniagaan hujung-ke-hujung yang bermakna kepada pengguna, manakala kekangannya ialah ia kurang berkesan dalam mengesan ralat pada peringkat input individu. Teknik ini disokong oleh Jorgensen (2018) dan piawaian ISO/IEC/IEEE 29119.

b. **Equivalence Partitioning (EP).** Teknik ini membahagikan domain input kepada kelas yang sah dan tidak sah supaya bilangan kes ujian dapat dikurangkan tanpa menjejaskan liputan. Teknik ini dipilih untuk medan input seperti e-mel, kata laluan, nombor telefon, dan nilai ukuran badan. Teknik ini digunakan pada modul M01, M04 dan M09. Kelebihannya ialah pengurangan bilangan kes ujian yang berlebihan, manakala kekangannya ialah ia mungkin terlepas ralat pada sempadan partition. Rujukan: Myers, Sandler & Badgett (2011).

c. **Boundary Value Analysis (BVA).** Teknik ini menguji nilai pada sempadan sesuatu partition kerana ralat lazimnya berlaku pada had bawah dan had atas. Teknik ini dipilih kerana sistem mempunyai banyak had nilai yang jelas, contohnya panjang kata laluan minimum 6 aksara (`Validators.password`), panjang nota maksimum 500 aksara (`AppConstants.maxNotesLength`), julat ukuran fisiologi dalam `RangeValidator`, dan tarikh serahan kain yang mesti pada masa hadapan. Teknik ini digunakan pada modul M01, M04 dan M06. Kelebihannya ialah keberkesanan tinggi dalam mengesan ralat sempadan, manakala kekangannya ialah liputannya terhad kepada input bernilai berjulat. Rujukan: Myers, Sandler & Badgett (2011).

d. **State Transition Testing.** Teknik ini menguji peralihan keadaan sistem yang berubah mengikut peristiwa. Teknik ini dipilih kerana tempahan mempunyai aliran keadaan yang jelas, iaitu status tempahan (`OrderStatus`: pending → confirmed → in_progress → ready → completed, atau cancelled) dan status item jahitan (`ItemStatus`: new → waiting_fabric → cutting → sewing → [fitting] → [adjustment] → qc → ready → delivered). Teknik ini digunakan pada modul M07 dan sebahagian M01 (keadaan sesi log masuk). Kelebihannya ialah ia mengesahkan bahawa hanya peralihan yang dibenarkan boleh berlaku (contoh: pembatalan hanya dibenarkan pada status pending atau confirmed), manakala kekangannya ialah bilangan keadaan yang banyak boleh meningkatkan kerumitan pengujian. Rujukan: ISTQB Foundation Level Syllabus (2018).

e. **Decision Table Testing.** Teknik ini memetakan gabungan syarat kepada tindakan yang sepadan. Teknik ini dipilih untuk proses checkout yang melibatkan gabungan pemboleh ubah, iaitu kaedah penghantaran (`DeliveryMethod`), kaedah penyerahan kain (`FabricDeliveryMethod`), dan terma bayaran (`PaymentTerms`). Teknik ini digunakan pada modul M06. Kelebihannya ialah ia memastikan setiap kombinasi logik diuji secara sistematik, manakala kekangannya ialah jadual boleh menjadi besar apabila bilangan syarat bertambah. Rujukan: Copeland (2004).

### 5.2.5 Matriks Kebolehjejakan (Traceability Matrix)

Matriks kebolehjejakan dalam Jadual 5.4 memetakan setiap Keperluan Fungsian kepada Use Case, modul, dan ID kes ujian yang berkaitan. Matriks ini memastikan tiada Keperluan Fungsian yang tertinggal daripada aktiviti pengujian.

**Jadual 5.4: Matriks Kebolehjejakan Keperluan Fungsian**

| Keperluan Fungsian | Use Case | Modul | ID Kes Ujian |
|--------------------|----------|-------|--------------|
| KF01 | Daftar Akaun | M01 | TC-01 |
| KF02 | Log Masuk | M01 | TC-02, TC-03 |
| KF03 | Pengesahan E-mel / Pemulihan Kata Laluan | M01 | TC-04 |
| KF04 | Layari Katalog | M02 | TC-05 |
| KF05 | Lihat Maklumat Rekaan | M02 | TC-06 |
| KF06 | Lihat Visualisasi Rekaan 2D AR | M03 | TC-07 |
| KF07 | Tambah Ukuran Profil | M04 | TC-08, TC-09 |
| KF08 | Tambah Rekaan ke Troli | M05 | TC-10 |
| KF09 | Membuat Tempahan | M06 | TC-11, TC-12 |
| KF10 | Jejak Status Tempahan | M07 | TC-13 |
| KF11 | Lihat Sejarah Tempahan | M07 | TC-14 |
| KF12 | Mula Perbualan | M08 | TC-15 |
| KF13 | Urus Profil dan Alamat | M09 | TC-16 |
| KF14 | Lihat Perincian Tempahan | M07 | TC-17 |
| KF15 | Kemaskini Status Tempahan | M07 | TC-18 |
| KF16 | Akses Rekod Tempahan | M07 | TC-19 |

---

## 5.3 Reka Bentuk Kes Ujian

Bahagian ini membentangkan reka bentuk kes ujian bagi pengujian fungsian, pengujian bukan fungsian, dan pengujian penerimaan pengguna. Setiap kes ujian ditulis mengikut format piawai yang merangkumi maklumat kes ujian, prasyarat (preconditions), data ujian (test data), prosedur ujian (test procedure), keputusan dijangka (expected result), keputusan sebenar (actual result), dan status.

### 5.3.1 Konvensyen dan Data Ujian Asas

Bagi memastikan keseragaman, dua akaun ujian utama digunakan sepanjang pengujian seperti dalam Jadual 5.5.

**Jadual 5.5: Akaun Ujian**

| Peranan | E-mel | Kata Laluan | Nama Penuh |
|---------|-------|-------------|------------|
| Pelanggan | siti.aminah@gmail.com | Siti1234 | Siti Aminah binti Rahim |
| Tukang Jahit | kakdah.busanaprima@gmail.com | KakDah2024 | Busana Prima Tailor |

Data produk ujian yang digunakan ialah rekaan "Kurung Pahang Pastel" dengan harga asas RM199 (dipaparkan sebagai "From RM199"), kategori "Kurung", warna tersedia "Pastel Pink", dan jenis kain "own" (kain pelanggan sendiri).

### 5.3.2 Kes Ujian Fungsian (System Testing)

**TC-01 — Pendaftaran Akaun Baharu**

| Perkara | Butiran |
|---------|---------|
| Test Case ID | TC-01 |
| Nama Modul | M01 – Autentikasi |
| Functional Requirement | KF01 |
| Use Case | Daftar Akaun |
| Objektif Pengujian | Mengesahkan pengguna baharu dapat mendaftar akaun dan dokumen `users/{uid}` dicipta dengan peranan "customer" |

- **Preconditions:** Aplikasi dibuka pada skrin log masuk; pengguna belum mempunyai akaun; peranti bersambung ke Internet.
- **Test Data:** Nama: "Siti Aminah binti Rahim"; E-mel: siti.aminah@gmail.com; Kata Laluan: Siti1234; Sahkan Kata Laluan: Siti1234.
- **Test Procedure:**
  1. Pelanggan menekan pautan "Daftar" pada skrin log masuk.
  2. Pelanggan memasukkan nama penuh, e-mel, kata laluan, dan pengesahan kata laluan.
  3. Pelanggan menekan butang "Sign Up".
  4. Sistem menjalankan validasi borang dan memanggil `AuthService.registerWithEmail()`.
- **Expected Result:** Akaun Firebase Authentication dicipta, e-mel pengesahan dihantar, dokumen `users/{uid}` dijana dengan medan `role: "customer"`, dan pengguna diarah ke skrin kejayaan pendaftaran.
- **Actual Result:** Akaun berjaya dicipta, e-mel pengesahan diterima, dokumen `users/{uid}` mengandungi `role: "customer"`, dan skrin `RegistrationSuccessScreen` dipaparkan.
- **Status:** BERJAYA

**TC-02 — Log Masuk dengan Kredensial Sah**

| Perkara | Butiran |
|---------|---------|
| Test Case ID | TC-02 |
| Nama Modul | M01 – Autentikasi |
| Functional Requirement | KF02 |
| Use Case | Log Masuk |
| Objektif Pengujian | Mengesahkan pengguna berdaftar dapat log masuk menggunakan e-mel dan kata laluan yang sah |

- **Preconditions:** Akaun siti.aminah@gmail.com telah didaftarkan; peranti bersambung ke Internet.
- **Test Data:** E-mel: siti.aminah@gmail.com; Kata Laluan: Siti1234.
- **Test Procedure:**
  1. Pelanggan memasukkan e-mel pada medan e-mel.
  2. Pelanggan memasukkan kata laluan pada medan kata laluan.
  3. Pelanggan menekan butang "Sign In".
- **Expected Result:** Sistem mengesahkan kredensial melalui `FirebaseAuth.signInWithEmailAndPassword()` dan mengarahkan pengguna ke skrin utama (`/home`).
- **Actual Result:** Log masuk berjaya dan skrin utama dipaparkan dengan header salam nama pengguna.
- **Status:** BERJAYA

**TC-03 — Log Masuk dengan Kata Laluan Salah**

| Perkara | Butiran |
|---------|---------|
| Test Case ID | TC-03 |
| Nama Modul | M01 – Autentikasi |
| Functional Requirement | KF02 |
| Use Case | Log Masuk |
| Objektif Pengujian | Mengesahkan sistem menolak log masuk dengan kata laluan salah dan memaparkan mesej ralat yang sesuai (kes negatif) |

- **Preconditions:** Akaun siti.aminah@gmail.com wujud.
- **Test Data:** E-mel: siti.aminah@gmail.com; Kata Laluan: Salah999.
- **Test Procedure:**
  1. Pelanggan memasukkan e-mel yang sah.
  2. Pelanggan memasukkan kata laluan yang salah.
  3. Pelanggan menekan butang "Sign In".
- **Expected Result:** Sistem menolak log masuk dan memaparkan mesej "Incorrect password. Please try again." atau "Invalid email or password." (pemetaan ralat dalam `_mapAuthError`).
- **Actual Result:** Log masuk ditolak dan mesej ralat dipaparkan; pengguna kekal pada skrin log masuk.
- **Status:** BERJAYA

**TC-04 — Pemulihan Kata Laluan**

| Perkara | Butiran |
|---------|---------|
| Test Case ID | TC-04 |
| Nama Modul | M01 – Autentikasi |
| Functional Requirement | KF03 |
| Use Case | Log Masuk (extend: Pemulihan Kata Laluan) |
| Objektif Pengujian | Mengesahkan pengguna dapat memohon e-mel set semula kata laluan |

- **Preconditions:** Akaun siti.aminah@gmail.com wujud.
- **Test Data:** E-mel: siti.aminah@gmail.com.
- **Test Procedure:**
  1. Pelanggan menekan pautan "Lupa Kata Laluan".
  2. Pelanggan memasukkan e-mel berdaftar.
  3. Pelanggan menekan butang "Hantar".
- **Expected Result:** Sistem memanggil `sendPasswordReset()` dan e-mel set semula kata laluan dihantar ke alamat berdaftar.
- **Actual Result:** E-mel set semula berjaya dihantar dan mesej pengesahan dipaparkan.
- **Status:** BERJAYA

**TC-05 — Melayari Katalog dan Penapisan Kategori**

| Perkara | Butiran |
|---------|---------|
| Test Case ID | TC-05 |
| Nama Modul | M02 – Katalog Produk |
| Functional Requirement | KF04 |
| Use Case | Layari Katalog |
| Objektif Pengujian | Mengesahkan katalog dipaparkan dan penapisan mengikut kategori berfungsi |

- **Preconditions:** Pengguna telah log masuk; koleksi `products` mengandungi rekod aktif.
- **Test Data:** Kategori dipilih: "Kurung".
- **Test Procedure:**
  1. Pelanggan berada pada skrin utama.
  2. Pelanggan melihat grid produk dua lajur beserta harga "From RMXXX".
  3. Pelanggan menekan tab kategori "Kurung".
- **Expected Result:** Sistem memaparkan hanya produk aktif dalam kategori "Kurung" melalui `productsStreamProvider`.
- **Actual Result:** Grid produk dikemas kini memaparkan produk kategori "Kurung" sahaja dengan format harga "From RM199".
- **Status:** BERJAYA

**TC-06 — Melihat Maklumat Rekaan**

| Perkara | Butiran |
|---------|---------|
| Test Case ID | TC-06 |
| Nama Modul | M02 – Katalog Produk |
| Functional Requirement | KF05 |
| Use Case | Lihat Maklumat Rekaan |
| Objektif Pengujian | Mengesahkan maklumat terperinci rekaan dipaparkan dengan betul |

- **Preconditions:** Pengguna telah log masuk.
- **Test Data:** Produk: "Kurung Pahang Pastel".
- **Test Procedure:**
  1. Pelanggan menekan kad produk "Kurung Pahang Pastel" pada grid.
  2. Sistem membuka skrin `ProductDetailsScreen`.
- **Expected Result:** Sistem memaparkan imej, nama, harga asas "From RM199", deskripsi, warna tersedia, dan butang tindakan.
- **Actual Result:** Semua maklumat produk dipaparkan dengan tepat sepadan dengan dokumen Firestore.
- **Status:** BERJAYA

**TC-07 — Visualisasi Rekaan 2D AR (Virtual Try-On)**

| Perkara | Butiran |
|---------|---------|
| Test Case ID | TC-07 |
| Nama Modul | M03 – Visualisasi 2D AR |
| Functional Requirement | KF06 |
| Use Case | Lihat Visualisasi Rekaan 2D AR |
| Objektif Pengujian | Mengesahkan tindanan (overlay) garmen 2D dipaparkan di atas imej badan melalui kamera |

- **Preconditions:** Pengguna telah log masuk; produk mempunyai `transparentUrl` (mod `supportsTryOn` bernilai benar); kebenaran kamera diberikan.
- **Test Data:** Produk: "Kurung Pahang Pastel" dengan PNG lut sinar.
- **Test Procedure:**
  1. Pelanggan menekan butang "Cuba Rekaan" pada skrin perincian produk.
  2. Sistem membuka `TryOnScreen` dan mengaktifkan kamera.
  3. Pelanggan berdiri dalam paparan kamera.
  4. Sistem mengesan torso melalui pose detection dan menindih imej garmen.
- **Expected Result:** Garmen 2D ditindih dan diselaraskan mengikut kedudukan torso pengguna secara masa nyata.
- **Actual Result:** Tindanan garmen dipaparkan dan mengikut pergerakan torso; kedudukan diselaraskan oleh `GarmentOverlayService`.
- **Status:** BERJAYA

**TC-08 — Pengimbasan dan Penyimpanan Profil Ukuran**

| Perkara | Butiran |
|---------|---------|
| Test Case ID | TC-08 |
| Nama Modul | M04 – Imbasan Badan |
| Functional Requirement | KF07 |
| Use Case | Tambah Ukuran Profil |
| Objektif Pengujian | Mengesahkan proses kalibrasi, pengimbasan, pengiraan ukuran, dan penyimpanan profil ke Firestore |

- **Preconditions:** Pengguna telah log masuk; kebenaran kamera diberikan; pencahayaan mencukupi; objek rujukan (kad A4) tersedia.
- **Test Data:** Nama profil: "Baju Nikah"; kategori saiz: "M".
- **Test Procedure:**
  1. Pelanggan membuka modul Imbasan Badan dan menyelesaikan kalibrasi pada `CalibrationScreen`.
  2. Pelanggan berdiri dalam pose yang ditetapkan pada `ScannerScreen`.
  3. Sistem mengesan titik pose (ML Kit) dan mengira ukuran apabila skor kualiti imbasan mencapai ambang `>= 0.65`.
  4. Pelanggan menyimpan profil dengan nama "Baju Nikah".
- **Expected Result:** Ukuran (bahu, dada, pinggang dan lain-lain) dikira dan profil disimpan ke `users/{uid}/measurements/{profileId}` beserta `confidence_score`.
- **Actual Result:** Profil "Baju Nikah" disimpan dengan bahu 42.5 cm, dada 96.0 cm, pinggang 82.0 cm dan `confidence_score` 0.85 (tahap "Tinggi").
- **Status:** BERJAYA

**TC-09 — Validasi Julat Ukuran (Boundary Value Analysis)**

| Perkara | Butiran |
|---------|---------|
| Test Case ID | TC-09 |
| Nama Modul | M04 – Imbasan Badan |
| Functional Requirement | KF07 |
| Use Case | Tambah Ukuran Profil |
| Objektif Pengujian | Mengesahkan sistem menolak nilai ukuran di luar julat fisiologi dalam `RangeValidator` (kes sempadan) |

- **Preconditions:** Enjin pengiraan ukuran aktif.
- **Test Data:** Ukuran dada diuji pada nilai 39.9 cm (di bawah minimum 40.0), 40.0 cm (had minimum), dan 150.1 cm (melebihi maksimum 150.0).
- **Test Procedure:**
  1. Sistem menerima nilai ukuran hasil pengiraan.
  2. `RangeValidator.validate()` menyemak nilai terhadap julat (40.0–150.0 cm untuk dada).
- **Expected Result:** Nilai 39.9 cm ditolak dengan sebab "Terlalu kecil"; 40.0 cm diterima; 150.1 cm ditolak dengan sebab "Terlalu besar".
- **Actual Result:** Nilai sempadan diproses tepat seperti dijangka; nilai di luar julat ditandakan tidak sah.
- **Status:** BERJAYA

**TC-10 — Menambah Rekaan ke Troli**

| Perkara | Butiran |
|---------|---------|
| Test Case ID | TC-10 |
| Nama Modul | M05 – Troli Belian |
| Functional Requirement | KF08 |
| Use Case | Tambah Rekaan ke Troli |
| Objektif Pengujian | Mengesahkan item ditambah ke troli dan logik penggabungan pendua (dedup) berfungsi |

- **Preconditions:** Pengguna telah log masuk; profil ukuran "Baju Nikah" wujud.
- **Test Data:** Produk "Kurung Pahang Pastel"; jenis kain: "own"; warna: "Pastel Pink"; profil ukuran: "Baju Nikah".
- **Test Procedure:**
  1. Pelanggan memilih konfigurasi rekaan (kain, warna, profil ukuran).
  2. Pelanggan menekan butang "Tambah ke Troli".
  3. Pelanggan mengulangi langkah 1–2 dengan konfigurasi yang sama.
- **Expected Result:** Item pertama dicipta di `users/{uid}/cart/{docId}`; penambahan kedua dengan konfigurasi sama menambah kuantiti menjadi 2 (tidak mencipta pendua) mengikut logik `CartService.addToCart()`.
- **Actual Result:** Satu item troli dengan kuantiti 2 tercipta; badge troli dikemas kini.
- **Status:** BERJAYA

**TC-11 — Membuat Tempahan Melalui Checkout**

| Perkara | Butiran |
|---------|---------|
| Test Case ID | TC-11 |
| Nama Modul | M06 – Checkout & Tempahan |
| Functional Requirement | KF09 |
| Use Case | Membuat Tempahan |
| Objektif Pengujian | Mengesahkan pelanggan dapat menyelesaikan proses checkout dan rekod tempahan dicipta di Firestore |

- **Preconditions:** Terdapat sekurang-kurangnya satu item dalam troli; pelanggan mempunyai alamat penghantaran.
- **Test Data:** Kaedah penghantaran: "Ship to address"; kaedah penyerahan kain: "Drop off at boutique"; tarikh serahan kain: 15 Julai 2026; terma bayaran: "Deposit (50%)"; kaedah bayaran: "Visa".
- **Test Procedure:**
  1. Pelanggan membuka troli dan menekan "Checkout".
  2. Pelanggan memilih kaedah penyerahan kain dan tarikh serahan pada `CheckoutDropoffScreen`.
  3. Pelanggan memilih kaedah penghantaran dan alamat pada `CheckoutShippingScreen`.
  4. Pelanggan memilih terma bayaran dan kaedah bayaran, kemudian menekan "Place Order".
  5. Sistem menjalankan simulasi bayaran dan mencipta tempahan.
- **Expected Result:** Simulasi bayaran menjana `transactionId` (format TXN-...) dan `referenceNumber`; dokumen `orders/{orderId}` dicipta dengan status "pending"; skrin `OrderConfirmationScreen` dipaparkan; troli dikosongkan bagi item yang ditempah.
- **Actual Result:** Tempahan BP-2024-1001 dicipta dengan status "pending", rekod bayaran deposit 50% dijana, dan skrin pengesahan dipaparkan.
- **Status:** BERJAYA

**TC-12 — Gabungan Pilihan Checkout (Decision Table)**

| Perkara | Butiran |
|---------|---------|
| Test Case ID | TC-12 |
| Nama Modul | M06 – Checkout & Tempahan |
| Functional Requirement | KF09 |
| Use Case | Membuat Tempahan |
| Objektif Pengujian | Mengesahkan sistem mengendalikan gabungan kaedah penghantaran, penyerahan kain, dan terma bayaran dengan betul |

Jadual keputusan (decision table) bagi gabungan yang diuji ditunjukkan dalam Jadual 5.6.

**Jadual 5.6: Jadual Keputusan Proses Checkout**

| Rule | Kaedah Penghantaran | Penyerahan Kain | Terma Bayaran | Tindakan Dijangka |
|------|---------------------|-----------------|---------------|-------------------|
| R1 | Ship to address | Drop off at boutique | Deposit 50% | Alamat diperlukan; baki 50% direkod |
| R2 | Self-collection | Self-shipping | Full payment | Alamat tidak diperlukan; baki 0 |
| R3 | Ship to address | Self-shipping | Full payment | Alamat diperlukan; baki 0 |
| R4 | Self-collection | Drop off at boutique | Deposit 50% | Alamat tidak diperlukan; baki 50% direkod |

- **Preconditions:** Troli mengandungi item; alamat penghantaran tersedia untuk rule yang memerlukan.
- **Test Data:** Empat gabungan seperti dalam Jadual 5.6.
- **Test Procedure:** Bagi setiap rule R1–R4, pelanggan menyelesaikan proses checkout dengan gabungan pilihan yang ditetapkan.
- **Expected Result:** Setiap rule menghasilkan tindakan seperti dalam lajur "Tindakan Dijangka"; nilai `balanceRemaining` dikira dengan betul mengikut terma bayaran.
- **Actual Result:** Kesemua empat rule menghasilkan tingkah laku yang tepat; medan tempahan disimpan dengan betul.
- **Status:** BERJAYA

**TC-13 — Menjejak Status Tempahan Secara Masa Nyata**

| Perkara | Butiran |
|---------|---------|
| Test Case ID | TC-13 |
| Nama Modul | M07 – Pengurusan Tempahan |
| Functional Requirement | KF10 |
| Use Case | Jejak Status Tempahan |
| Objektif Pengujian | Mengesahkan status tempahan dan kemajuan item dikemas kini secara masa nyata pada peranti pelanggan |

- **Preconditions:** Tempahan BP-2024-1001 wujud; tukang jahit mengemas kini status pada peranti lain.
- **Test Data:** Perubahan status item daripada "new" kepada "sewing".
- **Test Procedure:**
  1. Pelanggan membuka `OrderStatusScreen` bagi tempahan BP-2024-1001.
  2. Tukang jahit mengemas kini status item kepada "sewing".
  3. Pelanggan memerhati skrin tanpa memuat semula secara manual.
- **Expected Result:** Bar kemajuan dan label status dikemas kini secara automatik melalui `orderStreamProvider` yang mendengar `snapshots()` Firestore.
- **Actual Result:** Status dan peratus kemajuan dikemas kini secara masa nyata kepada "Sewing" tanpa muat semula manual.
- **Status:** BERJAYA

**TC-14 — Melihat Sejarah Tempahan**

| Perkara | Butiran |
|---------|---------|
| Test Case ID | TC-14 |
| Nama Modul | M07 – Pengurusan Tempahan |
| Functional Requirement | KF11 |
| Use Case | Lihat Sejarah Tempahan |
| Objektif Pengujian | Mengesahkan senarai tempahan pelanggan dipaparkan mengikut susunan yang betul |

- **Preconditions:** Pelanggan mempunyai sekurang-kurangnya satu tempahan lampau.
- **Test Data:** Tempahan sedia ada milik siti.aminah@gmail.com.
- **Test Procedure:**
  1. Pelanggan membuka `OrderPageScreen`.
  2. Sistem memuatkan tempahan melalui `userOrdersProvider`.
- **Expected Result:** Senarai tempahan pelanggan dipaparkan dengan nombor tempahan, status, dan jumlah bayaran.
- **Actual Result:** Senarai tempahan dipaparkan dengan tepat; hanya tempahan milik pengguna dipaparkan.
- **Status:** BERJAYA

**TC-15 — Memulakan Perbualan dengan Tukang Jahit**

| Perkara | Butiran |
|---------|---------|
| Test Case ID | TC-15 |
| Nama Modul | M08 – Chat & Panggilan |
| Functional Requirement | KF12 |
| Use Case | Mula Perbualan |
| Objektif Pengujian | Mengesahkan pelanggan dapat memulakan perbualan dan mesej dihantar secara masa nyata |

- **Preconditions:** Pelanggan mempunyai tempahan aktif; pelanggan telah log masuk.
- **Test Data:** Mesej: "Salam, bila kain perlu dihantar?".
- **Test Procedure:**
  1. Pelanggan membuka perbualan berkaitan tempahan melalui `ChatScreen`.
  2. Pelanggan menaip mesej pada medan komposer.
  3. Pelanggan menekan butang hantar.
- **Expected Result:** Mesej disimpan ke `conversations/{id}/messages/{messageId}`, dipaparkan dalam perbualan, dan medan `lastMessage` serta `unreadCount` tukang jahit dikemas kini.
- **Actual Result:** Mesej dihantar dan dipaparkan kepada tukang jahit, tetapi tidak ditandakan sebagai belum dibaca.
- **Status:** TIDAK BERJAYA

**TC-16 — Mengurus Profil dan Alamat**

| Perkara | Butiran |
|---------|---------|
| Test Case ID | TC-16 |
| Nama Modul | M09 – Profil & Alamat |
| Functional Requirement | KF13 |
| Use Case | Urus Profil (Sokongan) |
| Objektif Pengujian | Mengesahkan pelanggan dapat mengemas kini profil dan menambah alamat penghantaran |

- **Preconditions:** Pelanggan telah log masuk.
- **Test Data:** Nombor telefon: 0129876543; Alamat: "123, Jalan Merdeka, 50000 Kuala Lumpur, WP Kuala Lumpur".
- **Test Procedure:**
  1. Pelanggan membuka `EditProfileScreen` dan mengemas kini nombor telefon.
  2. Pelanggan menyimpan perubahan.
  3. Pelanggan membuka `AddressListScreen` dan menambah alamat baharu.
- **Expected Result:** Perubahan profil disimpan ke `users/{uid}`; alamat baharu disimpan ke `users/{uid}/addresses/{addressId}` dengan `isDefault: true`.
- **Actual Result:** Profil dan alamat berjaya disimpan dan dipaparkan semula dengan betul.
- **Status:** BERJAYA

**TC-17 — Tukang Jahit Melihat Perincian Tempahan**

| Perkara | Butiran |
|---------|---------|
| Test Case ID | TC-17 |
| Nama Modul | M07 – Pengurusan Tempahan |
| Functional Requirement | KF14 |
| Use Case | Lihat Perincian Tempahan |
| Objektif Pengujian | Mengesahkan tukang jahit dapat melihat perincian tempahan termasuk item dan profil ukuran pelanggan |

- **Preconditions:** Log masuk sebagai akaun tukang jahit; tempahan BP-2024-1001 wujud.
- **Test Data:** Tempahan BP-2024-1001.
- **Test Procedure:**
  1. Tukang jahit membuka perincian tempahan.
  2. Sistem memuatkan item tempahan dan rujukan profil ukuran.
- **Expected Result:** Perincian tempahan, senarai item, jenis kain, warna, dan ukuran pelanggan dipaparkan; capaian dibenarkan oleh peraturan keselamatan `isTailor()`.
- **Actual Result:** Maklumat ukuran pelanggan tidak dipaparkan pada skrin perincian tempahan tukang jahit.
- **Status:** TIDAK BERJAYA

**TC-18 — Tukang Jahit Mengemas Kini Status Tempahan (State Transition)**

| Perkara | Butiran |
|---------|---------|
| Test Case ID | TC-18 |
| Nama Modul | M07 – Pengurusan Tempahan |
| Functional Requirement | KF15 |
| Use Case | Kemaskini Status Tempahan |
| Objektif Pengujian | Mengesahkan peralihan status item mengikut aliran kerja dan sekatan pembatalan |

- **Preconditions:** Log masuk sebagai tukang jahit; item tempahan pada status "new".
- **Test Data:** Peralihan status item: new → waiting_fabric → cutting → sewing.
- **Test Procedure:**
  1. Tukang jahit memilih item dalam tempahan.
  2. Tukang jahit mengemas kini status mengikut urutan aliran kerja `ItemStatus`.
  3. Tukang jahit cuba membatalkan item pada status "cutting".
- **Expected Result:** Setiap peralihan sah direkod ke Firestore; pembatalan pada status "cutting" ditolak kerana `isCancellable` hanya benar pada status "new" dan "waiting_fabric".
- **Actual Result:** Peralihan status berjaya direkod; pembatalan pada peringkat "cutting" tidak dibenarkan seperti dijangka.
- **Status:** BERJAYA

**TC-19 — Tukang Jahit Mengakses Rekod Tempahan**

| Perkara | Butiran |
|---------|---------|
| Test Case ID | TC-19 |
| Nama Modul | M07 – Pengurusan Tempahan |
| Functional Requirement | KF16 |
| Use Case | Akses Rekod Tempahan |
| Objektif Pengujian | Mengesahkan tukang jahit dapat mengakses kesemua rekod tempahan pelanggan |

- **Preconditions:** Log masuk sebagai tukang jahit; terdapat beberapa tempahan daripada pelanggan berlainan.
- **Test Data:** Koleksi `orders` mengandungi pelbagai tempahan.
- **Test Procedure:**
  1. Tukang jahit membuka senarai tempahan.
  2. Sistem memuatkan kesemua tempahan mengikut kebenaran `isTailor()`.
- **Expected Result:** Kesemua tempahan dipaparkan tanpa mengira pemilik, mengikut peraturan `allow read: if isTailor()`.
- **Actual Result:** Kesemua rekod tempahan dipaparkan kepada tukang jahit.
- **Status:** BERJAYA

### 5.3.3 Kes Ujian Bukan Fungsian

Bahagian ini menguji lima Keperluan Bukan Fungsian (KNF1 hingga KNF5) seperti yang disenaraikan dalam Jadual 5.3, iaitu kebolehgunaan, prestasi, keselamatan, kebolehpercayaan, dan kebolehcapaian.

**TC-NF01 — Kebolehgunaan Antara Muka (KNF1)**

| Perkara | Butiran |
|---------|---------|
| Test Case ID | TC-NF01 |
| KNF | KNF1 – Kebolehgunaan |
| Objektif Pengujian | Mengesahkan antara muka mesra pengguna dan mudah difahami oleh tukang jahit serta pelanggan |

- **Preconditions:** Aplikasi dipasang; wakil pengguna tukang jahit dan pelanggan belum diberi latihan formal.
- **Test Data:** Tugasan pelanggan: melengkapkan tempahan dari troli; tugasan tukang jahit: mengemas kini status tempahan.
- **Test Procedure:**
  1. Pelanggan menyelesaikan aliran tempahan dari troli hingga pengesahan tanpa bantuan.
  2. Tukang jahit membuka perincian tempahan dan mengemas kini status item tanpa bantuan.
  3. Rekod bilangan langkah dan sama ada tugasan dapat diselesaikan tanpa panduan.
- **Expected Result:** Kedua-dua aktor menyelesaikan tugasan tanpa bantuan; aliran tempahan diselesaikan dalam ≤ 5 langkah utama; label dan ikon mudah difahami.
- **Actual Result:** Pelanggan menyelesaikan tempahan dalam 4 langkah (troli → dropoff → shipping → bayaran/pengesahan); tukang jahit mengemas kini status tanpa bantuan.
- **Status:** BERJAYA

**TC-NF02 — Prestasi Pemprosesan Imbasan dan AR (KNF2)**

| Perkara | Butiran |
|---------|---------|
| Test Case ID | TC-NF02 |
| KNF | KNF2 – Prestasi |
| Objektif Pengujian | Mengesahkan imbasan badan dan visualisasi AR diproses dalam tempoh masa yang munasabah |

- **Preconditions:** Kebenaran kamera diberikan; pencahayaan mencukupi; produk menyokong Try-On.
- **Test Data:** Sasaran masa pengiraan ukuran selepas imbasan ≤ 10 saat; kadar bingkai tindanan AR lancar (~real-time).
- **Test Procedure:**
  1. Jalankan pengimbasan badan pada `ScannerScreen` dan rekod masa dari imbasan sehingga hasil ukuran dipaparkan pada `ResultsScreen`.
  2. Buka `TryOnScreen` dan perhati kelancaran tindanan garmen mengikut pergerakan torso.
- **Expected Result:** Ukuran dikira dan dipaparkan dalam ≤ 10 saat selepas kualiti imbasan mencapai ambang `>= 0.65`; tindanan AR dikemas kini secara masa nyata tanpa lag ketara.
- **Actual Result:** Ukuran dipaparkan dalam ~6 saat selepas pose stabil; tindanan AR mengikut pergerakan torso dengan lancar.
- **Status:** BERJAYA

**TC-NF03 — Pengesahan Pengguna dan Perlindungan Data (KNF3)**

| Perkara | Butiran |
|---------|---------|
| Test Case ID | TC-NF03 |
| KNF | KNF3 – Keselamatan |
| Objektif Pengujian | Mengesahkan sistem melaksanakan pengesahan pengguna dan melindungi data pelanggan melalui kawalan akses berasaskan peranan |

- **Preconditions:** Log masuk sebagai pelanggan biasa; peraturan `firestore.rules` aktif.
- **Test Data:** Cubaan mengakses skrin terlindung tanpa log masuk; cubaan membaca tempahan milik pelanggan lain; cubaan mengubah medan `role` kepada "tailor".
- **Test Procedure:**
  1. Cuba mengakses fungsi tempahan tanpa sesi log masuk yang sah.
  2. Pelanggan cuba membaca dokumen tempahan yang bukan miliknya.
  3. Pelanggan cuba mengemas kini dokumen `users/{uid}` dengan `role: "tailor"`.
- **Expected Result:** Capaian tanpa log masuk dihalang; operasi (2) dan (3) ditolak oleh peraturan `firestore.rules` (`resource.data.customerId == request.auth.uid` dan `request.resource.data.role == 'customer'`).
- **Actual Result:** Capaian tanpa kebenaran ditolak dengan ralat permission-denied; data pelanggan lain tidak boleh dicapai.
- **Status:** BERJAYA

**TC-NF04 — Kebolehpercayaan dan Kekonsistenan Data (KNF4)**

| Perkara | Butiran |
|---------|---------|
| Test Case ID | TC-NF04 |
| KNF | KNF4 – Kebolehpercayaan |
| Objektif Pengujian | Mengesahkan data disimpan secara konsisten tanpa kehilangan maklumat selepas operasi tulis dan penyegerakan |

- **Preconditions:** Pengguna telah log masuk.
- **Test Data:** Tempahan baharu; kemas kini status item.
- **Test Procedure:**
  1. Cipta tempahan dan tutup aplikasi sepenuhnya.
  2. Buka semula aplikasi dan periksa tempahan serta butirannya.
  3. Kemas kini status pada satu peranti dan perhati penyegerakan pada peranti lain.
- **Expected Result:** Data tempahan kekal utuh selepas aplikasi dibuka semula tanpa kehilangan medan; perubahan disegerakkan secara konsisten antara peranti.
- **Actual Result:** Data kekal utuh dan konsisten; penyegerakan masa nyata berjaya tanpa kehilangan maklumat.
- **Status:** BERJAYA

**TC-NF05 — Kebolehcapaian Peranti dan Sokongan Keperluan Khas (KNF5)**

| Perkara | Butiran |
|---------|---------|
| Test Case ID | TC-NF05 |
| KNF | KNF5 – Kebolehcapaian |
| Objektif Pengujian | Mengesahkan aplikasi boleh digunakan pada peranti mudah alih dan menyokong pengguna dengan keperluan khas |

- **Preconditions:** Aplikasi dipasang pada peranti mudah alih berbeza saiz skrin.
- **Test Data:** Peranti Android 11 dan Android 13; ciri panduan suara (Text-to-Speech) dalam modul Imbasan Badan; tetapan saiz teks sistem diperbesar.
- **Test Procedure:**
  1. Jalankan aliran utama (log masuk, katalog, tempahan) pada peranti berlainan saiz skrin.
  2. Aktifkan modul Imbasan Badan dan sahkan panduan suara (`VoiceGuidanceService`) membacakan arahan pengimbasan.
  3. Besarkan saiz teks sistem dan perhati susun atur kekal terbaca.
- **Expected Result:** Susun atur responsif dan konsisten pada pelbagai saiz skrin; panduan suara membantu pengguna semasa pengimbasan; teks kekal terbaca tanpa ralat susun atur (overflow).
- **Actual Result:** Aplikasi responsif pada kedua-dua peranti; panduan suara berfungsi memberikan arahan audio; susun atur kekal terbaca apabila saiz teks diperbesar.
- **Status:** BERJAYA

### 5.3.4 Kes Ujian Penerimaan Pengguna (UAT)

Pengujian penerimaan pengguna (*User Acceptance Testing*, UAT) dijalankan bagi mengesahkan bahawa sistem memenuhi keperluan operasi sebenar pengguna akhir daripada perspektif Pelanggan dan Tukang Jahit. UAT melengkapkan pengujian fungsian (Bahagian 5.3.2) dengan menilai tahap kepuasan dan penerimaan pengguna terhadap sistem.

Pelaksanaan UAT dijalankan pada 9 Julai 2026 melibatkan tiga orang responden, iaitu dua orang pelanggan dan seorang tukang jahit. Responden diminta menggunakan sistem secara bebas, kemudian mengisi borang soal selidik kepuasan yang mengandungi sepuluh kenyataan penilaian menggunakan skala Likert 1 hingga 5.

**Jadual 5.7: Profil Responden UAT**

| ID | Nama | Peranan | Umur | Latar Belakang |
|----|------|---------|------|----------------|
| R1 | Nur Aina binti Hassan | Pelanggan | 27 | Eksekutif pejabat, pernah menggunakan perkhidmatan jahitan |
| R2 | Puan Khadijah binti Omar | Pelanggan | 48 | Suri rumah, kerap membuat tempahan pakaian keluarga |
| R3 | Puan Siti Dahilah | Tukang Jahit | 52 | Pemilik butik jahitan Busana Prima |

#### 5.3.4.1 Keputusan Soal Selidik Kepuasan UAT

Keputusan borang soal selidik responden diringkaskan dalam Jadual 5.7a dan Jadual 5.7b.

**Jadual 5.7a: Keputusan Soal Selidik Kepuasan UAT**

| No | Pernyataan | R1 | R2 | R3 | Purata |
|----|------------|----|----|-----|--------|
| 1 | Sistem mudah difahami tanpa latihan formal | 4 | 4 | 4 | 4.0 |
| 2 | Antara muka mesra pengguna | 4 | 5 | 4 | 4.3 |
| 3 | Proses tempahan jelas dari mula hingga akhir | 5 | 4 | 5 | 4.7 |
| 4 | Ciri imbasan badan membantu mengurangkan ukuran manual | 4 | 5 | 5 | 4.7 |
| 5 | Virtual Try-On membantu memilih reka bentuk | 4 | 3 | 5 | 4.0 |
| 6 | Penjejakan status per item sangat berguna | 5 | 5 | 5 | 5.0 |
| 7 | Chat dalam aplikasi lebih teratur daripada WhatsApp | 3 | 4 | 4 | 3.7 |
| 8 | Sistem membantu tukang jahit mengurus pesanan | 5 | 5 | 5 | 5.0 |
| 9 | Saya akan menggunakan sistem ini untuk tempahan akan datang | 4 | 5 | 5 | 4.7 |
| 10 | Saya akan mengesyorkan sistem ini kepada orang lain | 4 | 5 | 4 | 4.3 |

**Jadual 5.7b: Purata Skor Kepuasan Mengikut Responden**

| Responden | Peranan | Jumlah Skor | Purata |
|-----------|---------|-------------|--------|
| R1 — Nur Aina binti Hassan | Pelanggan | 42 | 4.2 |
| R2 — Puan Khadijah binti Omar | Pelanggan | 45 | 4.5 |
| R3 — Puan Siti Dahilah | Tukang Jahit | 46 | 4.6 |
| Keseluruhan | — | 133 | 4.4 / 5.0 |

#### 5.3.4.2 Huraian Keputusan UAT

Berdasarkan keputusan soal selidik, sistem mencapai purata keseluruhan 4.4 daripada 5.0, menunjukkan tahap penerimaan dan kepuasan pengguna yang tinggi. Responden tukang jahit (R3) mencatat purata tertinggi iaitu 4.6, diikuti responden pelanggan R2 (4.5) dan R1 (4.2). Aspek penjejakan status per item dan pengurusan pesanan tukang jahit mencapai skor purata maksimum 5.0, manakala modul sembang mencatat skor purata terendah iaitu 3.7. Penilaian ini selaras dengan kecacatan TC-15 dan TC-17 yang dikenal pasti dalam pengujian fungsian.

#### 5.3.4.3 Keputusan Penerimaan UAT

Berdasarkan purata kepuasan soal selidik sebanyak 4.4 daripada 5.0 yang melepasi sasaran minimum 4.0, sistem **DITERIMA** untuk operasi dengan syarat penambahbaikan pada modul sembang dan paparan ukuran tukang jahit.

**Jadual 5.7c: Pengesahan Responden UAT**

| Peranan | Nama | Tarikh |
|---------|------|--------|
| Pelanggan (R1) | Nur Aina binti Hassan | 9 Julai 2026 |
| Pelanggan (R2) | Puan Khadijah binti Omar | 9 Julai 2026 |
| Tukang Jahit (R3) | Puan Siti Dahilah | 9 Julai 2026 |
| Fasilitator | Pembangun Sistem (FYP) | 9 Julai 2026 |

---

## 5.4 Implementasi dan Pelaksanaan Pengujian

Bahagian ini menghuraikan persekitaran pengujian dan prosedur pelaksanaan bagi memastikan pengujian dapat diulang (repeatable).

### 5.4.1 Persekitaran Pengujian

Pengujian dijalankan dalam persekitaran sebenar menggunakan peranti fizikal dan perkhidmatan Firebase yang aktif. Butiran persekitaran diringkaskan dalam Jadual 5.8.

**Jadual 5.8: Persekitaran dan Konfigurasi Pengujian**

| Komponen | Spesifikasi |
|----------|-------------|
| Peranti ujian utama | Telefon pintar Android (skrin 6.4 inci) |
| Peranti ujian kedua | Telefon pintar Android (untuk pengesahan penyegerakan masa nyata) |
| Versi Android | Android 11 dan Android 13 |
| Versi Flutter | Flutter SDK ^3.11.0 (Dart) |
| Pengurusan state | flutter_riverpod ^2.6.1 |
| Navigasi | go_router ^14.8.1 |
| Backend | Firebase Authentication ^5.5.4, Cloud Firestore ^5.6.7, Firebase Storage ^12.4.0, Firebase Messaging ^15.0.0 |
| Pengesanan pose | google_mlkit_pose_detection ^0.12.0, camera ^0.11.0+2 |
| Panggilan suara/video | zego_uikit_prebuilt_call ^4.17.0 |
| Sambungan Internet | Wi-Fi (kelajuan sederhana, ~30 Mbps) dan data mudah alih 4G |
| Akaun Firebase | Projek Firebase Busana Prima (tier percuma) |
| Tarikh pengujian | 5 – 6 Julai 2026 (pengujian teknikal); 9 Julai 2026 (UAT) |

### 5.4.2 Prosedur Pelaksanaan

Pelaksanaan pengujian dijalankan mengikut prosedur berikut:

a. Menyediakan data ujian awal, iaitu akaun pelanggan dan tukang jahit, produk dalam koleksi `products`, dan profil ukuran.

b. Melaksanakan setiap kes ujian mengikut prosedur ujian (test procedure) yang ditetapkan dalam Bahagian 5.3 secara berurutan.

c. Merekod keputusan sebenar (actual result) bagi setiap kes ujian dan membandingkannya dengan keputusan dijangka (expected result).

d. Merakam tangkapan skrin sebagai bukti bagi setiap kes ujian yang berjaya atau gagal.

e. Menandakan status setiap kes ujian sebagai BERJAYA, TIDAK BERJAYA, atau PENDING.

f. Merekod dan melaporkan sebarang kecacatan yang ditemui untuk tindakan pembetulan.

---

## 5.5 Hasil Pengujian

Bahagian ini melaporkan keputusan keseluruhan aktiviti pengujian, merangkumi keputusan pengujian fungsian, bukan fungsian, dan penerimaan pengguna, beserta analisis kadar kelulusan.

### 5.5.1 Keputusan Pengujian Fungsian

**Jadual 5.9: Ringkasan Keputusan Pengujian Fungsian**

| Kes Uji ID | Hasil Jangkaan | Keputusan Sebenar | Status |
|------------|----------------|-------------------|--------|
| TC-01 | Akaun dicipta, dokumen `users` dengan role customer | Akaun dan dokumen dicipta dengan betul | BERJAYA |
| TC-02 | Log masuk berjaya ke skrin utama | Log masuk berjaya | BERJAYA |
| TC-03 | Log masuk ditolak dengan mesej ralat | Ralat dipaparkan, log masuk ditolak | BERJAYA |
| TC-04 | E-mel set semula kata laluan dihantar | E-mel dihantar | BERJAYA |
| TC-05 | Katalog ditapis mengikut kategori | Penapisan berjaya | BERJAYA |
| TC-06 | Maklumat rekaan dipaparkan | Maklumat dipaparkan tepat | BERJAYA |
| TC-07 | Tindanan rekaan 2D dipaparkan | Tindanan berfungsi | BERJAYA |
| TC-08 | Profil ukuran disimpan ke Firestore | Profil disimpan dengan skor keyakinan | BERJAYA |
| TC-09 | Nilai luar julat ditolak, nilai sempadan diterima | Validasi julat tepat | BERJAYA |
| TC-10 | Item ke troli, pendua digabung | Kuantiti digabung menjadi 2 | BERJAYA |
| TC-11 | Tempahan dicipta, bayaran disimulasi | Tempahan BP-2024-1001 dicipta | BERJAYA |
| TC-12 | Gabungan semak keluar dikendali betul | Kesemua rule R1–R4 tepat | BERJAYA |
| TC-13 | Status dikemas kini masa nyata | Kemas kini masa nyata berjaya | BERJAYA |
| TC-14 | Sejarah tempahan dipaparkan | Senarai tempahan tepat | BERJAYA |
| TC-15 | Mesej dihantar masa nyata dan ditandakan belum dibaca kepada tukang jahit | Mesej dihantar dan dipaparkan kepada tukang jahit tetapi tidak ditandakan sebagai belum dibaca | TIDAK BERJAYA |
| TC-16 | Profil dan alamat dikemas kini | Data disimpan | BERJAYA |
| TC-17 | Perincian tempahan dilihat tukang jahit | Maklumat ukuran pelanggan tidak dipaparkan | TIDAK BERJAYA |
| TC-18 | Peralihan status sah, pembatalan disekat | Aliran status betul | BERJAYA |
| TC-19 | Semua rekod tempahan diakses tukang jahit | Semua rekod dipaparkan | BERJAYA |

### 5.5.2 Keputusan Pengujian Bukan Fungsian

**Jadual 5.10: Ringkasan Keputusan Pengujian Bukan Fungsian**

| Kes Uji ID | KNF | Hasil Jangkaan | Keputusan Sebenar | Status |
|------------|-----|----------------|-------------------|--------|
| TC-NF01 | KNF1 – Kebolehgunaan | Tugasan selesai tanpa bantuan, ≤ 5 langkah | Selesai dalam 4 langkah tanpa bantuan | BERJAYA |
| TC-NF02 | KNF2 – Prestasi | Imbasan ≤ 10s, AR masa nyata | Ukuran ~6s, AR lancar | BERJAYA |
| TC-NF03 | KNF3 – Keselamatan | Capaian tanpa kebenaran ditolak | Permission-denied dipulangkan | BERJAYA |
| TC-NF04 | KNF4 – Kebolehpercayaan | Data kekal & konsisten tanpa hilang | Data utuh, segerak berjaya | BERJAYA |
| TC-NF05 | KNF5 – Kebolehcapaian | Responsif & sokong keperluan khas | Responsif, panduan suara berfungsi | BERJAYA |

### 5.5.3 Analisis Keputusan

Jumlah keseluruhan kes ujian yang dilaksanakan ialah 24 kes ujian teknikal, iaitu 19 kes ujian fungsian dan 5 kes ujian bukan fungsian. Selain itu, UAT dijalankan melalui borang soal selidik kepuasan yang melibatkan tiga responden pengguna akhir.

**Jadual 5.11: Analisis Kadar Kelulusan Pengujian Teknikal**

| Kategori | Jumlah Kes | BERJAYA | GAGAL | Kadar Kelulusan |
|----------|------------|---------|-------|-----------------|
| Fungsian | 19 | 17 | 2 | 89.5% |
| Bukan Fungsian | 5 | 5 | 0 | 100% |
| **Jumlah** | **24** | **22** | **2** | **91%** |

**Jadual 5.11a: Ringkasan Keputusan UAT (Soal Selidik)**

| Metrik UAT | Nilai |
|------------|-------|
| Bilangan responden | 3 |
| Bilangan kenyataan penilaian | 10 |
| Jumlah skor keseluruhan | 133 / 150 |
| Purata kepuasan soal selidik | 4.4 / 5.0 |
| Keputusan penerimaan | **DITERIMA** (bersyarat) |

Kadar kelulusan (pass rate) pengujian teknikal dikira menggunakan formula:

Kadar Kelulusan = (Bilangan BERJAYA ÷ Jumlah Kes Ujian) × 100%

Kadar Kelulusan = (22 ÷ 24) × 100% = 91%

Sebanyak 22 daripada 24 kes ujian teknikal mencapai status BERJAYA, memberikan kadar kelulusan sebanyak 91%. Kesemua lima kes ujian bukan fungsian (KNF1 hingga KNF5) berjaya diluluskan, menunjukkan sistem memenuhi keperluan kebolehgunaan, prestasi, keselamatan, kebolehpercayaan, dan kebolehcapaian. Bagi pengujian fungsian pula, 17 daripada 19 kes ujian berjaya, menghasilkan kadar kelulusan 89.5%. Dua kecacatan dikenal pasti melalui TC-15 dan TC-17, yang melibatkan modul sembang (KF12) dan paparan ukuran pada skrin tukang jahit (KF14). Kes ujian negatif (TC-03, TC-09 dan TC-NF03) turut berjaya, membuktikan sistem mengendalikan input tidak sah dan cubaan capaian tanpa kebenaran dengan sewajarnya.

Bagi UAT pula, keputusan soal selidik menunjukkan purata kepuasan keseluruhan 4.4 daripada 5.0, dengan responden tukang jahit (R3) mencatat purata tertinggi iaitu 4.6, diikuti responden pelanggan R2 (4.5) dan R1 (4.2). Aspek penjejakan status per item dan pengurusan pesanan tukang jahit mencapai skor purata maksimum 5.0, manakala modul sembang mencatat skor purata terendah iaitu 3.7. Penilaian ini selaras dengan kecacatan TC-15 dan TC-17 yang dikenal pasti dalam pengujian fungsian.

Secara keseluruhan, gabungan keputusan pengujian teknikal dan UAT menunjukkan majoriti fungsi sistem beroperasi dengan betul dan diterima oleh pengguna akhir. Walau bagaimanapun, kadar kelulusan fungsian (89.5%) tidak mencapai sasaran 95% yang ditetapkan dalam kriteria keluar disebabkan dua isyu pada modul chat dan paparan ukuran. Sistem **DITERIMA** untuk operasi dengan syarat kedua-dua isyu tersebut diperbetulkan pada fasa penambahbaikan.

### 5.5.4 Senarai Bukti Pengujian

Setiap kes ujian disokong oleh tangkapan skrin sebagai bukti pelaksanaan. Senarai rajah bukti diringkaskan dalam Jadual 5.12.

**Jadual 5.12: Senarai Bukti Pengujian (Tangkapan Skrin)**

| Rajah | Tajuk Bukti | Kes Ujian Berkaitan |
|-------|-------------|---------------------|
| Rajah 5.1 | Paparan borang pendaftaran akaun | TC-01 |
| Rajah 5.2 | Paparan log masuk berjaya (skrin utama) | TC-02 |
| Rajah 5.3 | Paparan mesej ralat log masuk gagal | TC-03 |
| Rajah 5.4 | Paparan e-mel set semula kata laluan | TC-04 |
| Rajah 5.5 | Paparan katalog dan penapisan kategori | TC-05 |
| Rajah 5.6 | Paparan perincian rekaan | TC-06 |
| Rajah 5.7 | Paparan visualisasi 2D AR (Try-On) | TC-07 |
| Rajah 5.8 | Paparan hasil ukuran dan simpan profil | TC-08 |
| Rajah 5.9 | Paparan amaran nilai ukuran di luar julat | TC-09 |
| Rajah 5.10 | Paparan troli dengan kuantiti digabung | TC-10 |
| Rajah 5.11 | Paparan pengesahan tempahan | TC-11 |
| Rajah 5.12 | Paparan pilihan checkout | TC-12 |
| Rajah 5.13 | Paparan status tempahan masa nyata | TC-13 |
| Rajah 5.14 | Paparan sejarah tempahan | TC-14 |
| Rajah 5.15 | Paparan skrin perbualan | TC-15 |
| Rajah 5.16 | Paparan kemas kini profil dan alamat | TC-16 |
| Rajah 5.17 | Paparan perincian tempahan (tukang jahit) | TC-17 |
| Rajah 5.18 | Paparan kemas kini status tempahan | TC-18 |
| Rajah 5.19 | Paparan senarai rekod tempahan (tukang jahit) | TC-19 |

---

## 5.6 Rumusan

Bab ini telah membentangkan aktiviti pengujian sistem yang menyeluruh ke atas aplikasi Sokongan Jahitan Pintar (Busana Prima). Pengujian dirancang berdasarkan piawaian ISO/IEC/IEEE 29119 dengan menetapkan objektif, asas pengujian, dan kriteria keluar yang jelas. Lima teknik pengujian kotak hitam, iaitu Ujian Kes Guna, Pembahagian Kesetaraan (EP), Analisis Nilai Sempadan (BVA), Pengujian Peralihan Keadaan, dan Pengujian Jadual Keputusan, telah dipilih dan dipadankan dengan modul yang bersesuaian.

Matriks kebolehjejakan memastikan bahawa kesemua enam belas Keperluan Fungsian (KF01 hingga KF16) dipetakan kepada sekurang-kurangnya satu kes ujian, tanpa sebarang keperluan yang tertinggal. Sebanyak 24 kes ujian teknikal telah dilaksanakan merangkumi 19 kes ujian fungsian dan 5 kes ujian bukan fungsian, menghasilkan kadar kelulusan keseluruhan sebanyak 91%. Tambahan pula, UAT dijalankan melalui borang soal selidik kepuasan yang melibatkan tiga responden pengguna akhir, mencapai purata kepuasan 4.4 daripada 5.0. Majoriti fungsi sistem beroperasi dengan betul, manakala dua kecacatan pada modul sembang (TC-15) dan paparan ukuran tukang jahit (TC-17) telah dikenal pasti.

Keputusan pengujian membuktikan bahawa sistem secara amnya berfungsi selaras dengan keperluan fungsian dan bukan fungsian yang ditetapkan dalam Bab III, selaras dengan implementasi yang dihuraikan dalam Bab IV. Kesemua keperluan bukan fungsian (KNF1 hingga KNF5) dipenuhi sepenuhnya. Bagi keperluan fungsian, 14 daripada 16 keperluan berjaya disahkan tanpa kecacatan, manakala KF12 dan KF14 memerlukan penambahbaikan berdasarkan keputusan TC-15 dan TC-17. Kejayaan kes ujian negatif (TC-03, TC-09 dan TC-NF03) turut mengesahkan ketahanan sistem terhadap input tidak sah dan cubaan capaian tanpa kebenaran. Keputusan soal selidik UAT mengesahkan bahawa ciri penjejakan status per item dan pengurusan pesanan tukang jahit dinilai sangat positif oleh responden, manakala modul sembang mencatat skor purata terendah iaitu 3.7.

Walaupun kadar kelulusan fungsian (89.5%) tidak mencapai sasaran 95% yang ditetapkan dalam kriteria keluar, kadar kelulusan keseluruhan sebanyak 91% bersama purata kepuasan UAT 4.4/5.0 menunjukkan sistem telah mencapai tahap kebolehgunaan yang memadai untuk operasi sebenar. Sistem disahkan **DITERIMA** untuk penggunaan dengan syarat dua isyu fungsian pada modul chat dan paparan ukuran tukang jahit diperbetulkan pada fasa penambahbaikan seterusnya.
