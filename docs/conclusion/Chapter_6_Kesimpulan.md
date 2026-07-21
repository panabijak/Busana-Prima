# BAB VI: KESIMPULAN

## 6.1 Rumusan Projek

Projek Aplikasi Sokongan Jahitan Pintar (Busana Prima) dibangunkan sebagai respons terhadap cabaran pengurusan tempahan jahitan secara manual dan tidak berpusat yang lazim berlaku dalam perusahaan jahitan kecil dan sederhana (PKS). Sebelum pembangunan sistem ini, interaksi antara pelanggan dan tukang jahit banyak bergantung kepada kehadiran fizikal ke butik, komunikasi tidak tersusun melalui aplikasi pesanan seperti WhatsApp, pengukuran manual yang berisiko ralat, serta kekurangan medium visual untuk menilai hasil akhir pakaian. Keadaan ini turut menyumbang kepada kelewatan penyiapan tempahan, ketidakselarasan maklumat, dan risiko terlepas tarikh penting dalam proses jahitan.

Berdasarkan analisis masalah yang dibentangkan dalam Bab I, pembangunan sistem ini bertujuan mentransformasikan aliran kerja jahitan tempahan daripada proses manual kepada ekosistem digital yang lebih teratur, telus, dan mudah diakses. Melalui integrasi teknologi imbasan badan (Body Scanning) dan visualisasi 2D (AR), sistem ini direka untuk mengurangkan kebergantungan terhadap pengukuran berulang, mempertingkatkan keyakinan pelanggan dalam pemilihan reka bentuk, serta membantu tukang jahit mengurus tempahan dengan lebih sistematik.

Objektif utama projek ialah membangunkan aplikasi Busana Prima bagi meningkatkan kecekapan pengurusan tempahan jahitan dan memperbaiki pengalaman pengguna dalam kalangan pelanggan dan tukang jahit. Bagi mencapai matlamat tersebut, empat objektif khusus telah ditetapkan dan dinilai melalui implementasi sistem serta hasil pengujian yang dibentangkan dalam Bab IV dan Bab V. Pemetaan pencapaian objektif diringkaskan dalam Jadual 6.1.

**Jadual 6.1: Pemetaan Objektif Projek, Implementasi dan Hasil Pengujian**

| Objektif Khusus | Fungsi Sistem Berkaitan | Modul | Bukti Pengujian |
|-----------------|-------------------------|-------|-----------------|
| Objektif 1: Pelanggan dapat membuat tempahan, memilih reka bentuk, memasukkan ukuran badan dan berkomunikasi dengan tukang jahit | Katalog rekaan, Imbasan Badan, Troli, Checkout, Chat | M02, M04, M05, M06, M08 | TC-05 hingga TC-11, TC-15 |
| Objektif 2: Mengurangkan keperluan pengukuran berulang dan ralat pengukuran | Imbasan badan, profil ukuran, validasi julat fisiologi | M04 | TC-08, TC-09 |
| Objektif 3: Membantu pelanggan menilai dan memilih reka bentuk dengan lebih yakin | Visualisasi 2D AR (Virtual Try-On) | M03 | TC-07 |
| Objektif 4: Tukang jahit dapat mengurus dan memantau setiap tempahan dengan lebih teratur | Pengurusan tempahan, kemas kini status, rekod tempahan | M07 | TC-13, TC-17, TC-18, TC-19 |

Secara keseluruhan, sistem yang dibangunkan merangkumi sembilan modul fungsi utama yang meliputi autentikasi pengguna, katalog produk, visualisasi 2D AR, pengukuran badan digital, troli belian, proses checkout dan tempahan, pengurusan tempahan, komunikasi masa nyata, serta pengurusan profil dan alamat penghantaran. Setiap modul ini direalisasikan melalui seni bina Model-View-ViewModel (MVVM) yang dilaksanakan dalam corak tiga lapisan (three-tier architecture), iaitu lapisan persembahan (Flutter Widgets), lapisan logik perniagaan (Riverpod Providers), dan lapisan akses data (Firebase Services).

Dari segi teknologi, projek ini menggunakan Flutter SDK dengan bahasa pengaturcaraan Dart sebagai platform pembangunan aplikasi mudah alih. Perkhidmatan backend disokong oleh Firebase yang merangkumi Firebase Authentication untuk pengesahan pengguna, Cloud Firestore sebagai pangkalan data masa nyata, Firebase Storage untuk penyimpanan fail media, serta Firebase Cloud Messaging (FCM) bagi penghantaran notifikasi. Modul Imbasan Badan mengintegrasikan Google ML Kit Pose Detection dan kamera peranti untuk pengiraan ukuran badan, manakala modul Visualisasi 2D AR menggunakan teknik tindanan (overlay) garmen secara masa nyata. Pengurusan state aplikasi dilaksanakan melalui flutter_riverpod, manakala navigasi antara skrin diuruskan menggunakan go_router.

Kaedah pembangunan sistem mengguna pakai pendekatan feature-first architecture di mana setiap modul fungsi diasingkan mengikut domain perniagaan di bawah direktori `lib/features/`. Pendekatan ini memudahkan penyelenggaraan kod, pengembangan modular, serta pemetaan keperluan fungsian kepada implementasi sebenar. Pangkalan data Firestore direka dengan koleksi utama dan subkoleksi yang menyokong aliran perniagaan jahitan tempahan, termasuk pengurusan profil pengguna, item troli, profil ukuran, rekod tempahan, perbualan, dan notifikasi.

Dari segi pencapaian, sistem berjaya menyelesaikan lima isu utama yang dikenal pasti dalam pernyataan masalah. Pertama, keperluan pelanggan hadir secara fizikal hanya untuk melihat katalog dan membuat tempahan dapat dikurangkan melalui modul katalog digital dan proses checkout dalam aplikasi. Kedua, komunikasi tidak tersusur melalui WhatsApp dapat digantikan dengan modul chat berstruktur yang dikaitkan terus dengan rekod tempahan. Ketiga, ralat pengukuran manual dapat diminimumkan melalui modul Imbasan Badan yang menyimpan profil ukuran pelanggan untuk kegunaan semula. Keempat, kekurangan medium visual untuk menilai reka bentuk dapat diatasi melalui ciri Virtual Try-On 2D AR. Kelima, risiko kelewatan dan keciciran tempahan dapat dikurangkan melalui aliran kerja jahitan (workflow) yang membenarkan tukang jahit mengemas kini status setiap item dan pelanggan menjejak kemajuan secara masa nyata.

Keberkesanan sistem ini disahkan melalui aktiviti pengujian sistem yang dibentangkan dalam Bab V. Sebanyak 24 kes ujian telah dilaksanakan, merangkumi 19 kes ujian fungsian dan 5 kes ujian bukan fungsian. Sistem mencapai kadar kelulusan keseluruhan sebanyak 91%, dengan 22 kes ujian berstatus BERJAYA dan 2 kes ujian berstatus TIDAK BERJAYA (TC-15 dan TC-17). Kesemua lima Keperluan Bukan Fungsian (KNF1 hingga KNF5) berjaya dipenuhi sepenuhnya. Bagi keperluan fungsian, 17 daripada 19 kes ujian berjaya, menunjukkan majoriti fungsi sistem beroperasi dengan betul walaupun terdapat dua kecacatan pada modul chat dan paparan ukuran tukang jahit yang memerlukan penambahbaikan.

Berdasarkan hubungan antara objektif projek, implementasi sistem, dan hasil pengujian, dapat dirumuskan bahawa keempat-empat objektif khusus projek telah pada amnya berjaya dicapai, walaupun terdapat dua isyu fungsian yang dikenal pasti semasa pengujian. Objektif pertama tercapai apabila pelanggan dapat menyelesaikan aliran lengkap daripada pemilihan reka bentuk, pengukuran badan, pembuatan tempahan, hingga komunikasi dengan tukang jahit melalui satu platform bersepadu. Objektif kedua tercapai apabila profil ukuran digital dapat dijana, disimpan, dan digunakan semula tanpa pengukuran manual berulang, disokong oleh validasi julat fisiologi yang mengurangkan risiko ralat. Objektif ketiga tercapai apabila ciri Virtual Try-On membolehkan pelanggan memvisualisasikan reka bentuk pakaian sebelum membuat keputusan tempahan. Objektif keempat sebahagian besarnya tercapai apabila tukang jahit dapat mengakses rekod tempahan, mengemas kini status mengikut aliran kerja jahitan, dan memantau kemajuan tempahan secara teratur, walaupun paparan maklumat ukuran pelanggan pada skrin perincian tempahan masih memerlukan penambahbaikan (TC-17).

Secara keseluruhan, projek Aplikasi Sokongan Jahitan Pintar telah berjaya direalisasikan sebagai sistem sokongan jahitan digital yang praktikal untuk perusahaan jahitan kecil dan sederhana. Sistem ini bukan sekadar memenuhi keperluan fungsian yang ditetapkan, tetapi turut menunjukkan keupayaan untuk mentransformasikan proses pengurusan tempahan jahitan daripada kaedah manual kepada pendekatan digital yang lebih cekap, telus, dan mesra pengguna. Pencapaian ini memberikan asas kukuh bagi penambahbaikan dan pengembangan sistem pada masa hadapan, seperti yang akan dibincangkan dalam bahagian seterusnya.

---

## 6.2 Kekuatan dan Kekangan Sistem

Bahagian ini membincangkan kekuatan dan kekangan sistem yang dikenal pasti berdasarkan implementasi sebenar dalam Bab IV serta hasil pengujian dalam Bab V. Analisis ini bertujuan memberikan penilaian yang seimbang dan kritikal terhadap pencapaian projek, tanpa mengabaikan aspek yang memerlukan penambahbaikan.

### a. Kekuatan Sistem

Projek Aplikasi Sokongan Jahitan Pintar menunjukkan beberapa kekuatan utama yang menyokong pencapaian objektif projek dan keberkesanan sistem dalam konteks operasi jahitan tempahan.

**Pembangunan Aplikasi Mudah Alih Berasaskan Flutter.** Penggunaan Flutter SDK dengan bahasa Dart membolehkan pembangunan aplikasi mudah alih dalam satu kod sumber (single codebase). Pendekatan ini mempercepatkan proses pembangunan dan memastikan konsistensi antara muka serta tingkah laku aplikasi merentasi peranti Android yang disokong. Kekuatan ini menyokong objektif peningkatan kecekapan pengurusan tempahan kerana fungsi utama dapat diakses oleh pelanggan dan tukang jahit melalui peranti mudah alih tanpa kebergantungan kepada kehadiran fizikal di butik.

**Integrasi Firebase sebagai Platform Backend.** Firebase menyediakan infrastruktur backend yang mantap meliputi pengesahan pengguna (Authentication), pangkalan data masa nyata (Cloud Firestore), penyimpanan fail (Storage), dan notifikasi (Cloud Messaging). Penyegerakan data secara masa nyata membolehkan kemas kini status tempahan dipantau serta-merta oleh pelanggan, seperti yang disahkan melalui TC-13. Kekuatan ini turut menyokong objektif pengurusan tempahan yang lebih teratur kerana data kekal konsisten dan boleh diakses oleh kedua-dua aktor tanpa kehilangan maklumat, sebagaimana dibuktikan dalam TC-NF04.

**Modul Imbasan Badan Berasaskan ML Kit.** Modul Imbasan Badan mengintegrasikan Google ML Kit Pose Detection dan kamera peranti untuk mengira ukuran badan pelanggan secara digital. Profil ukuran dapat disimpan dan digunakan semula untuk tempahan akan datang, sekali gus mengurangkan keperluan pengukuran manual berulang. Validasi julat fisiologi dalam `RangeValidator` pula memastikan nilai ukuran yang dijana berada dalam julat yang munasabah. Kekuatan ini secara langsung menyokong objektif kedua projek, iaitu mengurangkan ralat pengukuran, sebagaimana dibuktikan melalui TC-08 dan TC-09.

**Visualisasi 2D AR (Virtual Try-On).** Ciri Virtual Try-On membolehkan pelanggan memvisualisasikan reka bentuk pakaian secara maya melalui teknik tindanan (overlay) garmen 2D pada imej badan secara masa nyata. Walaupun ia bukan simulasi tiga dimensi (3D), ciri ini memberikan nilai tambah yang signifikan berbanding lakaran atau gambar statik sahaja. Kekuatan ini menyokong objektif ketiga projek dengan membantu pelanggan menilai dan memilih reka bentuk dengan lebih yakin sebelum membuat tempahan, sebagaimana dibuktikan melalui TC-07 dan TC-NF02.

**Aliran Kerja Jahitan (Workflow) Berstruktur.** Sistem mengimplementasikan aliran kerja jahitan yang jelas melalui status item (`ItemStatus`) iaitu Menunggu Kain, Pemotongan, Jahitan, Pemeriksaan Kualiti, Siap, dan sebagainya. Tukang jahit dapat mengemas kini status setiap item mengikut peringkat proses, manakala pelanggan dapat menjejak kemajuan secara masa nyata. Kekuatan ini menyokong objektif keempat projek dengan mengurangkan risiko keciciran dan kelewatan tempahan, sebagaimana dibuktikan melalui TC-18 dan TC-19.

**Seni Bina MVVM dan Three-Tier Architecture.** Penggunaan seni bina Model-View-ViewModel (MVVM) yang dilaksanakan melalui corak tiga lapisan memisahkan tanggungjawab antara lapisan persembahan (Flutter Widgets), lapisan logik perniagaan (Riverpod Providers), dan lapisan akses data (Firebase Services). Pendekatan feature-first architecture di bawah direktori `lib/features/` pula memudahkan penyelenggaraan kod dan pengembangan modular. Kekuatan seni bina ini menyokong kelestarian sistem jangka panjang dan memudahkan penambahbaikan fungsi pada masa hadapan.

**Keselamatan Berasaskan Peranan.** Peraturan keselamatan Firestore (`firestore.rules`) melaksanakan kawalan akses berasaskan peranan (role-based access control) yang membezakan kebenaran antara pelanggan dan tukang jahit. Cubaan capaian tanpa kebenaran ditolak dengan sewajarnya, sebagaimana dibuktikan melalui TC-NF03. Kekuatan ini melindungi data pelanggan dan memastikan hanya pengguna yang dibenarkan dapat mengakses atau mengubah rekod sensitif.

**Kebolehgunaan Antara Muka.** Hasil pengujian menunjukkan aliran tempahan dapat diselesaikan dalam empat langkah utama tanpa bantuan (TC-NF01), manakala antara muka dianggap mesra pengguna oleh kedua-dua aktor. Kekuatan ini menyokong objektif peningkatan pengalaman pengguna dan memastikan sistem dapat digunakan oleh pengguna dengan literasi digital asas.

### b. Kekangan Sistem

Walaupun sistem menunjukkan pencapaian yang memuaskan, terdapat beberapa kekangan yang perlu diakui secara profesional berdasarkan skop projek, had teknologi, dan hasil pengujian sebenar.

**Ketepatan Imbasan Badan Bergantung kepada Persekitaran Pengimbasan.** Ketepatan ukuran yang dijana oleh modul Imbasan Badan bergantung kepada faktor persekitaran seperti pencahayaan, kedudukan badan pengguna, kualiti kamera, dan kejayaan proses kalibrasi. Walaupun sistem menyediakan skor keyakinan (confidence score) dan validasi julat fisiologi, ukuran digital masih tidak dapat menandingi ketepatan pengukuran manual oleh tukang jahit berpengalaman dalam semua keadaan. Kekangan ini perlu dipertimbangkan oleh pengguna apabila menggunakan profil ukuran untuk tempahan.

**Kecacatan pada Modul Chat (TC-15).** Hasil pengujian mengenal pasti kegagalan sistem menandakan mesej sebagai belum dibaca (`unreadCount`) kepada tukang jahit walaupun mesej berjaya dihantar dan dipaparkan. Kekangan ini menjejaskan Keperluan Fungsian KF12 (Mula Perbualan) dan boleh menyebabkan tukang jahit tidak menyedari mesej baharu daripada pelanggan tanpa membuka skrin perbualan secara manual.

**Kecacatan pada Paparan Ukuran Tukang Jahit (TC-17).** Hasil pengujian turut mendapati maklumat ukuran pelanggan tidak dipaparkan pada skrin perincian tempahan tukang jahit, walaupun rekod tempahan dapat diakses. Kekangan ini menjejaskan Keperluan Fungsian KF14 (Lihat Perincian Tempahan) dan boleh menambah beban kerja tukang jahit yang perlu mencari maklumat ukuran melalui saluran lain.

**Prestasi AR Bergantung kepada Spesifikasi Peranti.** Visualisasi 2D AR memerlukan pemprosesan kamera dan pengesanan pose secara masa nyata. Prestasi tindanan garmen boleh terjejas pada peranti dengan spesifikasi rendah atau dalam keadaan pencahayaan kurang optimum. Walaupun TC-NF02 menunjukkan prestasi memuaskan pada peranti ujian, kekangan ini mungkin lebih ketara pada peranti lama atau berspesifikasi rendah.

**Kebergantungan kepada Sambungan Internet.** Sistem memerlukan sambungan Internet yang aktif untuk mengakses perkhidmatan Firebase, termasuk pengesahan pengguna, penyimpanan data, dan penyegerakan masa nyata. Fungsi utama seperti pelayaran katalog, pembuatan tempahan, dan penjejakan status tidak dapat beroperasi sepenuhnya dalam mod luar talian (offline). Kekangan ini menjadi isu dalam kawasan dengan liputan rangkaian yang lemah.

**Sokongan Platform Terhad kepada Android.** Projek ini dibangunkan dan diuji khusus untuk platform Android (versi 11 dan 13). Walaupun Flutter menyokong pembangunan cross-platform, versi iOS atau Web tidak diimplementasikan dalam skop projek ini. Kekangan ini mengehadkan capaian sistem kepada pengguna Android sahaja.

**Pengurusan Katalog Melalui Rowy.** Pengurusan katalog produk, kategori, dan banner promosi dilakukan melalui platform Rowy (admin CMS) dan bukan secara langsung dalam aplikasi mudah alih. Tukang jahit perlu mengakses Rowy secara berasingan untuk menambah atau mengemas kini reka bentuk pakaian. Kekangan ini selaras dengan skop projek yang memfokuskan aplikasi mudah alih kepada pelanggan dan tukang jahit, tetapi mengehadkan kemudahan pengurusan katalog dalam satu platform.

**Fungsi AR Tidak Menyokong Semua Jenis Pakaian.** Ciri Virtual Try-On hanya tersedia untuk produk yang mempunyai imej garmen lut sinar (`transparentUrl`). Produk tanpa imej tersebut tidak menyokong ciri try-on. Kekangan ini mengehadkan liputan visualisasi AR kepada reka bentuk tertentu sahaja.

**Tiada Integrasi Pembayaran Sebenar.** Sistem mengimplementasikan simulasi pembayaran untuk tujuan demonstrasi FYP dan tidak mengintegrasikan gerbang pembayaran (payment gateway) sebenar. Kekangan ini selaras dengan skop projek yang tidak melibatkan integrasi pembayaran pihak ketiga, tetapi mengehadkan kelengkapan aliran e-dagang.

**Skop Terhad kepada Perusahaan Jahitan Tunggal (PKS).** Sistem direka untuk satu premis jahitan dan tidak menyokong pengurusan berbilang cawangan, berbilang tukang jahit, atau pengurusan pekerja yang kompleks. Kekangan ini selaras dengan skop projek yang memfokuskan perusahaan jahitan kecil dan sederhana.

**Bilangan Responden Ujian Terhad.** Pengujian sistem dan UAT dijalankan dalam skop terhad dengan bilangan peranti dan pengguna ujian yang tidak besar. Walaupun kadar kelulusan mencapai 91%, keputusan ini mungkin tidak mencerminkan sepenuhnya pengalaman pengguna dalam persekitaran operasi sebenar dengan volum tempahan yang lebih tinggi.

---

## 6.3 Cadangan Penambahbaikan Kajian Masa Hadapan

Berdasarkan kekuatan dan kekangan yang dikenal pasti, serta hasil pengujian yang menunjukkan kadar kelulusan 91% dengan dua kecacatan fungsian, beberapa cadangan penambahbaikan dicadangkan bagi meningkatkan kualiti dan kebolehgunaan sistem pada masa hadapan. Cadangan ini dikelompokkan mengikut aspek fungsi, teknologi, infrastruktur, dan kajian lanjutan.

### a. Penambahbaikan Fungsi

**Pembetulan Kecacatan TC-15 dan TC-17.** Keutamaan tertinggi ialah memperbetulkan dua kecacatan yang dikenal pasti semasa pengujian. Bagi TC-15, logik kemas kini medan `unreadCount` dalam koleksi `conversations` perlu disemak semula supaya mesej baharu ditandakan sebagai belum dibaca kepada penerima. Bagi TC-17, skrin perincian tempahan tukang jahit perlu diperluaskan untuk memaparkan maklumat ukuran pelanggan yang dirujuk melalui `measurementProfileId` pada setiap item tempahan.

**Integrasi Pembayaran Dalam Aplikasi.** Sistem boleh diperluaskan dengan mengintegrasikan gerbang pembayaran tempatan seperti FPX, DuitNow, atau Touch 'n Go eWallet bagi membolehkan pelanggan membuat bayaran deposit atau bayaran penuh secara dalam talian. Penambahbaikan ini akan melengkapkan aliran tempahan hujung-ke-hujung tanpa memerlukan pengesahan bayaran manual.

**Pengurusan Katalog Terus dalam Aplikasi.** Pengurusan katalog produk, kategori, dan banner promosi boleh dipindahkan daripada Rowy ke dalam aplikasi mudah alih itu sendiri, membolehkan tukang jahit menambah, mengemas kini, dan menyahaktifkan reka bentuk pakaian tanpa mengakses platform berasingan.

**Dashboard Analitik untuk Tukang Jahit.** Modul dashboard boleh ditambah untuk memaparkan statistik perniagaan seperti bilangan tempahan aktif, tempahan tertunggak, anggaran hasil mingguan, dan purata masa penyiapan. Dashboard ini dapat membantu tukang jahit merancang beban kerja dan mengurangkan risiko kelewatan.

**Sokongan Berbilang Bahasa.** Antara muka aplikasi boleh dilokalisasikan untuk menyokong Bahasa Melayu dan Bahasa Inggeris, atau bahasa tambahan seperti Bahasa Arab, bagi memperluas capaian kepada pelanggan dari pelbagai latar belakang.

**Notifikasi Pintar Berasaskan Konteks.** Sistem notifikasi boleh dipertingkatkan untuk menghantar peringatan automatik berdasarkan konteks tempahan, contohnya peringatan serahan kain, kemas kini status jahitan, atau mesej belum dibaca daripada pelanggan.

### b. Penambahbaikan Teknologi

**Peningkatan Ketepatan Imbasan Badan.** Ketepatan modul Imbasan Badan boleh dipertingkatkan melalui integrasi sensor kedalaman (depth camera) atau teknologi LiDAR pada peranti yang menyokongnya. Selain itu, algoritma pengiraan ukuran boleh dikalibrasi semula berdasarkan data antropometrik populasi tempatan untuk meningkatkan ketepatan.

**Sistem Cadangan Saiz Berasaskan Kecerdasan Buatan (AI).** Model pembelajaran mesin boleh dilatih untuk mencadangkan saiz pakaian optimum berdasarkan profil ukuran pelanggan dan jenis reka bentuk yang dipilih, mengurangkan kebergantungan kepada input manual pelanggan.

**Virtual Try-On Berasaskan AI.** Ciri Virtual Try-On boleh ditingkatkan daripada tindanan 2D kepada simulasi berasaskan AI yang lebih realistik, termasuk penyesuaian tekstur kain, lipatan semula jadi, dan penyesuaian mengikut bentuk badan yang lebih tepat.

**Peningkatan Computer Vision.** Integrasi model computer vision yang lebih maju, seperti segmentasi badan penuh (full-body segmentation) dan pengesanan pose multi-sudut, boleh meningkatkan ketepatan ukuran dan kualiti visualisasi AR.

**Sistem Cadangan Reka Bentuk (Recommendation System).** Enjin cadangan boleh ditambah untuk memaparkan reka bentuk pakaian yang relevan berdasarkan sejarah tempahan, profil ukuran, dan pilihan pelanggan, serupa dengan pendekatan e-dagang moden.

### c. Penambahbaikan Infrastruktur

**Sokongan Platform iOS.** Aplikasi boleh diport ke platform iOS memanfaatkan keupayaan cross-platform Flutter, memperluas capaian kepada pengguna iPhone dan iPad.

**Penyegerakan Luar Talian (Offline Synchronisation).** Mekanisme cache tempatan boleh ditambah untuk membolehkan pelanggan melihat katalog, profil ukuran, dan sejarah tempahan tanpa sambungan Internet. Data akan disegerakkan secara automatik apabila sambungan dipulihkan.

**Cloud Functions untuk Automasi Proses.** Firebase Cloud Functions boleh digunakan untuk mengautomasikan tugasan seperti penghantaran notifikasi status tempahan, pengiraan harga dinamik, penjanaan nombor tempahan, dan pencucian data sementara.

**Penambahbaikan Keselamatan Data.** Penyulitan data tambahan boleh dilaksanakan pada medan sensitif seperti profil ukuran dan maklumat peribadi pelanggan. Audit log boleh ditambah untuk merekod aktiviti capaian data oleh tukang jahit.

**Migrasi kepada Seni Bina Microservices (Jangka Panjang).** Bagi skala yang lebih besar, komponen backend boleh dipisahkan kepada perkhidmatan mikro (microservices) yang berdiri sendiri, contohnya perkhidmatan tempahan, perkhidmatan ukuran, dan perkhidmatan notifikasi, bagi meningkatkan skalabiliti dan ketahanan sistem.

### d. Penambahbaikan Kajian

**Kajian Keberkesanan dengan Sampel Pengguna yang Lebih Besar.** Kajian lanjutan boleh dijalankan dengan melibatkan lebih ramai pelanggan dan tukang jahit dari pelbagai premis jahitan untuk menilai kebolehgunaan dan keberkesanan sistem dalam persekitaran operasi sebenar.

**Perbandingan Ketepatan Imbasan Badan dengan Pengukuran Manual.** Kajian perbandingan boleh dijalankan untuk mengukur perbezaan ketepatan antara ukuran digital (Imbasan Badan) dengan ukuran manual oleh tukang jahit, bagi menentukan faktor penentukur (calibration factor) yang sesuai untuk populasi tempatan.

**Penilaian Impak terhadap Produktiviti dan Kepuasan Pelanggan.** Kajian jangka panjang boleh menilai sama ada penggunaan sistem ini benar-benar mengurangkan kehadiran fizikal pelanggan, mempercepatkan proses tempahan, dan meningkatkan kepuasan pelanggan serta produktiviti tukang jahit.

**Kajian Perbandingan dengan Sistem Jahitan Komersial.** Perbandingan boleh dijalankan antara Aplikasi Sokongan Jahitan Pintar dengan platform jahitan komersial sedia ada untuk mengenal pasti kelebihan, kekurangan, dan peluang penambahbaikan.

**Ujian Prestasi pada Peranti Pelbagai Spesifikasi.** Kajian prestasi yang lebih menyeluruh boleh dijalankan merentasi pelbagai model dan spesifikasi peranti Android untuk mengenal pasti had minimum peranti yang disyorkan bagi penggunaan modul Imbasan Badan dan Visualisasi AR.

---

## 6.4 Rumusan Akhir

Projek Aplikasi Sokongan Jahitan Pintar (Busana Prima) telah berjaya membangunkan sistem sokongan jahitan digital yang praktikal untuk perusahaan jahitan kecil dan sederhana di Malaysia. Sistem ini menyelesaikan cabaran utama dalam pengurusan tempahan jahitan manual melalui digitalisasi katalog rekaan, pengukuran badan, visualisasi pakaian, komunikasi berstruktur, dan penjejakan status tempahan secara masa nyata.

Dari segi pencapaian objektif, keempat-empat objektif khusus projek telah pada amnya dicapai, disokong oleh kadar kelulusan pengujian sebanyak 91% dan pemenuhan sepenuhnya keperluan bukan fungsian. Dua kecacatan fungsian yang dikenal pasti (TC-15 dan TC-17) tidak menafikan nilai keseluruhan sistem, tetapi menandakan ruang penambahbaikan yang jelas untuk fasa seterusnya.

Dari segi impak, sistem ini memberikan manfaat kepada pelanggan melalui kemudahan membuat tempahan, mengukur badan, dan memvisualisasikan pakaian tanpa kehadiran fizikal yang kerap. Bagi tukang jahit pula, sistem ini menyediakan platform terpusat untuk mengurus tempahan, mengemas kini status jahitan, dan berkomunikasi dengan pelanggan secara lebih teratur. Secara keseluruhan, projek ini menyumbang kepada usaha pendigitalan industri jahitan tempahan di Malaysia, khususnya dalam kalangan perusahaan kecil dan sederhana yang masih bergantung kepada kaedah manual.

Potensi pengembangan sistem pada masa hadapan adalah besar, merangkumi penambahbaikan fungsi, teknologi, infrastruktur, dan kajian lanjutan seperti yang dibincangkan dalam Bahagian 6.3. Dengan pembetulan kecacatan sedia ada dan pelaksanaan cadangan penambahbaikan secara berperingkat, sistem ini berpotensi menjadi penyelesaian digital yang lebih lengkap dan mantap untuk industri jahitan tempahan di Malaysia.
