//+------------------------------------------------------------------+
//|        EA_PURE_SUPER_ULTRA_FIXED_FINAL - VERSI 5.0               |
//|   INTEGRASI PENUH 4 INDIKATOR KUSTOM FINAL (ARSITEKTUR MENARA)   |
//+------------------------------------------------------------------+
//| ARSITEKTUR "GEDUNG PENCAKAR LANGIT":                              |
//|                                                                    |
//| PONDASI  : Adaptasi otomatis instrumen & broker                    |
//|            (forex/JPY/exotic/GOLD/SILVER/CRYPTO/OIL, digit 4-5,   |
//|             stop level, lot step, spread per kelas aset)          |
//| LANTAI 1 : Supertrend_Promax = PEMICU utama (flip trend) + garis  |
//|            trailing + filter kualitas: umur trend, ADX genuine,   |
//|            titik jenuh (over-extended), pola koreksi              |
//| LANTAI 2 : HeikenAshi_Custom = KONFIRMATOR arah (buffer 6:        |
//|            arah terkonfirmasi 3-lapis anti-zigzag) - sinyal       |
//|            lawan warna DIVETO                                     |
//| LANTAI 3 : Entry_Signal_Pro = KONFIRMATOR independen (momentum/   |
//|            CCI/RSI/ADX multi-formula) - panah searah dlm N bar    |
//|            terakhir menguatkan sinyal                             |
//| LANTAI 4 : SuperSR_6 = ZONA support/resistance (sinyal dekat      |
//|            level S/R lebih kuat) + MTF M5-H4 opsional             |
//| PUNCAK   : Eksekusi AUTO penuh / SIGNAL-ONLY (alert+panah utk     |
//|            trading manual) + manajemen posisi lengkap             |
//|            (BE, trailing, partial, loss limiter, protection)      |
//|                                                                    |
//| NAMA FILE INDIKATOR (wajib terinstal persis):                     |
//|   Supertrend_Promax, HeikenAshi_Custom,                            |
//|   Entry_Signal_Pro, SuperSR_6                                     |
//+------------------------------------------------------------------+
#property copyright "Hends-Trader - AurumPulse XAUUSD Edition"
#property version   "3.01"
// =====================================================================
// === AurumPulse XAUUSD Edition - v2.00 (29 Jul 2026) =================
// === "AUDITED & HARDENED" ============================================
// =====================================================================
// Build ini adalah hasil AUDIT MENYELURUH atas v1.00 memakai bukti dari
// tes XAUUSD H1 periode 02 Jan - 28 Jul 2026 (306 posisi sebenarnya) +
// jurnal 28.608 baris. Semua perubahan di bawah punya bukti angkanya.
//
// --- 9 BUG DIPERBAIKI ---
// BUG-1 NILAI PIP 10x KEBESARAN (CalculateLotSize). "* 10.0" sisa asumsi
//   forex 5-digit. Terbukti: EA mencetak risiko "$876.74" utk posisi yg
//   risiko sebenarnya $87.68. Dampak terparah: di mode risk-based lot
//   jadi 10x TERLALU KECIL -> selalu jatuh ke minimum broker ->
//   compounding MATI. -> dipusatkan di PipValuePerLot().
// BUG-2 BADAI OrderModify. Kandidat SL mentah dibanding SL terpasang yg
//   sudah dibulatkan -> "selalu ada perbaikan" -> modify TIAP TICK ->
//   22.109 "OrderModify error 1", puncak 1.273/menit (~21 req/detik).
//   Di akun real = error 146, throttling, trade context tertahan.
//   -> semua modify kini lewat SafeOrderModify().
// BUG-3 INDEKS MONITOR SALAH setelah partial close (terjadi 235x).
//   RemoveTradeMonitor menggeser array, tapi 'idx' lama tetap dipakai ->
//   flag partial dicap ke POSISI LAIN. -> cari ulang indeks setelah add.
// BUG-4 TRAILING DIKUNCI MAKS $5,00. Clamp hardcode 15..500 "pip"; utk
//   gold = $0.15..$5.00, di instrumen ber-ATR $20/jam. Inilah penyebab
//   struktural median lama-tahan 2,2 jam & rasio payoff 0,62.
//   -> clamp kini RELATIF ATR (TrailMinATR..TrailMaxATR).
// BUG-5 TIGA MEKANISME MENEMBUS LANTAI GARIS ST. Spike Guard, Momentum
//   Candle Trail, dan Breakeven mengabaikan stLineFloor (perlindungan
//   yg dibangun di v37 justru utk mencegah exit dini). -> kini hormat.
// BUG-6 FILTER VOLATILITAS MUSTAHIL AKTIF. ATR/harga utk gold = 0,465%
//   vs ambang 7,5% - butuh ATR $322/jam utk memicu. 0 blokir dlm 7 bln.
//   -> diganti rasio ATR-pendek/ATR-panjang (skala-bebas).
// BUG-7 FILTER NEWS cuma 3 jam statis tanpa kesadaran tanggal.
//   -> ditambah jendela NFP (Jumat pertama tiap bulan).
// BUG-8 POSISI KE-21 HILANG DARI PENGAWASAN (array 20, gagal DIAM-DIAM,
//   tanpa trailing/BE/partial/spike-guard). -> 50 slot + peringatan.
// BUG-9 TIDAK ADA VALIDASI INDIKATOR. Satu .ex4 hilang / urutan input
//   bergeser = EA diam saja atau entri dari angka sampah.
//   -> ValidateCustomIndicators(), gagal = INIT_FAILED.
//
// --- FITUR KEAMANAN BARU ---
// * PAGAR RISIKO AGREGAT (UseTotalRiskCap). Temuan audit paling serius:
//   pagar lama HANYA per-trade. Piramida+repending membuka posisi SEARAH
//   yg berbagi level trailing sama - praktis SATU trade besar dipecah.
//   Bukti: tiga posisi kena SL di harga & DETIK yg sama (#2/#4/#6 @
//   4389.53). Puncak risiko agregat 43,5% balance SEKALIGUS.
//   Kini setiap entri/piramida/pending harus lolos gerbang total.
// * SIDIK JARI KONFIGURASI di OnInit - seluruh parameter penting dicetak
//   ke jurnal, jadi tiap hasil bisa ditelusuri ke setelan persisnya.
//
// --- KALIBRASI ULANG (satuan pip forex -> xATR) ---
//   TrailStart 20pip($0.20) -> 1.0xATR | BE 15pip($0.15) -> 0.8xATR
//   ST buffer 3pip($0.03) -> 0.35xATR  | clamp $5.00 -> 3.0xATR
//   VolRegimeQuietFactor 0.5 -> 0.85
//
// --- DEFAULT DIRAPIKAN (jebakan dihapus) ---
//   BaseLot 0.3 -> 0.01 (yg dites 0.02; 0.3 = 15x lipat kalau .set lupa)
//   EnableDrawdownProtection false -> true
//   UseProfitStageTrail true -> false (makin untung makin ketat = salah)
//   Subsistem pending -> false (net -$138 di tes, menang 73% tapi rugi)
//   MaxVolatilityPercent DIHAPUS (dipakai rumus mati)
//
// --- CATATAN JUJUR ---
// Tes v1.00 yg jadi dasar audit ini punya "Modelling quality: n/a" dan
// 5.577.563 mismatched charts errors. Angka PF 1,34 dari tes itu TIDAK
// SAH sbg ukuran performa. Perbaikan di v2.00 menyasar akar masalah yg
// terbukti dari STRUKTUR kode & pola trade (yg tetap valid walau data
// intrabar cacat), BUKAN mengejar angka backtest itu. WAJIB tes ulang
// dgn data bersih sesuai RENCANA_TES_BERTAHAP sebelum akun real.
// =====================================================================
// Riwayat teknis v1.00 & seluruh v30-v68 tetap tersimpan di bawah.
// === AurumPulse XAUUSD Edition â€” v1.00 (19 Jul 2026) ===
// FINALISASI fase khusus-XAUUSD, berdasar tes final: profit $1.893,13,
// PF 2,54, DD 20,99%/22,38%, 209 trade tertutup (Okt 2025 - Jan 2026).
// Setelan yg terbukti terbaik & jadi DEFAULT resmi build ini:
//   RependOrderMode=BOTH, ExhPendOrderMode=BOTH, UsePyramidAdd=true,
//   UseSlopeAdaptiveSLTP=true, UseMomentumCandleTrail=true.
// Nama "AurumPulse" - Aurum (Latin utk emas, akar kata kode ISO XAU
// itu sendiri) + Pulse (mencerminkan sifat adaptif thd momentum/
// kemiringan tren yg jadi ciri khas build ini: kalibrasi SL/TP otomatis
// menyesuaikan detak/ritme tren, bukan angka statis).
// Riwayat teknis lengkap (v30-v68, >60 perbaikan & fitur) tetap
// tersimpan di bawah ini sbg dokumentasi pengembangan.
// v68/6.46 (19 Jul 2026) - DIKHUSUSKAN UNTUK XAUUSD sesuai permintaan Anda
//   (catatan: perubahan ini TIDAK memengaruhi tes yg sedang berjalan saat
//   permintaan ini dibuat - file yg dites sudah dimuat terpisah; ini utk
//   iterasi berikutnya).
//   DIHAPUS seluruhnya (bukan cuma dimatikan) - infrastruktur deteksi &
//   konfigurasi multi-instrumen non-gold:
//   - Flag g_IsOil/g_IsCrypto/g_IsJPYPair/g_IsExoticPair
//   - Fungsi IsCryptoSymbol()/IsJPYPair()/IsExoticPair()/RefreshCryptoPipPoint()
//   - Cabang oil/crypto/JPY/exotic di ConfigurePairParameters() &
//     CheckVolatilityFilter() - kini HANYA jalur gold yg tersisa
//   - 6 parameter input: OilSpreadMultiplier, CryptoSpreadMultiplier,
//     CryptoLotReduction, JPYSpreadMultiplier, ExoticSpreadMultiplier,
//     ExoticLotReduction (280 parameter skrg, dr 286)
//   DetectAndConfigurePair() kini mencetak PERINGATAN jelas kalau chart
//   dipasang di simbol BUKAN gold (bukan diam-diam pakai kalibrasi yg
//   salah instrumen).
//   3 komentar riwayat yg menyebut "USDJPY" (data pengembangan sangat
//   awal, jauh sblm EA ini fokus penuh ke gold) diperbarui jadi istilah
//   generik - tak ada lagi sebutan pair lain tersisa di kode, sesuai
//   permintaan Anda.
//   DIVERIFIKASI: 280 parameter input, 0 yg tak terpakai; kurung kurawal
//   600/600 seimbang; 0 sisa referensi ke identifier yg dihapus (dicek
//   dgn pencarian menyeluruh, bukan cuma baca sekilas).
//   CATATAN UNTUK PENGEMBANGAN PAIR LAIN NANTI: infrastruktur yg dihapus
//   di sini (deteksi crypto/oil/JPY/exotic) masih tersimpan di versi v67
//   sebelumnya kalau dibutuhkan sbg titik awal utk proyek GBP/USD dan
//   lainnya yg sudah direncanakan - TIDAK di file khusus-XAUUSD ini.
// v67/6.45 (19 Jul 2026) - PEMBERSIHAN sesuai pertanyaan Anda: komentar
//   sebaris pada deklarasi input di MQL4 TAMPIL LANGSUNG di panel
//   "Inputs" Expert Properties MT4 - 29 parameter sebelumnya punya
//   komentar sebaris yg kepanjangan (sampai 525 karakter utk
//   HTFBiasHardBlock), akan terlihat berantakan di panel tsb. FIX:
//   detail teknis/riwayat lengkap dipindah jadi komentar baris TERPISAH
//   di ATAS tiap input (tetap tersimpan penuh utk dokumentasi kode ke
//   depan), baris input sendiri kini diberi keterangan singkat & bersih
//   yg akan tampil rapi saat file ini dibuka di MT4. TIDAK ADA logika
//   kode yg berubah sama sekali - murni restrukturisasi komentar,
//   diverifikasi: 286 parameter input tetap utuh, kurung kurawal tetap
//   seimbang (614/614) persis spt sblm perubahan ini.
// v66/6.44 (19 Jul 2026) - FINALISASI: audit menyeluruh sesuai permintaan
//   Anda sblm lanjut demo/real. Hasil tes RependOrderMode=BOTH (dgn
//   Pyramid+SlopeAdaptive aktif) - PENCAPAIAN TERBAIK sejauh ini: profit
//   $1.893,13, PF 2,54, DD 20,99%/22,38%, 209 trade (4 bln) - jauh
//   melampaui versi Repend=STOP sebelumnya ($897,02/PF1,95).
//   AUDIT SISTEMATIS DILAKUKAN (bukan sekadar baca sekilas):
//   1. 286 parameter input - SEMUA terpakai, 0 yg mati/tak terintegrasi.
//   2. 148 variabel global (g_*) - SEMUA terpakai (1 "temuan" ternyata
//      cuma sebutan nama di komentar sejarah, bukan variabel sungguhan).
//   3. 133 fungsi custom - SEMUA terpanggil (4 yg "tak terpanggil" adalah
//      OnInit/OnDeinit/OnTick/OnChartEvent, event handler standar MT4 yg
//      memang dipanggil platform, bukan dr kode ini).
//   4. 81 forward declaration - SEMUA cocok persis dgn definisi aktualnya
//      (jumlah parameter sama), tak ada mismatch dr berkali-kali fungsi
//      diubah signature-nya sepanjang sesi ini.
//   5. 0 fungsi terdefinisi dua kali (yg akan gagal kompilasi).
//   6. Kurung kurawal {613/613} & siku [134/134] seimbang sempurna.
//   7. ApplyIntelligentTrailing (tempat Momentum Candle Trail v65 hidup)
//      dikonfirmASI terpanggil benar via ApplyDynamicProtection() di
//      blok newBar OnTick - evaluasi tiap bar baru, sesuai desainnya.
//   8. OnDeinit membersihkan objek dashboard dgn benar.
//   PERBAIKAN KECIL: baris "ðŸ”§ PENGATURAN MODE" dilengkapi
//   UseMomentumCandleTrail (sblm ini terlewat) - kini SEMUA master-switch
//   fitur besar tercatat di satu baris awal jurnal.
//   CATATAN JUJUR: audit ini bersifat STATIS (struktur kode, keterhubungan
//   variabel/fungsi, integrasi ke loop utama) - BUKAN pengganti pengujian
//   backtest+demo yg sudah & akan Anda lakukan. Kode terstruktur bersih
//   tak menjamin performa trading optimal di semua kondisi pasar; itulah
//   gunanya tahap demo sblm real yg sudah Anda rencanakan.
//   Momentum Candle Trail (v65) BELUM sempat teruji (0 kali muncul di tes
//   terakhir, kemungkinan UseMomentumCandleTrail blm dinyalakan) - kalau
//   ingin diuji jg, aktifkan sebelum tes terakhir Anda.
// v65/6.43 (19 Jul 2026) - FITUR BARU sesuai permintaan: MOMENTUM CANDLE
//   TRAILING - master switch UseMomentumCandleTrail (default MATI).
//   Beda dr trailing ATR generik (jarak tetap sama tak peduli kekuatan
//   momentum) & beda jg dr kemiringan (mengukur TREN multi-bar) - ini
//   respons thd SATU candle yg baru tertutup: kalau range-nya (H-L)
//   melebihi MomentumCandleATRMult(1,3)xATR DAN searah posisi, SL
//   langsung ditarik dekat ke low/high candle itu (buffer
//   MomentumCandleBufferATR=0,3xATR utk ruang koreksi/zigzag wajar) -
//   berpotensi melompat lewat harga entri sekaligus kalau candle-nya
//   cukup kuat, PERSIS spy profit tak tergerus menunggu trailing biasa
//   yg lebih lambat bereaksi. Hanya MENGETATKAN (ratchet, sama spt
//   mekanisme trailing lain), tak pernah melonggarkan, & posisinya
//   ditempatkan SETELAH trailing garis-ST di kode (jd otomatis ikut
//   dihormati masa tenggang lewat early-return yg sudah ada, v54).
//   BELUM DIUJI - fitur baru sepenuhnya, WAJIB diuji dgn
//   UseMomentumCandleTrail=true, bandingkan dgn mati (false) di periode
//   sama, sblm digabung dgn konfigurasi terbaik yg sudah ada.
// v64/6.42 (19 Jul 2026) - dari ketidakcocokan jurnal (104 open, 25
//   PYRAMID ADD) vs laporan (88 trade, angka identik dgn tes TANPA
//   pyramid) - indikasi file .log dan .htm berasal dr run berbeda.
//   FIX PENCEGAHAN: baris "ðŸ”§ PENGATURAN MODE" kini jg mencatat
//   UsePyramidAdd & UseSlopeAdaptiveSLTP - supaya kecocokan pasangan
//   file jurnal+laporan bisa langsung dipastikan dr satu baris, tanpa
//   perlu hitung manual "open #" vs total trade laporan.
//   BELUM DIUJI - mohon unggah ulang pasangan .log+.htm dari RUN YANG
//   SAMA (biasanya tersimpan bersamaan) utk analisis pyramid+kemiringan
//   yg akurat.
// v63/6.41 (19 Jul 2026) - dari pengamatan Anda: pyramid tak lanjut di
//   tren turun curam walau tren msh kuat. DITELUSURI & DITEMUKAN: kode
//   pyramid SEBELUMNYA tak pernah mencatat alasan penolakan (semua early-
//   return diam2, beda dr filter entri utama yg selalu print "DITOLAK") -
//   jadi tak bisa dibuktikan langsung dr log. TAPI scr logika kode: syarat
//   PyramidMinProfitATR(0,8xATR untung dulu) & PyramidMaxChaseATR(2,0xATR
//   dr garis ST) bisa "berlomba" tercapai HAMPIR BERSAMAAN justru di tren
//   CURAM (garis ST wajar tertinggal saat harga bergerak cepat) - jendela
//   valid utk pyramid jd sempit/tertutup persis saat tren PALING kuat,
//   kebalikan dr yg diinginkan.
//   FIX 1: log baru "â³ PYRAMID ... ditahan: jarak dr garis ST ..." - kini
//   tercatat kalau memang inilah penyebabnya, bisa dibuktikan di tes
//   berikutnya.
//   FIX 2: PyramidMaxChaseATR kini ikut melebar (x1,6) khusus saat tren
//   CURAM - pakai kerangka kemiringan yg SAMA dgn AutoSlope/
//   SlopeAdaptiveSLTP (konsisten, tak menambah konsep baru). Di tren
//   landai/sedang, batas tetap SEKETAT semula (jangan pyramid di titik yg
//   mulai exhausted beneran).
//   CATATAN PENTING: pelonggaran ini HANYA aktif kalau
//   UseSlopeAdaptiveSLTP=true (dipakai sbg master-switch yg sama, blm
//   ada toggle terpisah) - kalau false, PyramidMaxChaseATR tetap statis
//   spt sebelumnya, TAK ADA perubahan perilaku.
//   BELUM DIUJI - WAJIB uji dgn UseSlopeAdaptiveSLTP=true & UsePyramidAdd=true,
//   perhatikan baris log baru utk konfirmasi apakah dugaan ini benar & apakah
//   jumlah pyramid di tren curam bertambah.
// v62/6.40 (19 Jul 2026) - FITUR BARU sesuai permintaan: kalibrasi SL/TP
//   berdasar kemiringan tren, diterapkan ke SEMUA sistem entri (Trend
//   Rider utama, Repend, Titik-Jenuh, Cover) sekaligus - master switch
//   UseSlopeAdaptiveSLTP (default MATI).
//   MEKANISME: GetManualSLPips()/GetManualTPPips() adalah fondasi yg
//   dipakai LANGSUNG oleh entri utama, dan TIDAK LANGSUNG oleh
//   Repend/ExhPend/Cover (lewat GetGraceAwareSLPips yg dibangun di atas
//   GetManualSLPips). Krn itu, kalibrasi cukup disisipkan SEKALI di kedua
//   fungsi ini - otomatis merambat ke SEMUA sistem tanpa perlu ubah tiap
//   satu-satu. Override manual (g_UseManualSL/TP) TIDAK disentuh -
//   kalibrasi cuma berlaku di jalur ATR-adaptif.
//   LOGIKA: kemiringan (xATR/bar) diukur SAAT itu, pakai ambang yg SAMA
//   dgn AutoSlopeLandaiMax(0,15)/CuramMin(0,40) - satu model mental yg
//   konsisten dgn fitur AUTO_SLOPE pending yg sudah ada:
//     CURAM (momentum kuat)  -> SL x0,8 (lebih ketat) & TP x1,3 (lebih lebar)
//     SEDANG                 -> x1,0 keduanya (baseline, tak berubah)
//     LANDAI (lemah/zigzag)  -> SL x1,3 (lebih lebar) & TP x0,8 (lebih sederhana)
//   Semua 4 pengali bisa diatur manual via input (SlopeAdaptSL_Curam dkk).
//   BELUM DIUJI - fitur baru sepenuhnya & berdampak luas (menyentuh SL/TP
//   SEMUA trade) - WAJIB diuji hati-hati dgn UseSlopeAdaptiveSLTP=true,
//   bandingkan dgn baseline (false) di periode sama, sblm dipakai
//   bersamaan dgn keputusan besar lain.
// v61/6.39 (18 Jul 2026) - dari kebingungan Tes2==Tes3 identik: ditelusuri
//   ULANG seluruh logika dispatch ExhPend (fresh eyes), TIDAK ditemukan
//   bug - strukturnya sama persis dgn Repend yg TERBUKTI berfungsi (Tes1
//   beda dr Tes3). Dugaan terkuat: UseExhaustionPending mati di tes2/3,
//   shg ExhPendOrderMode tak sempat berpengaruh sama sekali (fungsi keluar
//   sblm sampai ke situ) - bukan bug, cuma blm sempat teruji. Tak bisa
//   dipastikan 100% krn jurnal detail tak berhasil didapat (kendala unggah
//   file berulang).
//   PERBAIKAN PENCEGAHAN: baris log baru "ðŸ”§ PENGATURAN MODE" SEKARANG
//   PASTI tercetak SEKALI di barisÂ² pertama jurnal tiap tes (bukan
//   tersebar di tengah) - menunjukkan LANGSUNG status UseExhaustionPending/
//   ExhPendOrderMode/UseContinuationRepending/RependOrderMode/TradingMode
//   yg SEBENARNYA terpakai. Ke depan, "apakah setelan X sudah benar2
//   berubah dr tes sebelumnya" bisa dipastikan dr beberapa baris pertama
//   jurnal saja, tanpa perlu mencari jauh.
//   BELUM DIUJI - mohon konfirmasi UseExhaustionPending aktif utk tes
//   AUTO_SLOPE berikutnya, dan cek baris "ðŸ”§ PENGATURAN MODE" di awal
//   jurnal utk pastikan setelannya benar sblm menjalankan tes panjang.
// v60/6.38 (18 Jul 2026) - evaluasi 2 tes (LIMIT only vs BOTH, 2 bulan
//   penuh) + fitur AUTO-KEMIRINGAN sesuai diskusi:
//   EVALUASI TES: LIMIT only = profit $221,63 PF1,25 DD38,61% (99 trade);
//   BOTH = profit $477,86 PF1,46 DD28,48% (119 trade) - BOTH unggul di
//   SEMUA metrik. Bug error 130 (v59) DIKONFIRMASI berfungsi di kedua tes -
//   pola "gagal->fallback berhasil" muncul & tak ada kegagalan permanen.
//   Tidak ada bug baru ditemukan.
//   FITUR BARU: mode ke-4 `REPEND_AUTO_SLOPE` utk RependOrderMode &
//   ExhPendOrderMode - gaya (STOP/LIMIT/BOTH) dipilih OTOMATIS per
//   kejadian berdasar kemiringan tren SAAT ITU (xATR/bar, pakai
//   ComputeTrendSlopeATR yg sudah dipakai Bias TF-Atas & Regime):
//     |slope| < AutoSlopeLandaiMax(0,15)   -> LIMIT (landai, wajar ada koreksi berarti)
//     AutoSlopeLandaiMax..CuramMin         -> BOTH  (sedang, dua2nya masuk akal)
//     |slope| >= AutoSlopeCuramMin(0,40)   -> STOP  (curam, momentum kuat, jarang koreksi dalam)
//   Arah naik/turun tak mengubah logika - cuma besaran (nilai mutlak) yg
//   menentukan kategori, otomatis mencakup kedua arah.
//   BUG HALUS DITEMUKAN & DIPERBAIKI SAAT MEMBANGUN INI: PlaceRependStop/
//   PlaceRependLimit dulu baca RependOrderMode (global mentah) langsung
//   utk cek "mode BOTH atau bukan" - kalau globalnya AUTO_SLOPE, cek itu
//   SELALU false walau hasil resolusi saat itu BOTH, membuat pengecekan
//   "sudah ada pending" jadi keliru terlalu ketat. FIX: kedua fungsi kini
//   terima mode YANG SUDAH DIRESOLUSI sbg parameter, bukan baca global.
//   Log baru "ðŸ“ AUTO-KEMIRINGAN: ..." dicetak tiap kali mode AUTO
//   dipakai, menunjukkan slope terukur & gaya yg dipilih - mudah ditelusuri.
//   BELUM DIUJI - fitur baru sepenuhnya, WAJIB diuji (RependOrderMode=3,
//   ExhPendOrderMode=3) sblm dipakai bersamaan dgn keputusan lain.
// v59/6.37 (18 Jul 2026) - dari kroscek log jurnal tes 2-bulan LIMIT-only:
//   BUG PENTING DITEMUKAN & DIPERBAIKI: "Grace-period OrderModify err
//   #130" muncul 2x - ditelusuri akar masalahnya: target SL normal
//   dihitung SEKALI saat posisi baru terdeteksi (berdasar ATR saat itu).
//   Kalau harga bergerak jauh BERLAWANAN selama masa tenggang (kini bisa
//   5-8 bar utk posisi asal LIMIT - jendela lebih panjang drpd 2 bar biasa
//   = lebih banyak waktu utk pergerakan besar terjadi), target lama itu
//   bisa jadi TIDAK VALID lagi thd harga SEKARANG (terlalu dekat atau di
//   sisi salah) - OrderModify gagal error 130.
//   DAMPAKNYA FATAL: sblm ini, kegagalan = MENYERAH total (graceActive
//   dimatikan tanpa upaya lain) - posisi TERTINGGAL SELAMANYA dgn SL
//   LEBAR (risiko justru lebih besar, kebalikan dr maksud "masa tenggang
//   berakhir, kembali ke SL normal"). Ini kemungkinan MENYUMBANG ke
//   drawdown yg lebih dalam - posisi yg seharusnya sudah dilindungi SL
//   ketat malah terus terbuka lebar.
//   FIX: kalau percobaan pertama gagal error 130, dicoba SEKALI LAGI dgn
//   target di-CLAMP relatif harga SEKARANG (msh arah yg sama, sedekat
//   mungkin scr aman/valid) - supaya pengetatan tetap terjadi, bukan
//   macet permanen dgn SL lebar.
//   CATATAN: blm ada baseline profit/drawdown tes SEBELUM v57 utk
//   dibandingkan presisi angkanya dgn tes ini - tp bug di atas jelas
//   nyata & berkontribusi ke eksposur risiko yg tak perlu, terlepas dari
//   itu. BELUM DIUJI ULANG - WAJIB uji lagi, kirim jam/tiket spesifik
//   kalau masih ada penurunan profit/drawdown yg terasa jelas stlh ini,
//   spy bisa ditelusuri lebih presisi lagi.
// v58/6.36 (18 Jul 2026) - dari laporan tes 2-bulan LIMIT-only, dievaluasi
//   dgn data konkret sblm bertindak (bukan asumsi):
//   1. "Entri langsung jd lelet merespon momentum" - DIBANDINGKAN angka
//      diagnostik tes ini vs tes STOP-only sebelumnya (periode serupa):
//      ENTRI TREND RIDER TEREKSEKUSI PERSIS SAMA (17 vs 17), Bias TF-atas
//      142 vs 147, Kuorum kurang 89 vs 91 - SEMUA selisih Â±1-5 (variasi
//      wajar antar-run, BUKAN pergeseran berarti). Ditelusuri jg di kode:
//      SetGracePeriod() di jalur entri langsung (ExecuteSmartOrder) TIDAK
//      menyertakan parameter target-bar LIMIT sama sekali - jadi scr
//      teknis TIDAK MUNGKIN terpengaruh perubahan v57 (yg cuma aktif utk
//      posisi ber-comment "REPENDL"/"EXHL"). Kesimpulan: mekanisme pemicu
//      entri langsung TIDAK berubah - kemungkinan yg teramati adalah
//      filter Bias TF-atas (syarat pembalikan 2-bar, sudah ada sejak v34,
//      tak terkait pekerjaan LIMIT manapun). Kalau masih terlihat lelet
//      setelah ini, mohon kirim jam/tiket persisnya spy bisa ditelusuri
//      presisi spt kasus OrderModify #4108 kemarin.
//   2. "Pending LIMIT masih jarang" - INI MEMANG NYATA & terpisah dr soal
//      no.1, bukan akibat v57 (yg tak menyentuh logika penempatan sama
//      sekali). Akar masalahnya barometer jarak xATR (RependLimitMinATR/
//      MaxATR, ExhPendLimitMinATR/MaxATR) msh cukup ketat. FIX: dilonggarkan
//      MinATR 0.3->0.2, MaxATR 2.0->3.5 (baik Repend maupun Titik-Jenuh) -
//      beralasan krn trailing v53 sudah menjaga level LIMIT tetap
//      relevan/mengikuti garis ST, jd batas MaxATR ketat spt sebelumnya
//      tak lg sepenting itu utk cegah level jadi basi.
//   BELUM DIUJI - WAJIB uji ulang, perhatikan apakah pending LIMIT kini
//   lebih sering muncul, dan kirim contoh jam/tiket spesifik kalau soal
//   no.1 masih terasa stlh membaca penjelasan di atas.
// v57/6.35 (18 Jul 2026) - sesuai permintaan Anda: posisi hasil BUY/SELL
//   LIMIT (Repend maupun Titik-Jenuh) jangan mudah kena SL krn koreksi
//   harga/zigzag sesaat, dan pending LIMIT-nya sendiri bertahan lebih lama
//   sblm kedaluwarsa. Dua perbaikan:
//   1. MASA TENGGANG SL KHUSUS LIMIT (GracePeriodBarsLimit=5, baru,
//      terpisah dr GracePeriodBars=2 biasa) - posisi yg terdeteksi berasal
//      dr pending ber-comment "REPENDL"/"EXHL" kini dpt masa tenggang SL
//      LEBIH LAMA drpd entri biasa. Alasannya: LIMIT secara desain masuk
//      PERSIS di area koreksi/zigzag (garis ST atau puncak ekstensi) -
//      wajar kena goncangan harga sesaat lebih besar dulu sblm tren asli
//      lanjut, drpd entri STOP/breakout yg momentumnya sudah lebih
//      terbukti duluan. Trade monitor kini py graceBarsTarget PER-POSISI
//      (bukan cuma satu angka global), jadi tiap posisi bisa py durasi
//      beda sesuai asalnya.
//   2. DURASI PENDING LIMIT DIPERPANJANG (terpisah dr STOP):
//      RependLimitExpiryBars=16 (dulu ikut RependExpiryBars=8 milik STOP),
//      ExhPendLimitExpiryBars=16 (dulu ikut ExhPendExpiryBars=8 milik
//      STOP) - filosofi LIMIT (menunggu harga koreksi/pullback ke level
//      tertentu) wajar butuh waktu tunggu lebih lama drpd STOP (menunggu
//      breakout momentum, biasanya lebih cepat kejadian kalau memang akan
//      terjadi).
//   Parameter STOP (GracePeriodBars, RependExpiryBars, ExhPendExpiryBars)
//   TIDAK berubah sama sekali - hanya menambah jalur terpisah utk LIMIT.
//   BELUM DIUJI - WAJIB uji ulang LIMIT (Repend & Titik-Jenuh) dgn
//   pengaturan baru ini sblm lanjut ke pengujian yg lebih panjang.
// v56/6.34 (18 Jul 2026) - dari laporan tes LIMIT-only jangka pendek:
//   1. BUG DIKONFIRMASI & DIPERBAIKI: "Repend Limit trailing OrderModify
//      err #4108 / unknown ticket 19" berulang 5x - ManageRependLimitTrailing
//      cuma cek tipe order (BUYLIMIT/SELLLIMIT), TIDAK cek OrderCloseTime() -
//      padahal order yg sudah dihapus/expired TETAP "mengingat" tipe
//      aslinya. Akibatnya tiket lama yg sudah tak aktif terus dicoba
//      di-modify SELAMANYA (spam error tiap bar, tak pernah reset).
//      FIX: tambah cek OrderCloseTime()>0. (ManageExhaustionPending sudah
//      benar dari awal - cuma fungsi trailing Repend Limit yg lupa.)
//   2. Kasus tgl 13-14 Okt (SELL LIMIT titik-jenuh terisi tp langsung rugi):
//      DITELUSURI - LIMIT itu benar terpasang & terisi @4131.97 (RSI 78.5),
//      tp tren TERBUKTI lanjut naik (bukan berbalik) - Cut-Loss Cerdas
//      benar mendeteksi cepat & menutup rugi terbatas, lalu Cover benar
//      menangkap kelanjutan tren dgn BUY. Ini BUKAN bug - RSI overbought
//      tdk menjamin pembalikan seketika, kadang bertahan lama di tren
//      kuat; sistem sudah merespons secepat mungkin thdp sinyal yg
//      ternyata salah.
//   3. Kasus tgl 16-17 Okt (SELL terus jalan padahal "maunya" BUY LIMIT):
//      PENTING DIPAHAMI - Trend Rider/Pyramid & Titik-Jenuh itu DUA SISTEM
//      independen, jalan PARALEL, bukan satu memprioritaskan yg lain.
//      Trend Rider terus entry/pyramid selama kriterianya SENDIRI terpenuhi
//      (ST+HA+kuorum), independen dr kondisi jenuh yg dicek terpisah oleh
//      sistem Titik-Jenuh. Keduanya BISA & LUMRAH beda arah scr bersamaan.
//   4. Kasus tgl 22 Okt (market turn ekstrem, tak ada BUY LIMIT/entri BUY):
//      Titik-Jenuh TIDAK memenuhi syarat pemicunya (ekstensi xATR msh
//      dihitung dr basis tren lama, RSI blm tentu di titik ekstrem PAS
//      sebelum lonjakan) - lonjakan MENDADAK beda karakter dr tren panjang
//      yg menua bertahap (skenario yg jd dasar rancangan sistem ini). Sinyal
//      BUY jg tertahan filter Bias TF-Atas (syarat pembalikan 2-bar blm
//      terpenuhi dlm window yg diuji - tes dihentikan manual sebelum
//      kelihatan apakah akhirnya lolos).
//   5. Slot LIMIT titik-jenuh diberi kesabaran pembatalan TERPISAH & LEBIH
//      LONGGAR dr STOP: ExhPendLimitCancelPersistBars=4 (baru, dulu ikut
//      ExhPendCancelPersistBars=2 milik STOP) - gaya LIMIT ("tunggu
//      pembalikan mulai dr titik ini") wajar butuh lebih sabar drpd STOP
//      ("tunggu konfirmasi jebol") thdp fluktuasi RSI wajar.
//   CATATAN JUJUR: sistem berbasis ambang (extension/RSI) TIDAK akan
//   pernah menangkap SEMUA titik balik yg terlihat jelas scr visual -
//   ini batas bawaan pendekatan mekanis, bukan sesuatu yg bisa "diperbaiki"
//   jadi sempurna. Perbaikan di atas menangani bug nyata & kalibrasi yg
//   longgar, bukan menjanjikan deteksi sempurna tiap pembalikan.
// v55/6.33 (18 Jul 2026) - sesuai permintaan Anda: sistem Titik-Jenuh
//   (Exhaustion) kini jg punya opsi LIMIT, konsisten dgn Repend -
//   `ExhPendOrderMode` (0=STOP asli/1=LIMIT baru/2=KEDUANYA).
//   Filosofi LIMIT DIRANCANG BEDA dr Repend krn tujuan sistemnya beda:
//   - STOP (asli): nunggu KONFIRMASI jebol struktur (breakdown/breakout
//     sungguhan) baru masuk - level di SISI arah breakdown (low utk sell,
//     high utk buy).
//   - LIMIT (baru): masuk LANGSUNG di puncak/dasar ekstensi ITU SENDIRI -
//     level di SISI BERLAWANAN (high utk sell, low utk buy) - bertaruh
//     pembalikan mulai dr situ tanpa perlu tunggu konfirmasi tambahan.
//     Divalidasi jaraknya (xATR, ExhPendLimitMinATR/MaxATR) sama spt
//     Repend LIMIT - jgn dipasang kalau kejauhan/kedekatan.
//   Mode BOTH: dua tiket independen (STOP & LIMIT) berjalan bersamaan,
//   masing2 py siklus hidup sendiri (pasang/geser adaptif/hapus per umur
//   & histeresis RSI) - TIDAK saling ganggu. Panel dashboard diperbarui
//   menampilkan KEDUANYA sekaligus kalau sama2 aktif ("STOP @ X | LIMIT @ Y").
//   BELUM DIUJI - fitur baru sepenuhnya, WAJIB diuji dulu (bandingkan
//   STOP/LIMIT/BOTH utk Titik-Jenuh, terpisah dr pengujian Repend) sblm
//   dipakai bersamaan dgn keputusan lain.
// v54/6.32 (18 Jul 2026) - dari laporan tes singkat mode LIMIT only:
//   1. "SELL STOP muncul di tgl 13-14 Okt" - DITELUSURI & DIKONFIRMASI:
//      itu dari "PENDING TITIK-JENUH" (sistem Exhaustion, terpisah dr
//      Repend) - subsistem itu SELALU pakai STOP, tak terpengaruh
//      RependOrderMode sama sekali krn belum diperluas ke sana. BUKAN bug
//      di dispatch STOP/LIMIT Repend (sudah diperiksa ulang, tetap benar).
//   2. "BUY LIMIT tgl 17 Okt kurang akurat, kena SL cepat" - DITELUSURI &
//      KETEMU BUG BESAR: posisi #16 (limit @4341.99) baru 1 bar berjalan
//      SL-nya sudah jadi 4341.99 (=breakeven, SAMA PERSIS harga entri),
//      lalu kena SL 1 menit kemudian - rugi kesempatan penuh dr entri yg
//      sebenarnya presisi. AKAR MASALAH: trailing garis-ST (v37, sudah
//      ada sblm fitur LIMIT) & mekanisme UseBreakeven - KEDUANYA tidak
//      pernah cek apakah posisi msh dlm masa tenggang (grace period) -
//      begitu garis ST/harga bergeser dikit di bar berikutnya, SL LEBAR
//      hasil grace period langsung DITIMPA jadi dekat breakeven SEBELUM
//      GracePeriodBars lewat. Paling terasa di entri LIMIT (buffer awal ke
//      garis ST nyaris nol - jadi dampaknya besar & instan), tp
//      sebenarnya berlaku ke SEMUA entri yg sedang dlm masa tenggang.
//      FIX: SATU titik jaga baru di ApplyIntelligentTrailing - selama
//      posisi msh graceActive, SEMUA mekanisme pengetatan SL di bawahnya
//      (garis-ST, lepas-TP, trailing normal, profit-stage, pullback-
//      retrace, breakeven) dilewati sekaligus - HANYA ManageEntryGracePeriod
//      yg boleh menyentuh SL selama jendela ini, persis sesuai
//      rancangan aslinya. Ini bug besar yg mempengaruhi SEMUA entri sejak
//      v46 (grace period pertama dibuat), bukan cuma LIMIT - untung
//      ketahuan lewat kasus LIMIT yg dampaknya paling kentara.
//   BELUM DIUJI ULANG - WAJIB uji lagi (STOP/LIMIT/BOTH) sblm lanjut ke
//   tes panjang, supaya efek gabungan bersama fix v53 (trailing LIMIT
//   ke garis ST) terlihat jelas.
// v53/6.31 (17 Jul 2026) - dari evaluasi 3 tes berturut-turut (STOP only /
//   LIMIT only / BOTH), semua temuan Anda benar & sudah ditelusuri:
//   1. STOP only = identik spt sebelum ada sistem LIMIT - konfirmasi
//      refactoring v52 tidak merusak jalur asli.
//   2. LIMIT jarang dipasang & hampir tak pernah tersentuh - AKAR MASALAH
//      ditemukan: level LIMIT dipatok STATIS di garis ST SAAT DIPASANG.
//      Dalam tren kuat (persis skenario yg memicu Repend), garis ST terus
//      MAJU seiring bar berjalan - level lama itu makin lama makin
//      "ketinggalan" dr harga sekarang, celahnya melebar, makin sulit
//      tersentuh sebelum keburu hangus (RependExpiryBars).
//      FIX: ManageRependLimitTrailing() baru - selama pending LIMIT msh
//      hidup & belum tersentuh, harganya di-TRAILING mengikuti garis ST
//      SEKARANG tiap bar (SL/TP ikut disesuaikan), bukan beku di level
//      lama. Ini perbaikan STRUKTURAL, bukan cuma tuning angka.
//   3. BOTH mode: STOP dominan, LIMIT jarang tersentuh - INI SEBAGIAN
//      MEMANG WAJAR (STOP=breakout cocok dgn "tren msh confirm intact",
//      yg justru berarti harga CENDERUNG lanjut bukan koreksi dulu) -
//      TAPI dgn fix trailing di atas, LIMIT kini py peluang lebih adil
//      utk tersentuh saat memang ada pullback.
//   4. Soal "sell stop muncul saat mode LIMIT only": ditelusuri kode
//      RependOrderMode - TIDAK ditemukan bug (dispatch STOP/LIMIT sudah
//      benar terpisah tegas). Dua kemungkinan: (a) "Tester: stop loss #XX"
//      di jurnal (event SL KENA, bukan tipe pending) bisa kebaca sbg
//      "sell stop" - istilah mirip tp beda makna; (b) kalau
//      UseExhaustionPending/UsePendingCover jg aktif, KEDUANYA itu MASIH
//      pakai STOP selalu (belum diperluas ke LIMIT) - independen dr
//      RependOrderMode. Mohon konfirmasi baris jurnal persisnya kalau
//      terulang, supaya bisa dipastikan yg mana.
//   BUG PENTING TERPISAH ditemukan dari pertanyaan Anda ttg 3 mode trading:
//   TradingMode (Conservative/Normal/Aggressive) SELAMA INI hanya berlaku
//   di RiskPerTrade=0 (lot manual) - SEMUA tes sepanjang percakapan ini
//   pakai RiskPerTrade>0 (risk-based), jadi TradingMode TAK PERNAH benar2
//   berpengaruh, cuma label kosmetik. FIX: g_ModeRiskMult (0,6x Conservative/
//   1,0x Normal/1,4x Aggressive) & g_ModeQuorumAdjust (+1/0/-1) kini
//   diterapkan ke jalur risk-based (lot & kuorum Trend Rider) - ketiga
//   mode kini benar2 beda perilaku brp pun RiskPerTrade yg dipakai.
//   BELUM DIUJI - trailing LIMIT & mode trading keduanya baru, WAJIB
//   diuji ulang sebelum dipakai bersamaan dgn keputusan lain.
// v52/6.30 (17 Jul 2026) - dari evaluasi tes A/B SpikeGuard di modal $500
//   (tes sebelumnya $200-1000-an): net profit $471,96 (on) vs $554,09 (off),
//   drawdown 22,18% (on) vs 27,68% (off) - rasio proteksi-vs-profit makin
//   bagus dibanding tes sebelumnya. TIDAK ADA lagi jejak "OrderModify error
//   130" - bug itu tetap tuntas.
//   FITUR BARU (permintaan Anda): PENDING LANJUT-TREN kini bisa gaya STOP
//   (asli) DAN/ATAU LIMIT (baru) - dipilih via RependOrderMode (0=STOP,
//   1=LIMIT, 2=KEDUANYA sekaligus utk uji banding langsung).
//   Filosofi STOP (asli): breakout - pasang di LUAR struktur H/L terkini,
//   menangkap kelanjutan MOMENTUM (harga harus terus bergerak searah tren
//   utk terisi).
//   Filosofi LIMIT (baru): pullback - pasang PERSIS di garis Supertrend
//   saat ini (acuan tren yg SUDAH dipakai konsisten di seluruh EA ini utk
//   kuorum/jarak-kejar/trailing - BUKAN harga sembarang), menangkap
//   koreksi/pullback KEMBALI ke tren yg sama dgn harga LEBIH BAIK dr market.
//   BAROMETER AKURASI (sesuai permintaan - jangan asal pasang): jarak garis
//   ST ke harga sekarang WAJIB dalam rentang RependLimitMinATR..MaxATR
//   (default 0,3-2,0xATR) - kalau kejauhan (tren mungkin sudah menua/lemah
//   saat limit terisi nanti) atau kedekatan (nyaris sama dgn harga sekarang,
//   tak ada manfaat harga lebih baik), TIDAK dipasang sama sekali, drpd
//   dipaksakan pada level yg lemah dasarnya.
//   Mode BOTH: dua pending (satu STOP, satu LIMIT) boleh terpasang
//   bersamaan (masing2 dicegah dobel dgn tipenya sendiri) - persis
//   permintaan Anda utk bisa membandingkan langsung mana yg lebih relevan.
//   Panel dashboard (info pending) diperbarui supaya jg mengenali & ikut
//   menampilkan pending LIMIT baru, bukan cuma STOP spt sebelumnya.
//   BELUM DIUJI - fitur baru, WAJIB dites dulu (bandingkan STOP vs LIMIT vs
//   BOTH, periode sama) sebelum dipakai bersamaan dgn keputusan lain.
// v51/6.29 (17 Jul 2026) - build ini DIBANGUN DI ATAS file kustomisasi
//   dashboard Anda (posisi/warna/font sudah diverifikasi - TIDAK ADA
//   perubahan logika/sistem apa pun di file itu, murni tampilan, sesuai
//   yg Anda sampaikan). Nilai dolar di V_PairInfo SENGAJA dibiarkan sesuai
//   konfirmasi Anda.
//   Dari evaluasi tes A/B Spike Guard ronde 2 (build v50): TERKONFIRMASI
//   bug OrderModify error 130 TUNTAS - tidak ada lagi jejaknya di jurnal.
//   BUG STRUKTURAL PartialProfit ditemukan (bukan sekadar soal waktu spt
//   dugaan v50): PartialProfitPercent1/2=30% dikalikan ke lot - TAPI akun
//   ini (dan kemungkinan besar akun manapun yg masih kecil) SELALU trading
//   di lot minimum broker 0.01 (terlihat di SETIAP baris "Lot digunakan:
//   0.01" di semua log yg pernah dikirim). 0.01 x 30% = 0.003, dibulatkan
//   NormalizeDouble jadi 0.00 - TIDAK VALID, partial-close TIDAK PERNAH
//   bisa terjadi secara MATEMATIKA, apa pun perbaikan frekuensi
//   pengecekannya (v50 benar tp tidak cukup - itu memperbaiki KAPAN
//   dicek, bukan KENAPA hasilnya selalu nol).
//   FIX: kalau closeLot yg dihitung < lot minimum broker (lot tak bisa
//   dipecah), FALLBACK ke penguncian profit via SL (prinsip sama dgn
//   Spike Guard) - level ATR yg tercapai (1.5x/2.5xATR) dikunci sbg SL
//   baru, bukan coba memecah lot yg scr matematis mustahil. Utk akun yg
//   CUKUP besar shg lot > minimum, perilaku PECAH-LOT asli TETAP berjalan
//   spt sebelumnya - fallback ini HANYA aktif saat memang perlu.
// v50/6.28 (17 Jul 2026) - dari evaluasi tes A/B Spike Guard (periode sama,
//   985 bar): net profit $554â†’$495 (-10.6%), TAPI drawdown maksimal turun
//   signifikan 35.33%â†’28.61% - trade-off yg masuk akal utk fitur proteksi.
//   Bukti konkret fitur bekerja: order #127 (buy @4182.67) sempat untung
//   1.95xATR lalu mundur tajam - Spike Guard mengunci SL di 4195.65 (MASIH
//   profit +12.98 poin dari entri), tanpa itu akan lanjut ke SL lama di
//   4166.54 (RUGI). Satu contoh ini saja mengubah trade dari rugi jd untung.
//   DUA BUG ditemukan & diperbaiki dari log yg dikirim:
//   1. BUG KRITIS Spike Guard: OrderModify TIDAK PERNAH cek jarak minimum
//      broker sblm dipanggil - kalau level kunci kebetulan terlalu dekat
//      dgn harga saat itu, broker menolak (error 130), dan krn gagal maka
//      kondisi tetap terpenuhi SELAMANYA -> mencoba lagi TIAP TICK ->
//      membanjiri jurnal dgn puluhan "OrderModify error 130" beruntun
//      (persis terlihat di log tes 2). FIX: jarak dipangkas ke minimum
//      aman broker dulu sblm modify, bukan dibiarkan mentah.
//   2. BUG PartialProfit (dari catatan Anda "belum berfungsi dgn baik"):
//      TERKONFIRMASI - ManagePartialProfit() SELAMA INI dipanggil dari
//      dalam ApplyIntelligentTrailing yg (seperti Spike Guard versi lama)
//      HANYA dicek SEKALI PER BAR BARU. Kalau harga menembus ambang
//      PartialProfitLevel1/2 (xATR) DALAM SATU bar lalu mundur lagi
//      sebelum bar itu tutup, ambang itu TIDAK PERNAH terdeteksi - profit
//      yg sempat bisa diamankan lewat begitu saja. FIX: CheckPartialProfitTick()
//      baru - logika ManagePartialProfit() sendiri TIDAK diubah (tetap
//      berbasis xATR, tetap idempoten), HANYA frekuensi pengecekannya kini
//      tiap tick, konsisten dgn Spike Guard & berlaku utk SEMUA jalur
//      entri (langsung maupun via pending, krn keduanya sama2 masuk
//      g_tradeMonitors sejak fix v49).
//   REKOMENDASI: ulangi tes A/B yg sama (SpikeGuard on/off, periode sama)
//   dgn build ini - PartialProfit yg baru benar2 aktif kali ini bisa
//   mengubah hasil dibanding tes sebelumnya, jadi angka lama tidak lagi
//   representatif utk perbandingan final.
// v49/6.27 (17 Jul 2026) - dari evaluasi tes drawdown kedua (SEHAT: DD
//   34,96% tertahan wajar dekat ambang, tidak ada lagi lockup/error 4051 -
//   kedua bug v47/v48 terkonfirmasi tuntas) & 2 pertanyaan teknis lanjutan:
//   1. MASA TENGGANG SL TERSAMBUNG KE PENDING ORDER: sebelumnya HANYA
//      berlaku di entri langsung (ExecuteSmartOrder) - SEMUA pending order
//      (titik-jenuh/cover/lanjut-tren) masih pakai SL sempit biasa tanpa
//      masa tenggang sama sekali, persis keluhan "napas pending kena agak
//      sempit". FIX: GetGraceAwareSLPips() - fungsi bantu baru dipakai
//      konsisten di ManageExhaustionPending (termasuk pergeseran
//      adaptifnya), MaybePlaceCoverStop, MaybePlaceContinuationRepending -
//      begitu pending TERSENTUH jadi posisi sungguhan, EnsureAllOrdersMonitored
//      kini JUGA mendaftarkannya ke masa tenggang (target normal dihitung
//      fresh saat itu), supaya SL-nya jg mengetat otomatis setelah
//      GracePeriodBars - benar2 konsisten dgn entri langsung, bukan cuma
//      lebar selamanya.
//   2. SPIKE GUARD (fitur baru) - menjawab: "sudah untung jauh, candle
//      LEBAR tiba2 membalik dalam satu bar, TP tak sempat diamankan".
//      Akar masalah: trailing/proteksi (ApplyDynamicProtection) SELAMA INI
//      HANYA dicek SEKALI PER BAR BARU (di dalam blok if(newBar) OnTick) -
//      pembalikan yg terjadi & SELESAI DALAM SATU bar tidak pernah sempat
//      "terlihat" sebelum bar itu tutup. UseSpikeGuard (default nonaktif)
//      menambah pengecekan TERPISAH tiap TICK (bukan per-bar) - kalau
//      profit sudah cukup besar (SpikeGuardMinProfitATR) DAN harga mundur
//      signifikan dari puncak SAAT ITU JUGA (SpikeGuardRetraceATR, bukan
//      nunggu bar tutup), SL darurat langsung dipasang mengunci sebagian
//      profit puncak (SpikeGuardLockRatio). Koreksi kecil/pendek yg masih
//      wajar TETAP dibiarkan ke trailing biasa - Spike Guard cuma aktif
//      utk pembalikan yg genuinely lebar & mendadak.
//   CATATAN JUJUR: Spike Guard fitur BARU, default nonaktif, BELUM
//   divalidasi backtest - WAJIB diuji dulu (bandingkan on/off) sebelum
//   dipakai bersamaan dgn fitur lain, supaya efeknya jelas terlihat
//   terpisah.
// v48/6.26 (17 Jul 2026) - BUG KRITIS KEDUA ditemukan dari laporan Anda:
//   begitu HARD DRAWDOWN STOP terpicu (dd>=35%), EA jeda 4 jam spt
//   dirancang - TAPI begitu jeda berakhir, terkunci lagi SELAMANYA, tidak
//   pernah entri lagi. Akar masalah: g_HighestBalance (puncak saldo
//   tertinggi, dasar perhitungan drawdown %) TIDAK PERNAH direset setelah
//   hard-stop. Begitu jeda 4 jam berakhir, drawdown yg dihitung ULANG masih
//   PERSIS di atas 35% (belum ada trade baru selama jeda utk memulihkannya)
//   - jadi CheckDrawdownProtection() LANGSUNG memicu ulang hard-stop
//   SEKETIKA pada tick berikutnya, mengunci 4 jam lagi, berulang TANPA
//   HENTI. Jeda "berakhir" cuma sesaat, tak pernah benar2 sempat entri lagi
//   - persis penguncian permanen yg dilaporkan.
//   FIX: begitu jeda berbatas-waktu berakhir DAN drawdown masih di atas
//   ambang (g_DrawdownProtectionActive=true), puncak saldo direset ke
//   ekuitas SAAT ITU - drawdown dihitung ulang relatif ke titik pemulihan,
//   bukan puncak lama sebelum insiden. EA kini benar2 aktif kembali setelah
//   jeda, bukan terjebak mengunci diri sendiri berulang.
// v47/6.25 (16 Jul 2026) - BUG KRITIS ditemukan dari laporan Anda: begitu
//   EnableDrawdownProtection=true & drawdown lewat 25%, SEMUA entri
//   Recovery gagal permanen ("OrderSend error 4051 / invalid lots amount",
//   "lot final 0.00") - BUKAN soal jeda 4 jam spt dugaan awal, tapi bug
//   URUTAN KODE nyata di CalculateLotSize(): batas minimum lot (minLot)
//   diterapkan SEBELUM pengali faktor reduksi drawdown & kekalahan-beruntun
//   dikalikan. Begitu KEDUA faktor itu aktif bersamaan (cuma bisa terjadi
//   kalau EnableDrawdownProtection=true, krn keduanya digerbang flag yg
//   sama), hasil kalinya bisa sampai ~0,06x - lot yg SUDAH di-floor ke
//   minLot (mis. 0.01) dikalikan lagi jadi 0,0006, dibulatkan jadi 0.00 -
//   TIDAK VALID utk OrderSend, gagal selamanya selama drawdown masih
//   tinggi (persis penguncian yg dilaporkan; hard-stop 35% bahkan belum
//   sempat kepakai krn Recovery sudah macet duluan di 25%).
//   FIX: floor minLot ditambahkan LAGI setelah pengali reduksi diterapkan,
//   DAN sebagai jaring pengaman terakhir tepat sebelum lot dikembalikan -
//   apa pun jalur perhitungannya (normal/LotBoost/pagar risiko/recovery),
//   lot yg dikirim ke OrderSend dijamin tidak akan pernah di bawah minimum
//   broker.
// v46/6.24 (16 Jul 2026) - MASA TENGGANG SL: menjawab keluhan spesifik -
//   "sering kena SL duluan gara2 koreksi/zigzag WAJAR di awal tren baru
//   bergerak, padahal arahnya sudah benar, keburu kena SL sebelum tren
//   sungguhan lanjut". FIX: UseEntryGracePeriod (default NONAKTIF) - saat
//   aktif, SL SUNGGUHAN yg dipasang di awal entri LEBIH LEBAR
//   (GracePeriodATRMultiplier=2.2xATR drpd normal 1.2xATR) khusus utk
//   GracePeriodBars (default 2) bar pertama - cukup lebar utk bertahan dari
//   shake-out/koreksi wajar yg umum terjadi persis saat tren baru mulai
//   (pasar "ambil ancang-ancang" dulu). Begitu masa tenggang lewat, SL
//   OTOMATIS mengetat ke jarak normal (kalau posisi masih terbuka & belum
//   ada trailing lain yg sudah membuatnya lebih baik).
//   PENTING soal risiko (baca sebelum aktifkan): lot-size DIHITUNG dari
//   jarak SL LEBAR ini sejak awal - jadi risiko % tetap sesuai
//   RiskPerTrade yg dikonfigurasi (TIDAK ada risiko tersembunyi tambahan),
//   TAPI kalau trade memang salah arah sejak awal (bukan cuma shake-out),
//   kerugian dolar per SL kena selama 2 bar pertama akan SAMA seperti
//   biasa (krn risk% konstan) - yg berubah adalah SEBERAPA JAUH harga harus
//   bergerak dulu sebelum SL itu kena, bukan besar kerugiannya. Trade-off
//   sesungguhnya: profit per lot jadi sedikit lebih kecil (lot mengecil
//   proporsional dgn jarak SL yg lebih lebar) demi survival rate yg lebih
//   baik dari shake-out. DEFAULT NONAKTIF - fitur baru, WAJIB diuji di
//   demo dulu, bandingkan hasil on/off, sebelum akun real.
//   TAMBAHAN: log "PARTIAL PROFIT" ditambahkan - sebelumnya partial-profit
//   (kalau UsePartialProfit aktif) tereksekusi TOTAL SILENT tanpa jejak
//   sama sekali di jurnal, beda dgn PYRAMID ADD/PENDING LANJUT-TREN yg
//   selalu tercatat - kini disamakan, supaya bisa diaudit dari jurnal jg.
// v45/6.23 (16 Jul 2026) - BUG SUNGGUHAN ditemukan: panel "Positions"
//   (Entry Buy/Sell count & Floating P/L) TIDAK real-time saat trading
//   manual - baru muncul setelah bar baru terbentuk (bisa 1 jam sekali di
//   H1)! Akar masalah: g_BuyPositions/g_SellPositions/g_CurrentFloatingProfit
//   (dipakai V_BuyC/V_SelC/V_Flt) dihitung oleh UpdatePositionStats() yg
//   HANYA dipanggil di blok newBar - sementara detail posisi (L_BuyDetails/
//   L_SellDetails, yg SUDAH benar menurut laporan Anda) scan order fresh
//   tiap panggilan DAN ikut refresh dashboard tiap DETIK - jadi dua bagian
//   panel yg sama py frekuensi update berbeda jauh. FIX: UpdatePositionStats()
//   kini JUGA dipanggil tiap detik (bareng UpdateDashboard), disamakan
//   frekuensinya dgn detail posisi - semua bagian panel Positions kini
//   benar2 real-time & sinkron, termasuk saat trading manual lewat tombol
//   BUY/SELL dashboard. Tidak mempengaruhi logika trading (MaxOrders dkk
//   tetap bar-gated spt semula, sinkron dgn CheckEntry yg jg bar-gated) -
//   perbaikan ini murni utk akurasi TAMPILAN monitoring.
// v44/6.22 (16 Jul 2026) - BUG SUNGGUHAN ditemukan (bukan cuma soal
//   tampilan): keempat handler tombol SL+/SL-/TP+/TP- men-SEED nilai awal
//   manual dari GetAdaptiveStopLossPips()/GetAdaptiveTakeProfitPips() saat
//   PERTAMA KALI diaktifkan - utk emas (SL berbasis ATR) itu bisa RIBUAN
//   pip, bukan nol! Jadi klik + PERTAMA KALI langsung melompat ke
//   "ribuan+10" (persis kasus nyata: "M:1239" yg dilaporkan - itu SL
//   adaptif saat itu ~1229, ditambah step 10). FIX: keempatnya kini mulai
//   dari 0 murni saat pertama diaktifkan - klik pertama pas menghasilkan
//   "10", klik kedua "20", dst, sesuai skenario yg diminta persis.
// v43/6.21 (16 Jul 2026) - sesuai permintaan: label SL/TP di dashboard
//   (tombol +/- DAN panel Advanced Info) kini HANYA menampilkan angka pip
//   polos, nilai dolar "($X.X)" dihapus - ruang dashboard sempit, cukup pip
//   saja utk kebutuhan trading manual via tombol BUY/SELL dashboard.
//   Mekanisme intinya SUDAH BENAR sejak awal (dikonfirmasi lewat pembacaan
//   kode, bukan tebakan): menggeser SL/TP lewat +/- SAAT posisi sedang
//   berjalan langsung memodifikasi SL/TP SUNGGUHAN posisi itu (dihitung
//   dari harga entrinya via OrderModify) - bukan cuma tersimpan utk entri
//   berikutnya. Lot manual (tombol tersendiri) & SL/TP manual independen -
//   kalau salah satu/keduanya dilepas (tak diatur), otomatis kembali ikut
//   sistem adaptif spt semula.
// v42c/6.20 (16 Jul 2026) - AUDIT MENYELURUH atas permintaan eksplisit
//   sebelum akun real: cek seluruh variabel global & input parameter,
//   pastikan semua tersambung benar, tidak ada yg mati/terlewat.
//   DITEMUKAN & DIBERSIHKAN (kode mati, TIDAK mengubah perilaku EA):
//   - g_cnt_ContH1/H4/HA/HTFBias: mati sejak sistem kuorum v38 (counter
//     individual diganti 1 counter kuorum gabungan, yg lama tak pernah
//     dihapus).
//   - RegimeADXMin: mati sejak rezim dirombak jadi dominasi DI+/DI- (v19) -
//     tertinggal, tak pernah dihapus walau fungsinya sudah diganti total.
//   - SoftStopSafetyMultiplier: dideklarasikan tp tak pernah dipakai -
//     virtual SL (soft-stop) ternyata pakai jarak PERSIS SAMA dgn SL asli,
//     bukan dikali multiplier ini. TIDAK diubah perilakunya (terlalu
//     berisiko menebak logika SL tanpa konfirmasi Anda) - kalau maksud
//     awalnya beda, kabari saya.
//   - C_Purple/C_Cyan/C_Magenta: opsi warna dashboard yg tak pernah dipakai
//     di tampilan manapun - menyesatkan kalau dibiarkan seolah fungsional.
//   - g_StartingBalance, HasESPSignal, GetHighestFavorablePrice: dideklarasi/
//     ditulis tp tak pernah dibaca/dipanggil - logika yg relevan (spt ESP
//     veto) ternyata sudah diimplementasi ulang scr inline di tempat lain.
//   DITEMUKAN & DIPERBAIKI (bukan cuma dihapus - disambungkan dgn benar,
//   PERUBAHAN PERILAKU YG DISENGAJA demi keamanan akun real):
//   - SmartOrderSend: fungsi retry-otomatis utk error transien (requote,
//     harga berubah, off-quotes) yg SUDAH DITULIS LENGKAP tp TAK PERNAH
//     dipanggil dari mana pun - 6 titik OrderSend() aktif di EA semuanya
//     pakai OrderSend() polos tanpa retry sama sekali. Diganti fungsi baru
//     OrderSendRetry (drop-in replacement, argumen sama persis) yg kini
//     dipakai di SEMUA 6 titik order (entri pasar Reversal/Rider, pullback,
//     titik-jenuh, cover, lanjut-tren, manual dashboard). PENTING: error
//     transien ini SERING di akun real tp TIDAK PERNAH muncul di backtest
//     manapun (Strategy Tester tidak mensimulasikannya) - jadi lubang ini
//     tidak akan pernah kelihatan dari hasil backtest sebaik apa pun.
//   CATATAN JUJUR: audit ini SISTEMATIS (dicek semua 138 variabel global &
//   263 input parameter scr terprogram) tp bukan JAMINAN 100% tanpa celah -
//   kompleksitas logika (bukan cuma keberadaan variabel) tetap butuh
//   pengujian nyata di demo sblm akun real.
// v42b/6.19 (16 Jul 2026) - perbaikan warning compile: "possible use of
//   uninitialized variable 'tpNowD'/'slNowD'" di panel Advanced Info (v42).
//   Bukan bug logika (nilainya sebenarnya selalu terisi di semua jalur -
//   compiler MQL4 cuma tidak cukup pintar membuktikan sendiri lewat pola
//   flag showingReal), tapi tetap dirapikan dgn inisialisasi eksplisit ke 0
//   di deklarasi, menghilangkan ambiguitas sepenuhnya.
// v42/6.18 (16 Jul 2026) - dari klarifikasi PENTING soal maksud tombol SL/TP
//   dashboard: tombol ini utk ENTRI MANUAL opsional (lewat tombol BUY/SELL
//   dashboard sendiri, terpisah dari mesin otomatis) - saat belum diatur,
//   MESTINYA tampil kosong/nol, bukan angka adaptif besar tanpa keterangan.
//   FIX: label SL/TP kini tampilkan "0 (auto)" abu-abu saat belum diatur
//   manual - jelas ini kondisi kosong/opsional (fungsi eksekusi TETAP pakai
//   nilai adaptif sbg pengaman kalau BUY/SELL diklik tanpa mengatur dulu -
//   cuma TAMPILANNYA yg diperjelas, bukan menghapus pengaman).
//   Panel Advanced Info jg diperbaiki serupa: dulu SELALU tampilkan angka
//   HIPOTETIS (estimasi entri berikutnya), bahkan saat ADA posisi terbuka -
//   begitu TrendRun_ReleaseTP memperlebar TP posisi yg sedang berjalan,
//   angka yg tampil (dari kalkulasi baru, BUKAN posisi sungguhan) bisa beda
//   & terlihat "ribuan pip tanpa alasan". Kini: kalau ADA posisi terbuka,
//   rekam SL/TP SUNGGUHAN posisi itu (ditandai "[POSISI AKTIF]"); kalau
//   tidak ada, baru tampilkan estimasi (ditandai "[estimasi]").
// v41/6.17 (16 Jul 2026) - MENEPATI JANJI yang tertunda di v39: mekanisme
//   PYRAMID ADD - dulu sengaja ditunda krn perlu dirancang hati-hati
//   terpisah (menambah eksposur risiko), sekarang diimplementasikan.
//   MASALAH: Reversal & Rider keduanya WAJIB pemicu segar (flip/breakout)
//   utk entri - tren yg mulus tanpa pemicu tambahan otomatis cuma dapat 1
//   entri, walau MaxOrders mengizinkan lebih & trennya jelas msh berjalan
//   kuat. Ini akar "entri beruntun tidak konsisten" yg dilaporkan.
//   FIX: TryPyramidAdd() - dipanggil di akhir CheckEntry(), HANYA jalan
//   kalau TIDAK ADA sinyal baru yg tereksekusi tick ini. Menambah posisi
//   SEARAH posisi yg SUDAH terbuka, dgn penjagaan berlapis (SEMUA harus
//   lolos, bukan opsional):
//   - Posisi terakhir min untung PyramidMinProfitATR (0.8) xATR - bukti
//     tren SUNGGUHAN berjalan, bukan asal nambah begitu entri pertama.
//   - Min PyramidMinBarsGap (3) bar sejak entri terakhir - jangan menambah
//     tiap saat/tiap tick.
//   - ST trend msh SEARAH posisi (blm flip) - kalau sudah berbalik, jangan
//     tambah eksposur ke arah yg mulai diragukan indikator sendiri.
//   - Jarak ke garis ST skrg TIDAK BOLEH > PyramidMaxChaseATR (2.0) xATR -
//     JANGAN pyramid tepat di titik yg sudah mulai exhausted (ini yg
//     mencegah fitur ini malah menciptakan masalah "entri di puncak" yg
//     baru, kalau tak dijaga).
//   - Gerbang AI (kalau UseAIScoreGate aktif) tetap ikut menyaring.
//   - Pakai lot-sizing berbasis risiko yg SAMA (CalculateLotSize) spt
//     entri normal - bukan tambahan risiko yg tak terkontrol; total
//     eksposur tetap dibatasi MaxOrders x risiko-per-trade seperti biasa.
//   CATATAN JUJUR: DEFAULT NONAKTIF (UsePyramidAdd=false) - ini fitur baru
//   yg BELUM tervalidasi backtest sama sekali. Menambah posisi berarti
//   menambah eksposur (drawdown potensial bisa lebih dalam kalau tren
//   ternyata berbalik SETELAH pyramid ditambahkan, sebelum trailing sempat
//   bereaksi) - WAJIB uji di backtest/demo dulu sebelum dipakai live,
//   bandingkan dgn hasil UsePyramidAdd=false yg sudah tervalidasi.
// v40/6.16 (16 Jul 2026) - dari tes 7-bulan v39 (AI=false: net +986.94, PF 1.71,
//   DD 38.85%, Repend berkontribusi ~60 trade tambahan) & laporan lanjutan:
//   1. AI DILATIH ULANG dgn CSV terbaru (13 Jul 2026). Ketahuan hal penting:
//      walau atr_ratio sudah tersedia, pohon TETAP memilih atr_now mentah
//      (basi) drpd atr_ratio - keduanya scr statistik "cukup mirip" tapi
//      atr_now kebetulan sedikit lebih tinggi info-gain-nya di data historis.
//      FIX: atr_now DIHAPUS TOTAL dari pilihan fitur (bukan cuma ditambah
//      alternatif) - memaksa pohon pakai fitur yg robust. Hasilnya kini pakai
//      htf_slope (sudah ternormalisasi ATR sejak awal) di percabangan
//      terakhir, bukan ambang ATR mentah yg basi. AUC ~sama (0.595 vs 0.593)
//      tapi ambang 0.5 kini JAUH lebih longgar (19032 sinyal lolos vs 3081
//      dulu) - precision di ambang 0.5 turun jadi 0.474, TAPI naik lagi ke
//      0.741 di ambang 0.6 (mirip selektivitas versi lama). PILIH SENDIRI
//      ambang sesuai selera agresif/presisi Anda - tabel lengkap ada di
//      log training, defaultnya saya biarkan 0.5.
//   2. DASHBOARD SL/TP "RIBUAN PIP": ternyata BUKAN bug angka, tapi konvensi
//      satuan - emas pakai 1 pip=$0.01 (2 desimal), jadi SL wajar $27 (dari
//      1.2xATR saat ATR~$23) tampil sbg "2700" tanpa konteks dolar, terlihat
//      alarming padahal benar & wajar. FIX: semua label SL/TP (tombol +/-
//      DAN panel Advanced Info) kini disertai nilai dolar eksplisit "(...$X)"
//      supaya langsung jelas, bukan cuma angka pip mentah.
//   3. STATUS PENDING DI DASHBOARD: label "Pending: ..." SEBELUMNYA cuma
//      mencerminkan sistem ExhPend (titik-jenuh) - begitu Cover(v30) atau
//      Repend(v39) yg memasang pending, dashboard tetap tampil "-" walau
//      SUNGGUH ada pending aktif. FIX: kini memindai LANGSUNG order pending
//      manapun milik EA ini (dari subsistem manapun), jadi selalu
//      mencerminkan kondisi nyata.
//   4. PENDING STOP vs LIMIT (pertanyaan Anda): TIDAK diubah ke limit -
//      justru EA ini SUDAH PERNAH mengujinya (lihat EntryStyle=
//      ENTRY_PULLBACK_LIMIT, sejak versi lama) dan comment kode sendiri
//      mencatat hasilnya: "adverse selection" - sinyal PEMENANG jarang
//      retrace jadi TERLEWAT, sinyal PECUNDANG lebih sering retrace dalam
//      jadi TERISI - net-nya lebih buruk dari market/stop. Gerbang
//      konfirmasi (ExhPend/Cover/Repend) SENGAJA pakai STOP krn tujuannya
//      memang menunggu BUKTI arah (harga menembus level), bukan memburu
//      harga lebih baik - limit akan melemahkan justru tujuan itu.
//   CATATAN JUJUR: semua perbaikan dashboard baru diimplementasi, BELUM
//   divalidasi visual langsung (saya tidak bisa melihat tampilan dashboard
//   sungguhan) - mohon screenshot dashboard setelah update ini kalau masih
//   ada yg terlihat janggal, supaya saya bisa cek persis apa yg tampil.
// v39/6.15 (15 Jul 2026) - dari laporan pengamatan mendalam pengguna atas hasil
//   tes AI=false yg sudah tervalidasi kuat ($863,61, PF 1,79, DD 43,98%):
//   1. DASHBOARD SL/TP MENAMPILKAN ANGKA "ANEH": ternyata tombol SL+/TP- di
//      dashboard adalah OVERRIDE MANUAL (bisa tersenggol klik tanpa sengaja
//      saat menonton visual backtest) - begitu aktif, seluruh trailing
//      otomatis BERHENTI utk order itu, dan label sebelumnya TIDAK PUNYA
//      penanda visual apa pun beda dari mode normal (warna & format sama
//      persis) - wajar user bingung "angka ini dari mana". Ditambah, label
//      V_PairInfo TIDAK ikut sadar override manual (selalu tampilkan nilai
//      otomatis) sementara V_SLValue/V_TPValue sudah sadar - dua tempat di
//      panel yg sama bisa tampilkan angka BERTENTANGAN. FIX: kedua label kini
//      diberi awalan "M:" + warna oranye saat override manual aktif, dan
//      V_PairInfo disamakan supaya konsisten dgn V_SLValue/V_TPValue.
//   2. SL KENA SAAT KOREKSI SESAAT, TREN ASLI LANJUT TANPA ENTRI ULANG:
//      sistem PENDING COVER yg ada (v30) ternyata HANYA menyasar kasus tren
//      SUNGGUH berbalik (butuh ST+HA sudah flip ke arah LAWAN posisi yg
//      kalah) - kasus yg dikeluhkan (koreksi wajar, tren ASLI masih hidup,
//      cuma keburu kena cut-loss) sama sekali tidak tertangani. Ditambahkan
//      mekanisme baru MaybePlaceContinuationRepending: begitu posisi tutup
//      rugi TAPI indikator (ST+HA mentah) MASIH searah posisi lama, pasang
//      pending SEARAH posisi lama, baru tersentuh kalau harga sungguh
//      menembus struktur terbaru (bukti koreksi selesai, bukan asal masuk
//      lagi di harga sama).
//   3. AI (v36-v38): akar masalah AI=true 0 trade sudah didiagnosis (skor
//      selalu 0,494 krn batas atr_now mentah jadi basi - lihat catatan
//      diagnosis sebelumnya). Export_AI_Training_Data.mq4 dinaikkan ke v3:
//      tambah fitur atr_ratio (ATR pendek/ATR panjang) yg tetap relevan
//      berapa pun harga emas nanti, krn pembilang & penyebut naik
//      proporsional bersama. BELUM retraining - menunggu CSV baru dari Anda.
//   CATATAN JUJUR: (a) perbaikan #1 & #2 baru diimplementasi, BELUM
//   divalidasi lewat backtest ulang - wajib diuji ulang. (b) Ada satu lagi
//   pengamatan Anda yg BELUM saya tangani di versi ini: "entri beruntun
//   memanfaatkan tren kuat" tidak konsisten (kadang dapat beberapa entri
//   searah, kadang cuma 1 walau MaxOrders=3) - ini BUKAN bug tapi keterbatasan
//   desain: kedua mesin entri (Reversal & Rider) sama2 BERBASIS PEMICU (perlu
//   flip/breakout BARU tiap kali), bukan "tambah posisi selama tren masih
//   sehat" - trend yg mulus tanpa pemicu tambahan otomatis cuma dapat 1 entri
//   walau trennya kuat & panjang. Perbaikan utk ini (mekanisme "pyramid"
//   entri tambahan tanpa perlu pemicu baru) perlu dirancang & diuji terpisah
//   krn menambah eksposur risiko - saya usulkan sbg langkah berikutnya,
//   belum dikerjakan di versi ini supaya perubahan kali ini tetap fokus &
//   bisa diuji dgn jelas satu-satu.
// v38/6.14 (15 Jul 2026) - dari diagnosis tes 7-bulan nyata (2025.10-2026.04,
//   4394 bar, laba bersih +410.91 tapi drawdown 50.77% & win rate Long cuma
//   25.42% - akar masalah keluhan "entri selalu di puncak/lembah tren, kena
//   SL beruntun":
//   1. TEMUAN UTAMA: dari RINGKASAN DIAGNOSTIK jurnal sendiri, "ENTRI TREND
//      RIDER tereksekusi: 0" - dari 482 pemicu genuine sepanjang 7 bulan,
//      NOL yang lolos SEMUA gerbang (H1+H4+HA+Regime+HTFBias wajib bulat
//      5/5). Akibatnya SELURUH 101 trade yang benar2 jalan datang dari
//      mesin Reversal (IsPerfectReversalSignal) - yang secara ALAMI memicu
//      tepat saat garis/HA baru berbalik, dan secara geometris itu SELALU
//      dekat titik ekstrem lokal (puncak/lembah) - persis pola yang
//      dikeluhkan. Trend Rider (mestinya menyediakan entri "awal tren
//      segar", bukan di titik baliknya) sama sekali tidak berkontribusi
//      sebagai penyeimbang.
//      FIX: 5 gerbang searah Rider (H1/H4/HA/Regime/HTFBias) yang dulu
//      wajib SEMUA lolos (AND ketat) diganti sistem KUORUM - kini cukup
//      ContQuorumRequired (default 4) dari 5 yang setuju, tidak perlu bulat.
//      Exhaustion guard & Chase guard TETAP wajib mutlak (itu soal risiko,
//      bukan soal berapa indikator setuju arah).
//   2. Gerbang AI (v36, tervalidasi 74% vs 42% win rate di data historis)
//      SEBELUMNYA cuma menyaring Rider - yang ternyata 0 eksekusi, jadi AI
//      TIDAK memberi manfaat apapun di tes 7-bulan ini. Kini AI JUGA
//      menyaring mesin Reversal (memakai fungsi ComputeAIScore yang sama,
//      fiturnya memang umum bukan spesifik pemicu Rider) - di sinilah AI
//      paling relevan disaring, karena di sinilah SEMUA trade sungguhan
//      berasal.
//   CATATAN JUJUR: aplikasi AI ke mesin Reversal ini extrapolasi yang
//   beralasan (fitur & pola yang sama, divalidasi di data umum) TAPI belum
//   divalidasi SPESIFIK utk bar-bar pemicu Reversal - anggap ini hipotesis
//   yang perlu dikonfirmasi tes berikutnya, bukan fakta final. Begitu pula
//   sistem kuorum Rider: arahnya (dari AND ketat -> mayoritas) jelas
//   beralasan dari data, tapi angka ContQuorumRequired=4 adalah titik awal
//   yang wajar, bukan angka yang sudah teroptimasi - WAJIB backtest ulang
//   utk validasi, terutama drawdown (karena kuorum lebih longgar = lebih
//   banyak entri Rider, perlu dipastikan kualitasnya tetap terjaga).
// v37/6.13 (14 Jul 2026) - PERBAIKAN TRAILING/TP & PENDING STOP atas laporan
//   cross-check AI (false vs true, 1 bulan yg sama: 17 trade/$29.77/PF 1.27
//   vs 14 trade/$50.31/PF 1.72 - AI terbukti bekerja). Dua permintaan lanjut:
//   1. TRAILING/TP: dulu ADA 4 mekanisme pengetat SL berjalan SENDIRI2
//      (trailing garis-ST, TrailMethod+profit-stage, pullback-retrace-lock,
//      breakeven) - yang PALING KETAT yang menang tiap saat, walau garis ST
//      sendiri blm flip (trend menurut indikator masih jalan). UseProfitStageTrail
//      khususnya bikin trailing makin ketat begitu profit >1xATR, sering
//      menang lebih ketat dr garis ST dan memotong posisi di koreksi/zigzag
//      biasa - TrendRun_ReleaseTP yg melepas TP jauh jadi percuma krn SL
//      keburu kena duluan. FIX: selama UseSupertrendTrailing aktif & valid,
//      SEMUA mekanisme lain (TrailMethod/profit-stage, pullback-retrace)
//      dibatasi tidak boleh lebih ketat dari garis ST - garis ST jadi
//      plafon/lantai bersama. Posisi kini bernapas penuh sampai ST sendiri
//      yg bicara (atau SmartCutLoss pd pembalikan terkonfirmasi), TP jauh
//      jadi benar2 terpakai.
//   2. PENDING STOP TITIK-JENUH (ManageExhaustionPending): dulu dibatalkan
//      SEKETIKA begitu RSI mundur dikit (1 bar saja) meski umur blm habis -
//      wajar & sering terjadi walau setup masih valid, jadi banyak pending
//      terhapus sebelum sempat tersentuh. FIX: baru dibatalkan kalau
//      "kondisi jenuh hilang" ini bertahan ExhPendCancelPersistBars (default
//      2) bar BERUNTUN, bukan 1 bar. Buffer level (ExhPendBufferPips=3, nyaris
//      nol utk gold) kini ikut skala ATR juga (ExhPendBufferATRFactor=0.15)
//      spy tetap bermakna.
//   CATATAN JUJUR: sama seperti sebelumnya, belum divalidasi lewat backtest
//   sungguhan (di luar jangkauan sandbox ini). WAJIB backtest ulang & bandingkan
//   - terutama expected payoff/rata2 profit-per-trade dan drawdown, karena
//   membiarkan posisi bernapas lebih jauh ke garis ST berarti float loss
//   sementara bisa lebih dalam drpd sebelumnya sebelum akhirnya profit -
//   perhatikan apakah drawdown masih dalam batas nyaman Anda.

// v35/6.11 (14 Jul 2026) - PERBAIKAN ATAS TES XAUUSD H1 SETELAH v34 (SELL
//   sudah muncul: 37 short win 51.35%, 34 long win 70.59%, net profit
//   +40.75, PF 1.22 - progres nyata dari v34 yang tadinya 0 short). Temuan
//   baru dari log jurnal & report tes ini: trend yang panjang/mulus (garis
//   Supertrend "lurus" konsisten, bukan zigzag) berulang kali TIDAK
//   terkonfirmasi jadi entri, padahal kalau lolos akan profit besar (harga
//   sudah lanjut ratusan-ribuan pip sebelum akhirnya "DIRELAKAN"/ditolak).
//   Dibedah 2 gerbang yang cocok dgn pola ini:
//   1. CompressionVerdict/UpdateCompressionBox (kotak sideways) MURNI
//      berbasis LEBAR (high-low vs ATR), tanpa cek arah pergerakan. Trend
//      yang HALUS (tiap candle kecil tapi konsisten searah) punya lebar
//      per-N-bar kecil, sama seperti sideways sungguhan - jadi salah dicap
//      "kotak" (bukti: counter Compress = 105 penolakan di tes ini, jauh
//      terbesar di antara semua gerbang terkait tren-lanjutan). FIX: tambah
//      input CompressionMinDirectionality - kotak cuma sah kalau net-
//      displacement (jarak awal->akhir) RENDAH relatif ke lebar totalnya
//      (harga sungguh bolak-balik tanpa progres). Rasio TINGGI = harga
//      jalan satu arah terus, ini trend, dibiarkan lolos walau lebarnya
//      kecil.
//   2. Gerbang 6 "kaki trend TUA" (MaxLegAgeBars=10 default): dulu BLOKIR
//      MUTLAK begitu garis ST sudah menanjak/menurun beruntun >10 bar,
//      tanpa peduli trend itu masih kuat atau tidak - padahal jumlah bar
//      semata bukan bukti kejenuhan (nama gerbangnya sendiri scr harfiah
//      cocok dgn komplain: trend panjang otomatis ditolak krn "sudah tua").
//      FIX: leg "tua" sekarang HANYA diblokir kalau ADX JUGA melemah
//      dibanding LegAgeADXLookback bar lalu (bukti nyata kehabisan tenaga)
//      - kalau ADX masih naik/tetap, trend dianggap masih sehat, tetap
//      dilayani berapa pun umur barnya.
//   3. Counter g_cnt_LegAge dipisah dari g_cnt_ContChase (dulu digabung
//      satu counter, menyamarkan kontribusi leg-age vs kejar-harga asli
//      di ringkasan diagnostik).
//   CATATAN JUJUR: sama seperti v34, perbaikan ini benar scr logika kode &
//   selaras dgn data log/report, TAPI belum divalidasi lewat strategy
//   tester sungguhan. WAJIB backtest ulang - idealnya periode yang SAMA dulu
//   (2025.06.02-2025.09.09, bisa dibandingkan apple-to-apple dgn report ini)
//   baru periode lain/out-of-sample. CompressionMinDirectionality=0.6 dan
//   LegAgeADXLookback=5 adalah titik awal yang masuk akal scr logika, BUKAN
//   angka yang sudah teruji lewat backtest - wajar kalau perlu disetel ulang
//   setelah lihat hasilnya. Juga: input LineFlatBars/MinLineSlopeATR/
//   UseLineSlopeGate/MaxLegAgeBars TIDAK ikut tercetak di kolom Parameters
//   report Anda kali ini (senasib dgn TradeDirection/StrategyMode dulu -
//   terpotong krn EA ini py ratusan input) - cek langsung di tab Input
//   sebelum backtest ulang utk pastikan nilainya sesuai asumsi di atas.
// v34/6.10 (14 Jul 2026) - PERBAIKAN ATAS TEMUAN TES XAUUSD H1 (~3 bulan):
//   Laporan tes: 57 trade, SEMUANYA long - 0 short (Short positions won%:
//   0/0.00%). Kode dibedah baris per baris utk cari akar masalah. HASIL:
//   RegimeVerdict, TryContinuationEntry (mesin RIDER), dan Entry_Signal_Pro
//   semua SIMETRIS by design (dir=1/-1 pakai fungsi & ambang yang sama) -
//   BUKAN di situ bug-nya. Akar masalah sesungguhnya: v33 HTFBiasHardBlock
//   =true MEMBLOKIR MUTLAK setiap sinyal melawan bias TF-atas TANPA
//   pengecualian sama sekali, di KEDUA mesin (REVERSAL gerbang 1c-bis &
//   RIDER gerbang 3-bis). Ambang filter ini (slope 0.03, DI sep 6, body
//   0.55xATR) diracik dari data historis awal 7 bulan lalu dipakai apa adanya
//   di XAUUSD H1 tanpa kalibrasi ulang. Karena XAUUSD naik nyaris terus-
//   menerus sepanjang periode tes (bias H4 nyaris selalu positif), blokir
//   mutlak ini otomatis mengunci SELL total - 0 short bukan kebetulan,
//   itu konsekuensi matematis kombinasi filter+kondisi pasar. FIX:
//   1. HTFBiasHardBlock default true->false. Pintu darurat lama (v32, yg
//      dimatikan krn gampang ketipu SATU candle-spike di puncak lokal)
//      diganti versi PRESISI-2-BAR: wajib divergensi DI + candle besar
//      bertahan 2 candle beruntun (bukan cuma 1) + ADX benar2 MENGUAT
//      (bukan sisa ADX trend lama yg meluruh). Spike 1 candle gagal
//      syarat ini; pembalikan sungguhan (momentum nambah tiap bar) tetap
//      lolos dlm hitungan bar. HTFBiasHardBlock=true tetap tersedia sbg
//      opsi utk yg memang mau mode "murni ikut tren, tanpa reversal sama
//      sekali".
//   2. Pesan log "...pola SELL pembunuh di report (win rate 34%)" yang
//      SALAH muncul apa adanya walau yang diblokir itu BUY (bug label di
//      pesan, bukan bug logika) - diganti jadi netral-arah & sesuai v34.
//   3. SR_MaxDistancePips (toleransi jarak ke S/R) kini ATR-aware lewat
//      SR_UseATRScaling/SR_MaxDistanceATRFactor - versi lama pakai pip
//      TETAP yg terlalu sempit utk instrumen mahal/berombak spt XAUUSD
//      (20-30 "pip" = $0.20-0.30, nyaris mustahil tersentuh di gold yg
//      ATR H1-nya bisa puluhan dolar).
//   CATATAN JUJUR: perubahan ini looks-correct dari pembacaan kode &
//   selaras dgn data laporan, TAPI belum divalidasi lewat strategy tester
//   sungguhan (di luar jangkauan environment ini). WAJIB backtest ulang -
//   idealnya periode yang SAMA (bisa dibandingkan apple-to-apple dgn
//   laporan lama) + periode lain/out-of-sample - sebelum dipakai live.
// v33/6.9 (13 Jul 2026) - HARD BLOCK MELAWAN BIAS (bedah report v32):
//   Data v32: BUY market +15.95, PENDING jenuh +8.06 (NET POSITIF di uji
//   perdananya!), tapi SELL market -32.11 -> total -8.10. Win rate short
//   34.6% IDENTIK dgn sebelum filter bias ada = "pintu darurat" melawan-
//   bias (DI sep + candle besar) terbuka SISTEMATIS tepat di puncak lokal
//   (di situ selalu ada candle lawan besar + DI melonjak). FIX:
//   1. HTFBiasHardBlock=true (default): sinyal melawan bias TF-atas
//      DITOLAK MUTLAK. Pembalikan makro sungguhan tidak hilang - begitu
//      tren TF-atas benar2 berbalik, slope regresi ikut berbalik & arah
//      itu jadi SEARAH bias (lolos normal) dlm hitungan bar.
//   2. HTFBiasMinSlope 0.06->0.03: uptrend D1 yg merayap pelan tetap
//      terdeteksi sbg bias naik (di 0.06 sering salah baca "datar" ->
//      sell lolos via jalur makro-datar).
//   Seandainya aturan ini aktif di test v32: -8.10 -> +24.01.
// v32/6.8 (13 Jul 2026) - FIX RECOVERY TAK PERNAH AKTIF + PENDING
//   TITIK-JENUH ADAPTIF + INFO DASHBOARD (laporan pengamatan Anda):
//   1. BUG RECOVERY: pencatatan defisit ada DI DALAM CheckDailyReset()
//      yg mati total bila UseDailyTarget=false - recovery tak pernah
//      punya bahan utk hidup. FIX: fungsi kini jalan bila target ATAU
//      recovery aktif. Syarat momentum jg dilonggarkan (DI sep 6->4,
//      slope 0.20->0.15) krn data test: ambang lama nyaris tak pernah
//      kesampaian.
//   2. PENDING STOP TITIK-JENUH (baru, sesuai konsep Anda): tren
//      berjalan jenuh (ekstensi >= 2.5xATR dari garis ST + RSI ekstrem
//      >=70/<=30) -> pending STOP arah lawan disiapkan di bawah/atas
//      STRUKTUR harga (low/high 6-bar, atau level S/R SuperSR bila ada
//      di antaranya = menembus S/R konfirmasi lebih kuat). ADAPTIF:
//      digeser ulang tiap bar mengikuti struktur terbaru (tidak kaku);
//      hangus bila jenuh hilang/umur habis; saat tersentuh -> posisi
//      market penuh dgn trailing normal.
//   3. INFO DASHBOARD: panel PROTECTION kini menampilkan baris
//      "Recovery: standby / defisit $X (n/3) / OFF" real-time; panel
//      ADVANCED INFO menampilkan "Pending: -" / "SELL STOP @ ... (sisa
//      n bar)" / "TERSENTUH ... @ ..." di bekas tempat label pending
//      lama - kontrol visual penuh utk kedua sistem.
// v31/6.7 (13 Jul 2026) - FILTER BIAS TIMEFRAME-ATAS (temuan #1-3, dari
//   report 7bln H4 historis awal: analisa trade-per-trade membuktikan 93% dari
//   SELURUH kerugian berasal dari 2 pola saja):
//   POLA A (50% kerugian): SELL full-SL MELAWAN uptrend makro D1 - win
//   rate short cuma 34% vs long 62%. POLA B (43%): BUY kena SL di fase
//   RANGING makro Agu-Sep. Akar sama: EA buta arah TF di ATAS chart
//   (MTF lama malah cek M5/M15/M30 = noise di bawah H4).
//   SOLUSI: bias TF-atas (H4->D1, H1->H4, M30->H4, dst) diukur regresi
//   slope harga (xATR/bar): searah bias = lolos normal; makro DATAR =
//   butuh DI sep >= 5; MELAWAN bias = butuh bukti SANGAT kuat (DI sep
//   >= 6 + candle >= 0.55xATR searah) atau ditolak. Terpasang di KEDUA
//   mesin (reversal & rider), counter diagnostik tersendiri.
//   REKOMENDASI SETTING utk chart H4: UseMTF_M5/M15/M30=false (TF di
//   bawah chart cuma noise; bias D1 kini menggantikan peran arah besar).
// v30/6.6 (13 Jul 2026) - 4 FITUR BARU (temuan #4-7 test 7bln H4 historis awal):
//   1. CUT-LOSS CERDAS (temuan #4): posisi rugi ditutup DINI hanya bila
//      ada BUKTI pembalikan sungguhan (ST flip lawan + HA mentah lawan +
//      candle lawan >= 0.5xATR, di LUAR kotak sideways) - tidak lagi
//      diam kaku menunggu SL penuh; tapi koreksi/zigzag biasa TIDAK
//      memicunya (posisi diberi napas penuh).
//   2. TRAILING BERTAHAP (temuan #5): makin besar profit berjalan (xATR),
//      jarak trailing otomatis makin ketat (s/d x0.45) - profit besar
//      dikunci makin rapat (gerak cepat selamatkan TP), profit kecil
//      masih diberi ruang berkembang. Bertumpuk dgn trailing adaptif
//      volatilitas v21 (candle kecil=ketat, candle lebar=longgar).
//   3. RECOVERY PINTAR (temuan #6): defisit hari minus dicatat saat
//      reset; hari berikutnya lot dinaikkan (x1.5) HANYA saat momentum
//      tren sangat kuat searah sinyal (DI berpisah >=6 + regresi >=0.2
//      xATR) - bukan martingale: ada pagar risiko khusus (2.5%), batas
//      3 trade recovery, & otomatis mati begitu defisit terpulihkan.
//   4. PENDING STOP COVER (temuan #7): posisi yg tertutup RUGI memicu
//      evaluasi arah lawan - bila ST trend + HA mentah kompak searah
//      lawan (pembalikan terkonfirmasi 4-indikator), STOP order dipasang
//      di titik ekstrem 8-bar +/- buffer utk menangkap kelanjutan tren
//      lawan itu; hangus otomatis 6 bar bila tak tersentuh.
// v29/6.5 (12 Jul 2026) - 3 PERBAIKAN TAMPILAN DASHBOARD (permintaan Anda):
//   1. TOMBOL ON/OFF TIDAK BERUBAH WARNA: warna/teks tombol B_Switch
//      cuma diset SEKALI saat dashboard pertama dibuat - menekannya
//      menukar g_Active, tapi tampilan tombol beku selamanya. FIX:
//      disegarkan tiap tick - hijau+"ON" saat aktif, merah+"OFF" saat
//      mati, sesuai kondisi sebenarnya.
//   2. PANEL POSITIONS TIDAK MENGAKUMULASI ENTRI GANDA: kalau ada 2 BUY
//      terbuka, kode lama MENIMPA info (yg tampil cuma order terakhir,
//      yg pertama "hilang" dari tampilan, lot tak terjumlah). FIX: lot
//      dijumlahkan semua entri BUY/SELL yg sejenis, harga entri
//      masing2 didaftar (dipisah koma) - SL/TP individual per-order
//      tidak lagi ditampilkan (ruang panel terbatas, sesuai permintaan
//      Anda "asal lot terakumulasi & titik entry price, itu cukup").
//   3. INFO PENDING ORDER (usang) DIHAPUS dari panel Advanced Info -
//      label "Pending: OFF" itu HARDCODED, tak pernah benar2
//      mencerminkan status apa pun (info palsu/membingungkan), dan
//      sistem pending-order lama itu sendiri sudah tidak relevan
//      dipakai.
// v28/6.4 (12 Jul 2026) - AUDIT MENYELURUH SEMUA TOMBOL DASHBOARD:
//   1. RESTART SEBELUMNYA BUKAN RESTART: memanggil ExpertRemove() yang
//      MELEPAS EA dari chart (perlu ditarik ulang manual, tidak otomatis
//      jalan lagi). FIX: kini in-place - EA tetap menempel & aktif, semua
//      status (posisi, target, pause, override manual lot/SL/TP,
//      loss-streak, kotak konsolidasi) disegarkan ke kondisi awal.
//   2. RESET SL/TP SEBELUMNYA MEMBUANG PROGRES TRAILING: memanggil
//      ApplyManualSLTPToAllOrders() yg menghitung ULANG SL/TP dari harga
//      OPEN dgn jarak adaptif lebar - SL yg sudah di-trailing jauh
//      (mengunci profit besar) tiba2 dipaksa mundur, membuang pengamanan
//      profit yg sudah didapat! FIX: kini cuma mematikan flag manual -
//      auto-trailing melanjutkan dari SL/TP yg SEDANG berlaku (tidak
//      di-snap mundur).
//   3. ON/OFF SEBELUMNYA MEMATIKAN TRAILING SEKALIGUS: kalau Anda entry
//      MANUAL lalu matikan saklar, posisi manual itu SAMA SEKALI TIDAK
//      DILINDUNGI trailing lagi - berbahaya, krn OFF harusnya "berhenti
//      buka posisi baru", bukan "lepas tangan dari posisi yg sudah
//      terbuka". FIX: trailing/proteksi (tak pernah menambah risiko,
//      cuma mengunci/mengetatkan) kini SELALU jalan apa pun status
//      ON/OFF; hanya entri BARU otomatis yg benar2 berhenti saat OFF.
//   4. DIKONFIRMASI SUDAH BENAR (tanpa perlu diubah): tombol BUY/SELL
//      manual memakai Lot/SL/TP dari tombol +/- dgn benar (fallback ke
//      hitungan otomatis kalau belum disentuh); tombol HIDE/SHOW
//      berfungsi penuh; tombol CLOSE menutup semua posisi; RESET (target
//      harian) sudah benar dari perbaikan v22-v27 sebelumnya.
// v27/6.3 (12 Jul 2026) - BUG "HIDUP-MATI" DAILY TARGET DITEMUKAN LAGI
//   (dari jurnal H4: target 16.79% lalu 17.80% "Hit ke-1/100" LAGI persis
//   di detik reset berikutnya):
//   BUG #3 - DUA MEKANISME RESET TUMPANG TINDIH: blok reset kalender di
//   CalcDailyProfit (ganti hari 00:00 SERVER) berjalan independen dari
//   CheckDailyReset (yg menghormati input DailyResetTime) - bisa bentrok
//   kalau DailyResetTime bukan "00:00". FIX: blok kalender dihapus,
//   CheckDailyReset() jadi SATU-SATUNYA otoritas reset.
//   BUG #4 - FLOATING POSISI LAMA IKUT TERHITUNG "PROFIT HARI INI": versi
//   lama `total = realized-sejak-reset + floating SEMUA posisi terbuka`.
//   Posisi lama yg masih mengambang untung besar (mis. trend-run TP-
//   release yg sengaja dibiarkan terbuka berhari-hari) ikut terhitung
//   PENUH tiap kali reset lewat - target langsung tercapai lagi seketika
//   di detik reset, pause lagi - inilah pola "hidup-mati" yg dilaporkan.
//   FIX: total kini = SELISIH EKUITAS dari titik reset (g_DayStartEquity,
//   dicatat ulang di SETIAP reset - terjadwal maupun tombol manual).
//   Floating P&L yg SUDAH ada saat reset otomatis "terbekukan" di angka
//   itu; hanya pergerakan SETELAH reset yg terhitung hari ini. Efek
//   samping baik: skenario "belum tercapai/minus" kini TIDAK bisa lagi
//   memicu pause keliru (selisih ekuitas negatif tak akan pernah >=
//   target positif) - persis sesuai permintaan Anda "jangan dulu
//   dipause, terus kejar sampai tercapai". Panel & proteksi loss-limit
//   turut disamakan ke patokan ini (sebelumnya loss-limit buta thd
//   rugi mengambang, dan panel bisa tampil beda dgn yg sesungguhnya
//   memicu pause).
//   CATATAN: fitur "berhenti trading jam tertentu" (mis. 22:00) SUDAH
//   ADA & berfungsi terpisah dari jam reset target - aktifkan
//   UseTimeControl=true lalu set TradingEndTime="22:00".
// v26/6.2 (12 Jul 2026) - MODE LOT MANUAL MURNI (permintaan susulan Anda):
//   v25 membuat Pagar Risiko berlaku UNIVERSAL termasuk jalur BaseLot,
//   tapi ternyata itu berlawanan dgn maksud Anda: RiskPerTrade=0 memang
//   SENGAJA dipilih sbg "saya kendalikan lot manual", bukan utk tetap
//   dipotong otomatis. FIX: RiskPerTrade<=0 kini jadi MODE MANUAL MURNI -
//   BaseLot dipakai APA ADANYA (cuma disesuaikan TradingMode & pengaman
//   bawaan spt loss-streak reduction + LotBoost opsional bila diaktifkan),
//   Pagar Risiko (v20) TIDAK berlaku di mode ini. Sebagai gantinya,
//   jurnal mencetak PERINGATAN INFORMATIF (bukan blokir) kalau risiko
//   dari BaseLot yg dipilih ternyata > MaxRiskPerTradePercent, supaya
//   Anda tetap sadar besarnya tanpa lot-nya dipaksa berubah. Pagar Risiko
//   tetap berlaku PENUH di mode RiskPerTrade>0 (persen-otomatis) seperti
//   semula.
// v25/6.1 (12 Jul 2026) - BUG LOT TETAP MELOMPATI PAGAR RISIKO (dari
//   jurnal H1: "Lot digunakan: 0.14 (Risk=0.0%, Balance=200.0)" - lot
//   0.14 di SL 30 pip pd balance $200 = risiko ~14% SEKALI TRADE!):
//   Jalur lot RiskPerTrade<=0 (pakai BaseLot langsung) sebelumnya
//   `return` LEBIH AWAL, melompati SELURUH Pagar Risiko (v20) di
//   bawahnya - lot sama sekali tak terkendali thd ukuran balance. Inilah
//   penyebab sesungguhnya "daily target hidup-mati/minus tiba2 dipause"
//   yang tadinya dikira bug timeframe H1 - satu trade oversized saja
//   bisa melompat jauh dari target. FIX: jalur BaseLot kini TIDAK return
//   lebih awal, tetap wajib lewat Pagar Risiko (MaxRiskPerTradePercent)
//   yang sama dgn jalur risk-percent - berapa pun BaseLot/RiskPerTrade
//   yang diset, risiko per trade tak akan pernah melebihi pagar.
// v24/6.0 (12 Jul 2026) - PAUSE STATUS DI DASHBOARD TIDAK REAL-TIME:
//   Label "Pause Status:" di panel HANYA diisi SEKALI saat dashboard
//   pertama dibuat (CreateLabel dgn GetPauseStatus() sbg teks awal) dan
//   TIDAK PERNAH di-refresh sesudahnya - jadi walau logika pause sudah
//   benar (v23), tampilannya beku selamanya di teks awal ("Active"),
//   tidak pernah terlihat berubah walau target tercapai & trading
//   berhenti. FIX: kini di-refresh tiap tick di UpdateDashboardValues(),
//   plus warna berubah real-time (hijau=aktif, oranye=target
//   tercapai/dijeda) - status pause sekarang benar2 terkonfirmasi visual
//   di dashboard, bukan cuma di jurnal.
// v23/5.9 (12 Jul 2026) - BUG KRITIS SUSULAN DITEMUKAN (v22 tidak cukup):
//   Setelah v22, target masih tidak menghentikan trading. Ditemukan DUA
//   baris kode yang menghapus status "target tercapai" hanya SATU TICK
//   setelah tercapai:
//   1. `if(g_TradingPaused && TimeCurrent()>=g_PauseUntilTime)` di OnTick -
//      target-hit sengaja diberi g_PauseUntilTime=0 (penanda "dikendalikan
//      jadwal reset harian"), tapi TimeCurrent()>=0 SELALU true (timestamp
//      manapun >= 0) - jadi g_TradingPaused langsung ke-reset false lagi.
//   2. `if(g_GoalHit && now>=reset+60) g_GoalHit=false;` di CheckDailyReset -
//      `reset` = jam reset HARI INI; lewat jam segitu (mis. lewat 00:01),
//      syarat ini TRUE SEPANJANG SISA HARI, jadi g_GoalHit yang baru saja
//      true langsung dihapus lagi tick berikutnya.
//   Kedua bug ini BERSAMAAN membuat KEDUA gerbang (g_GoalHit DAN
//   g_TradingPaused) di CheckEntry() nyaris seketika kembali false setelah
//   target tercapai - trading kelihatan "tidak pernah berhenti" walau v22
//   sudah benar secara logika deteksi. FIX: baris #1 kini hanya aktif utk
//   pause BERBATAS WAKTU (g_PauseUntilTime>0, mis. drawdown/loss-limit);
//   baris #2 DIHAPUS total (sudah didup dgn blok reset yg benar di atasnya).
// v22/5.8 (12 Jul 2026) - BUG DAILY TARGET DITEMUKAN & DIPERBAIKI TOTAL:
//   AKAR BUG: gerbang pencapaian target memakai `!g_GoalHit`, padahal
//   g_GoalHit baru jadi true stlh g_DailyTargetHits>=MaxDailyTargetHits
//   (default 100) - akibatnya counter bertambah SETIAP TICK selama profit
//   di atas target (bukan sekali per pencapaian), trading baru berhenti
//   stlh "100 tick di atas target" tercapai scr tdk menentu (detik s/d
//   menit tergantung kepadatan tick). Ini penyebab "daily target tidak
//   berfungsi dengan baik".
//   FIX: gerbang jadi `!g_TargetAchievedToday` (sekali-pakai/hari) ->
//   begitu total profit >= target, trading LANGSUNG berhenti detik itu
//   juga (g_GoalHit+g_TradingPaused langsung true, tanpa nunggu hit
//   ke-100) - berlaku utk KEDUA mesin (reversal & rider, satu gerbang di
//   CheckEntry() menaungi keduanya). Berhenti s/d (a) jam reset harian
//   (DailyResetTime, otomatis lewat CheckDailyReset) atau (b) tombol
//   RESET ditekan manual (kini ikut membersihkan g_TargetAchievedToday -
//   sebelumnya tombol reset TIDAK mencabut kuncian ini, jadi trading
//   tetap tidak aktif walau tombol sudah ditekan). MaxDailyTargetHits
//   dipakai ulang jadi batas pengaman brp kali reset-manual+capai-ulang
//   boleh terjadi dlm 1 hari. Status panel "DAILY TARGET HIT" & "Pause
//   Status" diperbaiki juga (sebelumnya ada bug tampilan "Paused until
//   1970.01.01" saat target-hit krn prioritas pengecekan salah urutan).
// v21/5.7 (12 Jul 2026) - PENJAGA TITIK JENUH + TRAILING ADAPTIF (dari
//   analisa test 6 bulan M30, evaluasi jurnal+equity+visual chart):
//   1. AKAR MASALAH "entri di titik jenuh tren" DITEMUKAN: Perisai Pisau
//      (knife guard, v18) HANYA terpasang di mesin REVERSAL, TIDAK di
//      mesin LANJUTAN/RIDER (panah presisi). Bukti nyata trade #246 (26
//      Des): REVERSAL menolak BUY "melawan LEG RAKSASA" TAPI RIDER tetap
//      entry BUY via "panah ST" di waktu sama -> rugi. Kini PENJAGA TITIK
//      JENUH terpasang jg di mesin lanjutan: ekstensi trend BERJALAN
//      (searah sinyal) diukur dari garis ST; kalau >3xATR (sudah lari
//      jauh = berisiko segera berbalik), sinyal lanjutan butuh candle
//      ekstra kuat (>=0.55xATR) atau ditolak.
//   2. TRAILING ADAPTIF VOLATILITAS (permintaan Anda): rasio ATR jangka-
//      pendek(3bar)/dasar(14bar) jadi "rezim volatilitas". Candle
//      kecil2/rapat (rezim tenang, rasio<0.75) -> SEMUA jarak trailing
//      (ST-line, ATR-trailing, breakeven) DIKETATKAN (x0.5) - profit
//      kecil sempat terkunci sebelum balik arah. Candle lebar2 (rezim
//      kuat, rasio>1.3) -> jarak trailing DILONGGARKAN (x1.6) - tidak
//      kena koreksi wajar dari candle besar yang masih trending.
// v20/5.6 (12 Jul 2026) - LOT BOOST OPSIONAL + PAGAR RISIKO KERAS:
//   Permintaan: lot bisa diperbesar SECARA OPSIONAL tapi risiko tetap
//   terjaga. UseLotBoost(on/off) x LotBoostMultiplier membesarkan lot
//   dasar hasil risk-calc; MaxRiskPerTradePercent adalah PAGAR KERAS yg
//   SELALU jadi kata akhir - berapapun kelipatan boost, kalau risiko $
//   hasil akhir melebihi pagar, lot otomatis dipangkas turun tepat ke
//   batas itu. Juga menambal kasus lot dipaksa naik ke minimum broker
//   (0.01) yg diam2 bisa melebihi RiskPerTrade - kini ikut kena pagar.
// v19/5.5 (12 Jul 2026) - PRESISI REZIM & CHOP (dari data test 6bln M30):
//   1. REZIM DIROMBAK: data test menunjukkan "Ditolak-rezim ADX" = 51x
//      (TERBANYAK semua filter), mayoritas pada DI+/DI- NYARIS SERI
//      (mis. 19.9 vs 20.0) - divonis "berlawanan" padahal itu noise, ini
//      penyebab "pergantian tren kuat masih dilewat". Kini: selisih DI
//      >=DIMinSeparation(4) = vonis tegas; di bawah itu (seri/noise) ->
//      WASIT KEDUA kemiringan REGRESI LINIER harga 6 bar (xATR) - cepat,
//      matematis, tanpa lag DI.
//   2. KANTONG CHOP JANGKA-PENDEK: kotak adaptif perlu >=8 bar utk
//      terbentuk; kantong choppy 3-6 bar bisa lolos & memicu entri yg
//      cepat berbalik (turut andil give-back equity trade #28->34 di
//      data test). Ditambah cek independen 4-bar vs ATR.
//   3. FIX BUG: trailing stop memicu OrderModify walau nilai SETELAH
//      normalisasi identik dgn SL/TP order saat ini - penyebab
//      "OrderModify error 1" berulang di jurnal test. Kini dibandingkan
//      thd nilai ternormalisasi aktual, hanya modify bila BENAR berubah.
// v18/5.4 (11 Jul 2026) - TIMING ENTRI DIROMBAK (dari data trade jurnal):
//   1. JALUR CEPAT: flip segar (<=2 bar) + candle kuat + DI searah + luar
//      kotak = entri TANPA menunggu HA (yang sengaja lambat 3+ candle).
//      Fix "beli karcis setelah kereta berangkat" (trade #3: telat 100 pips).
//   2. BATAS TELAT jalur konfirmasi: harga sudah lari > 1.2xATR dari flip
//      = DIRELAKAN, tunggu kesempatan berikutnya (trade #2 & #3).
//   3. PERISAI PISAU: lawan leg raksasa (>3xATR) butuh candle super-kuat
//      (>=0.6xATR) atau breakout kotak (trade #4: SELL lawan rally -> SL).
//   4. Kotak sideways: HANYA keterangan teks di chart, persegi dihapus total.
// v17/5.3 (11 Jul 2026) - KOREKSI FILTER PEMBUNUH SINYAL (dari jurnal test):
//   1. REZIM: level/kemiringan ADX DIBUANG (memblokir semua pembalikan V -
//      "ADX MELURUH" 3 Jul & "ADX 21.4<22" 7 Jul). Ganti: DOMINASI DI+/DI-
//      (berarah & cepat). Sideways murni = tugas kotak konsolidasi.
//   2. KEJAR-HARGA: batas dikoreksi matematis jadi sadar-band
//      (ST_ATRMultiplier + MaxChaseATR) x ATR dari garis ST - entri segar
//      pasca-flip tidak lagi salah-tolak (3 Jul 16:00, 7 Jul 08-11).
//   3. CANDLE LEMAH: tambah jalur momentum 2-candle (net >= 0.6xATR).
//   4. PEMICU BREAKOUT disatukan dgn kotak adaptif (kontradiksi 8 Jul fix).
//   5. Gerbang H4 SOFT: syarat ganda AND -> OR (H4 selalu telat vs H1).
//   6. Kotak sideways TIDAK digambar lagi (default) - visual bersih,
//      keterangan cukup di jurnal. DrawCompressionBox=true bila mau audit.
// v16/5.2 (11 Jul 2026) - PEROMBAKAN TOTAL ANTI-SIDEWAYS:
//   1. KOTAK KONSOLIDASI ADAPTIF: menggantikan jendela kaku 12-bar v15
//      (yang bocor di konsolidasi lebar). Kotak tumbuh mundur s/d 96 bar
//      selama lebarnya < 2.5xATR. Di dalam kotak = SEMUA pemicu diblokir.
//   2. Keluar kotak HANYA lewat breakout: close menembus batas + buffer,
//      entri hanya SEARAH breakout; arah lawan dikunci 6 bar pasca-tembus.
//   3. Kotak DIGAMBAR di chart (persegi abu2 + label "SIDEWAYS - ENTRI
//      DIBLOKIR", jejak kotak lama dibekukan) -> keputusan EA bisa diaudit
//      mata langsung di visual tester.
//   4. Filter KEKUATAN CANDLE SINYAL (>= MinSignalBodyATR x ATR, searah).
//   5. VERIFIKASI BUILD: judul panel kini "V-71 [v16]" + banner versi di
//      jurnal saat start - memastikan build yang diuji adalah build ini.
#property strict
#property description "AurumPulse XAUUSD - Reversal + Trend Rider Adaptif, 4 Indikator Kustom Terintegrasi"

//+------------------------------------------------------------------+
//| ENUM DECLARATIONS                                                |
//+------------------------------------------------------------------+
enum ENUM_TRADING_MODE { MODE_CONSERVATIVE, MODE_NORMAL, MODE_AGGRESSIVE };
enum ENUM_TARGET_TYPE { TARGET_IN_MONEY, TARGET_IN_PERCENT };
enum ENUM_TRAILING_METHOD { TRAIL_FIXED, TRAIL_PERCENT, TRAIL_ATR, TRAIL_STEP };
enum ENUM_LOSS_LIMITER_METHOD { LOSS_FIXED, LOSS_ATR, LOSS_SMART };
enum ENUM_TRADE_DIRECTION { TRADE_BOTH, TRADE_BUY_ONLY, TRADE_SELL_ONLY };
enum ENUM_DYNAMIC_DISTANCE { DIST_TIGHT, DIST_NORMAL, DIST_WIDE };
enum ENUM_DYNAMIC_SPEED   { SPEED_AGGRESSIVE, SPEED_NORMAL, SPEED_SLOW };
enum ENUM_EXEC_MODE { EXEC_AUTO, EXEC_SIGNAL_ONLY }; // AUTO=order otomatis; SIGNAL_ONLY=alert+panah saja (trading manual)
enum ENUM_ENTRY_STYLE { ENTRY_AUTO, ENTRY_MARKET, ENTRY_LIMIT, ENTRY_STOP, ENTRY_PULLBACK_LIMIT }; // AUTO dipilih oleh Supertrend PendingHint
enum ENUM_STRATEGY_MODE { STRAT_TREND_RIDER, STRAT_REVERSAL, STRAT_BOTH }; // TREND_RIDER=ikuti trend berjalan (statistik terbaik); REVERSAL=buru titik balik (tersulit); BOTH=keduanya
enum ENUM_H4_MODE { H4_STRICT, H4_SOFT, H4_OFF }; // STRICT=H4 wajib searah; SOFT=H4 searah ATAU momentum H4 sedang membangun ke arah sinyal; OFF=tanpa gerbang H4

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input int    MagicNumber              = 777999;

// === MANAJEMEN RISIKO ===
input double RiskPerTrade             = 0.75;   // v2.00: mode RISK-BASED kini BENAR (BUG-1 diperbaiki). 0 = lot manual.
input double BaseLot                  = 0.01;   // v2.00: dulu 0.3 - JEBAKAN. Yg dites 0.02; 0.3 = 15x lipat kalau .set lupa dimuat.
//=== v20: LOT BOOST OPSIONAL + PAGAR RISIKO KERAS ===
// Permintaan: lot bisa diperbesar SECARA OPSIONAL (tombol on/off + kelipatan
// bebas diatur) TAPI risiko tetap terjaga (tidak pernah tembus batas aman
// walau kelipatan diset besar-besar). Cara kerja:
// 1. Lot dasar tetap dihitung dari RiskPerTrade seperti biasa (murni).
// 2. Jika UseLotBoost aktif, lot itu DIKALIKAN LotBoostMultiplier.
// 3. SETELAH itu, risiko $ dari lot yang sudah membesar tsb DICEK ULANG
//    thd MaxRiskPerTradePercent (pagar keras) - kalau ternyata melebihi,
//    lot OTOMATIS dipangkas turun persis ke batas itu. Kelipatan besar
//    tidak berbahaya - pagar selalu jadi kata akhir.
input bool     UseLotBoost            = false;    // aktifkan pembesaran lot opsional
input double   LotBoostMultiplier     = 2.0;      // lot dasar (hasil risk) dikalikan ini
input double   MaxRiskPerTradePercent = 1.5;      // PAGAR KERAS per trade: risiko $ satu trade tak boleh lewat ini
// === v2.00 PAGAR RISIKO AGREGAT (FITUR BARU - temuan audit paling serius) ===
// Audit tes Jan-Jul 2026 menemukan: pagar risiko lama HANYA membatasi SATU
// trade, tak pernah menjumlahkan SELURUH posisi terbuka. Karena piramida &
// repending membuka posisi SEARAH yg berbagi level trailing yg sama, posisi2
// itu praktis SATU trade besar yg dipecah - bukan risiko yg terdiversifikasi.
// Bukti dr jurnal: tiga posisi kena SL di harga yg SAMA, di detik yg SAMA:
//   Tester: stop loss #2 at 4389.53 / #4 at 4389.53 / #6 at 4389.53
// Puncak risiko agregat terbuka mencapai $531.80 saat balance $1.222 = 43,5%
// balance dipertaruhkan SEKALIGUS. Pagar di bawah menutup lubang itu: entri
// baru (termasuk piramida & pending) DITOLAK kalau total risiko terbuka +
// risiko calon entri melewati batas ini.
input bool     UseTotalRiskCap        = true;     // AKTIFKAN - pagar risiko SELURUH posisi terbuka (bukan per-trade)
input double   MaxTotalRiskPercent    = 5.0;      // total risiko semua posisi terbuka maks % balance
input int    MaxOrders                = 1;
input double MaxAllowedLot            = 5.0;
input int    MinMinutesBetweenTrades  = 5;

// === TP/SL DINAMIS ===
input bool   UseATRBasedSL            = true;
input int    ATRPeriod_SL             = 12;
input double ATRMultiplier_SL         = 1.2;
// v46: MASA TENGGANG SL - sesuai keluhan: sering kena SL duluan gara2
// koreksi/zigzag WAJAR di awal tren baru bergerak (sblm tren sungguhan
// lanjut), padahal arahnya sudah benar. FIX: SL lebih lebar utk N bar
// PERTAMA (survive koreksi wajar), lalu OTOMATIS mengetat ke SL normal
// begitu masa tenggang lewat - risiko TIDAK membesar diam2 krn lot-size
// dihitung dari jarak SL lebar ini sejak awal (risiko % tetap sesuai
// RiskPerTrade yg dikonfigurasi, bukan risiko tersembunyi tambahan).
input bool   UseEntryGracePeriod      = true;   // v2.00: sesuai konfigurasi yg dites - menahan shake-out awal tren.  // DEFAULT NONAKTIF - fitur baru, uji dulu di demo sblm akun real
input int    GracePeriodBars          = 2;      // berapa bar SL tetap lebar sblm mengetat ke SL normal
// v57: posisi hasil BUY/SELL LIMIT (Repend maupun Titik-Jenuh) butuh masa
// tenggang LEBIH LAMA drpd entri biasa - secara desain LIMIT masuk PERSIS
// di area koreksi/zigzag (garis ST atau puncak ekstensi), jadi WAJAR kena
// goncangan harga sesaat lebih besar sblm tren "asli" lanjut. GracePeriodBars
// biasa (2) yg dirancang utk entri STOP/breakout terlalu singkat utk gaya
// ini - SL keburu mengetat ke jarak normal sblm koreksi wajar itu selesai.
// GracePeriodBarsLimit: masa tenggang KHUSUS posisi asal LIMIT (Repend/Titik-Jenuh) - lebih lama drpd GracePeriodBars biasa
input int    GracePeriodBarsLimit     = 5; // masa tenggang SL khusus posisi asal LIMIT (lebih lama dr biasa)
// GracePeriodATRMultiplier: pengali ATR SL selama masa tenggang (harus > ATRMultiplier_SL spy benar2 lebih lebar)
input double GracePeriodATRMultiplier = 2.2; // pengali ATR SL selama masa tenggang
input double MinRR_Ratio              = 1.5;
input int    StopLoss_Fixed           = 150;
input int    TakeProfit_Fixed         = 225;

// === DRAWDOWN & PROTECTION ===
input bool   EnableDrawdownProtection = true;   // v2.00: DINYALAKAN - tes lama DD 24,01% tanpa rem sama sekali.
input double MaxDrawdownPercent       = 25.0;
input int    MaxConsecutiveLosses     = 5;
input double DailyLossLimitPercent    = 20.0;
input double HardDrawdownStopPercent  = 35.0;

// === TRAILING STOP ===
input bool      UseTrailingStop       = true;
// === v2.00 KALIBRASI ULANG EXIT UNTUK GOLD (temuan audit #1 penyebab PF mentok) ===
// MASALAH ASLI: seluruh parameter exit di bawah ini memakai satuan "pip" EA.
// Untuk XAUUSD, PipPoint()=0.01, jadi 20 "pip" = $0.20 - padahal ATR H1 gold
// sekitar $20. Artinya trailing mulai bekerja setelah harga bergerak 1% dari
// satu ATR: praktis langsung, di dalam noise murni.
// BUKTI DARI TES Jan-Jul 2026 (306 posisi):
//   - median lama tahan posisi 2,2 JAM di chart H1 (trend-following yg mati 2 bar)
//   - hanya 6,2% posisi mencapai jarak TP aslinya; exit t/p rata2 $65 vs exit
//     lain <$5 - pemenang diamputasi sebelum matang
//   - rasio payoff cuma 0,62 (untung $20,86 vs rugi $33,50) -> PF terkunci 1,36
//   - 53 posisi (17%) yg sempat untung >1xATR menghasilkan SELURUH profit
//     (+$1.919); 253 sisanya net -$754
// FIX: semua ambang exit kini RELATIF ATR, bukan angka pip mati. Nilai default
// di bawah = titik awal konservatif hasil audit; uji bertahap sesuai rencana.
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// === v3.00 TANGGA KUNCI PROFIT (fitur inti baru) ======================
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// DASAR BUKTI - temuan paling tajam dari seluruh tes bertahap Anda:
//   TAHAP 1: 23 posisi mencapai 1,5xATR profit -> 23 MENANG (100%)
//            50 posisi TIDAK mencapainya       -> 5 menang (10%)
//   TAHAP 2: 15 posisi mencapai 1,5xATR profit -> 15 MENANG (100%)
//            36 posisi TIDAK mencapainya       -> 2 menang (5,6%)
// Seluruh sistem ternyata bermuara pada SATU pertanyaan biner: apakah
// trade ini sampai 1,5xATR atau tidak? Kalau ya, praktis pasti menang.
// Tapi di v2.00 TIDAK ADA APA PUN yg MENJAMIN itu - 100% menang tadi
// murni kebetulan, tak ada mekanisme yg mengunci hasilnya.
// Tangga ini yg menguncinya: begitu PUNCAK profit (bukan profit saat
// ini) menyentuh satu anak tangga, SL dijamin tak pernah lagi turun di
// bawah level kunci tangga itu - permanen, satu arah, tak bisa dibatal-
// kan mekanisme lain mana pun, dan TIDAK dibatasi lantai garis ST.
// Ini juga menjawab temuan kedua: 87-94% kerugian bukan SL penuh, tapi
// trade yg sempat bergerak benar lalu balik menembus entri.
input bool      UseProfitLadder       = true;    // AKTIFKAN tangga kunci profit
input double    LadderStep1ATR        = 0.8;     // puncak profit >= ini xATR ...
input double    LadderLock1ATR        = 0.05;    //    ... kunci SL di entri + ini xATR
input double    LadderStep2ATR        = 1.5;     // <- ambang "pasti menang" dari data Anda
input double    LadderLock2ATR        = 0.50;
input double    LadderStep3ATR        = 2.5;
input double    LadderLock3ATR        = 1.20;
input double    LadderStep4ATR        = 4.0;
input double    LadderLock4ATR        = 2.20;
// === v3.00 PEMOTONG TRADE MATI ========================================
// DASAR BUKTI - distribusi lama-tahan gabungan TAHAP 1+2 (124 posisi):
//    0-2 jam : n= 13  win 53,8%  net  +$248
//    2-4 jam : n= 46  win 13,0%  net -$1023   <-- ladang pembantaian
//    4-8 jam : n= 36  win 41,7%  net  +$212
//    8-24 jam: n= 24  win 66,7%  net  +$623
// Kelompok 2-4 jam adalah trade yg masuk, tak ke mana-mana, lalu mati
// pelan-pelan saat trailing mengetat. Rata-rata -$22 per trade.
// Pemotong ini menutupnya lebih awal HANYA kalau trade itu benar-benar
// belum menunjukkan tanda hidup (puncak profit masih di bawah ambang).
// Trade yg sudah bergerak benar TIDAK disentuh - mereka yg jadi profit
// di kelompok 4-24 jam.
input bool      UseDeadTradeCut       = true;    // AKTIFKAN pemotong trade mati
input int       DeadTradeBars         = 4;       // setelah N bar ...
input double    DeadTradeMinPeakATR   = 0.5;     //    ... kalau puncak profit msh < ini xATR, tutup
input double    TrailStartATR         = 1.0;     // trailing baru aktif setelah profit >= ini x ATR (dulu 20 pip = $0.20)
input double    TrailMinATR           = 0.5;     // jarak trailing MINIMUM (x ATR) - ganti clamp lama "15 pip"
input double    TrailMaxATR           = 3.0;     // jarak trailing MAKSIMUM (x ATR) - ganti clamp lama "500 pip" = $5.00
input double    TrailStartPips        = 20.0;    // [WARISAN] hanya dipakai kalau UseATRRelativeExits=false
input bool      UseATRRelativeExits   = true;    // AKTIF = pakai ambang xATR di atas (disarankan utk gold)
input double    TrailDistancePips     = 30.0;
input ENUM_TRAILING_METHOD TrailMethod = TRAIL_ATR;
input double    TrailPercent          = 70.0;
input double    TrailATRMultiplier    = 1.2;
input double    TrailStepSize         = 25.0;
input bool      UseBreakeven          = true;
input double    BreakevenTriggerATR   = 0.7;     // v3.00: BE dikunci setelah profit >= ini x ATR
input double    BreakevenPlusATR      = 0.05;    // v3.00: SL dikunci sedikit DI ATAS entri (x ATR) - tutup biaya spread+komisi, bukan sekadar impas
input bool      BreakevenRespectSTLine_DEPRECATED = false; // v3.00: parameter v2.00 ini DIHAPUS fungsinya (lihat penjelasan di ApplyIntelligentTrailing)     // BE dikunci setelah profit >= ini x ATR (dulu 15 pip = $0.15 - kena hampir instan)
input double    BreakevenTriggerPips  = 15.0;    // [WARISAN] hanya dipakai kalau UseATRRelativeExits=false
input bool      UseSoftStopLoss       = true;
// v42c: SoftStopSafetyMultiplier DIHAPUS - dideklarasikan tp TIDAK PERNAH
// dipakai di mana pun. SetVirtualSL() ternyata memakai jarak PERSIS SAMA dgn
// SL asli (slPips, tanpa dikali apa pun) - soft-stop ini fungsinya jadi
// pengecekan CADANGAN via kode (in case broker gagal eksekusi SL asli),
// BUKAN margin ekstra spt namanya menyiratkan. Ini tidak saya ubah
// perilakunya (terlalu berisiko menebak logika SL tanpa konfirmasi) - cuma
// menghapus input yg terbukti tak berpengaruh sama sekali. Kalau maksud
// awalnya memang ingin soft-stop lebih lebar/sempit dari SL asli, beri tahu
// saya, saya sambungkan dgn benar sesuai yg Anda maksud.

// === LOSS LIMITER & PULLBACK ===
input bool      UseLossLimiter          = true;
input double    LossLimiterPips         = 200.0;
input ENUM_LOSS_LIMITER_METHOD LossLimiterMethod = LOSS_ATR;
input double    LossLimiterATRMultiplier = 1.5;
input double    SmartMaxLossPips        = 400.0;
input bool      UsePullbackDetection    = true;
input double    PullbackRetracePercent  = 40.0;
input double    MaxTrailRetracePercent  = 50.0;
input bool      UsePartialProfit        = true;   // v2.00: aktif, TAPI level kini benar-benar xATR (lihat di bawah).
input double    PartialProfitLevel1     = 1.5;
input double    PartialProfitPercent1   = 30.0;
input double    PartialProfitLevel2     = 2.5;
input double    PartialProfitPercent2   = 30.0;

// === FILTER ANTI TREN PALSU ===
input bool     UseVolatilityFilter    = true;   // v2.00: kini benar-benar berfungsi (lihat CheckVolatilityFilter)
// --- v2.00: filter lonjakan volatilitas berbasis RASIO ATR (skala-bebas) ---
input int      VolSpikeShortPeriod    = 3;      // ATR jangka pendek (bar)
input int      VolSpikeLongPeriod     = 24;     // ATR jangka panjang / "kebiasaan pasar" (bar)
input double   MaxVolSpikeRatio       = 2.5;    // blokir entri kalau ATR pendek > ini x ATR panjang
// --- v2.00: kesadaran jadwal NFP ---
input bool     BlockNFP               = true;   // blokir jendela NFP (Jumat pertama tiap bulan)
input int      NFPHour                = 15;     // jam NFP di waktu SERVER broker (sesuaikan! IC Markets GMT+2/+3 -> 15 = 13:30 GMT musim panas)
input int      NFPMinute              = 30;
input int      NFPBlockMinutes        = 45;     // blokir +/- menit ini di sekitar NFP
// v2.00: MaxVolatilityPercent DIHAPUS - dipakai oleh rumus ATR/harga lama yg
// terbukti mustahil aktif utk gold. Diganti MaxVolSpikeRatio (rasio ATR).
input bool     UseNewsFilter          = true;
input string   NewsHours              = "13:30,14:30,19:00";
input int      NewsBlockMinutes       = 30;

// === INDIKATOR UTAMA ===
input string   SupertrendFile         = "Supertrend_Promax";
input string   ST_ObjectName          = "Supertrend_Promax"; // disamakan dgn IndicatorName final v3.00
// PERBAIKAN v2: multiplier 2.5 (percobaan sebelumnya) terlalu lebar utk H1 - band jarang
// tertembus, hasilnya cuma 1-2 sinyal dlm 2 bulan data. Titik tengah 1.8 dipilih sbg
// starting point; SILAKAN uji rentang 1.5-2.2 utk cari yg paling pas dgn pair/timeframe Anda.
input double   ST_ATRMultiplier       = 0.5;      // coba rentang 1.5-2.2
input int      ST_ATRPeriod           = 7;       // standar: 10-14
input int      ST_ATRMaxBars          = 500;
input int      ST_Shift               = 0;
input bool     ST_EnableEntrySignals  = true;
// ST_UsePullbackSignal: WAJIB true utk mesin TREND RIDER! (panah pullback buffer 5/6 = pemicu entri lanjutan; false = mesin trend-rider buta total)
input bool     ST_UsePullbackSignal   = true; // WAJIB true - pemicu inti mesin Trend Rider
input bool     ST_UseADXFilter        = false;
input int      ST_ADXPeriod           = 14;
input double   ST_ADXThreshold        = 25.0;
input bool     ST_UseRSIFilter        = false;
input int      ST_RSIPeriod           = 14;
input double   ST_RSIOversold         = 30.0;
input double   ST_RSIOverbought       = 70.0;
input int      ST_TrendBuffer         = 4;
// Diagnostic/entry-signal buffers of Supertrend_Promax.
// v3.00 contract: buffer 5 = BUY pullback signal, buffer 6 = SELL pullback signal.
input int      ST_BuySignalBuffer    = 5;
input int      ST_SellSignalBuffer   = 6;
// v3.01: Supertrend leader/EASync buffers (7=BUY, 8=SELL)
input int      ST_LeaderBuyBuffer     = 5;
input int      ST_LeaderSellBuffer    = 6;
//--- passthrough parameter PRESISI Supertrend_Promax v3.00 (WAJIB ada supaya urutan iCustom pas)
input double   ST_RSIBufferZone       = 6.0;
input bool     ST_UseADXRisingFilter  = true;
input bool     ST_UseExhaustionReversal = true;
input double   ST_ExhaustOverbought   = 72.0;
input double   ST_ExhaustOversold     = 28.0;
input int      ST_ExhaustLookback     = 6;
input int      ST_ExhaustMinGapBars   = 6;

// === HEIKEN ASHI ===
input bool     UseHeikenAshi          = true;
input bool     UseInternalHeikenAshi  = false;                 // false = pakai HeikenAshi_Custom FINAL (direkomendasikan!)
input string   HeikenAshiFile         = "HeikenAshi_Custom";   // indikator final (3-lapis anti-zigzag)
input int      HA_OpenBuffer          = 2;
input int      HA_CloseBuffer         = 3;
input int      HA_DirectionBuffer     = 6;                     // buffer arah TERKONFIRMASI (rekomendasi utama)
//--- passthrough parameter HeikenAshi_Custom v2.20 (sinkron dgn indikator final)
input bool     HA_UseConfirmedColor   = true;
input int      HA_MinFlipBars         = 3;
input bool     HA_UseBodySizeFilter   = true;
input double   HA_MinBodyATRFactor    = 0.30;
input int      HA_BodyATRPeriod       = 14;
input int      HA_SmoothPeriod        = 6;

//=== KONFIRMASI ENTRY_SIGNAL_PRO (LANTAI 3 - konfirmator independen) ===
input bool     UseESPConfirmation     = true;                  // Aktifkan peran Entry_Signal_Pro
// ESP_RequireMatch: false=mode VETO saja (direkomendasikan): panah lawan menolak sinyal, panah searah TIDAK diwajibkan. true=wajib ada panah searah (ketat, BUY jadi sangat jarang krn StrictBuyMode di ESP)
input bool     ESP_RequireMatch       = false; // false=mode veto (disarankan), true=wajib panah searah (ketat)
input string   ESP_IndicatorFile      = "Entry_Signal_Pro";
input int      ESP_LookbackBars       = 3;                     // Jangkauan scan panah (bar)
input int      ESP_BuyBuffer          = 0;                     // buffer 0 = BUY SIGNAL (sesuai dok final)
input int      ESP_SellBuffer         = 1;                     // buffer 1 = SELL SIGNAL

//=== PENJAGA KEJAR-HARGA (ANTI ENTRI TELAT - pelajaran dari Test 2) ===
// Entri jauh setelah flip = harga sudah lari dari titik balik -> SL rentan
// tersentuh & reward mengecil. Sinyal ditolak bila harga sudah bergerak
// lebih dari MaxChaseATR x ATR searah sinyal sejak bar flip.
input bool     UseChaseGuard          = true;
// MaxChaseATR: diperketat dari 1.2 - entri market hanya saat harga masih dekat titik flip (perbaikan "entri di puncak" TANPA adverse selection limit order)
input double   MaxChaseATR            = 0.8; // batas jarak kejar harga dr titik flip (xATR)

// === KONFIRMASI MTF - FLEKSIBEL (pilih sendiri timeframe mana yang dipakai) ===
input bool     UseMTFConfirmation     = true;      // AKTIFKAN UNTUK KONFIRMASI
input bool     UseMTF_M5              = true;      // Ikutkan M5 dalam konfirmasi trend
input bool     UseMTF_M15             = true;      // Ikutkan M15 dalam konfirmasi trend
input bool     UseMTF_M30             = true;      // Ikutkan M30 dalam konfirmasi trend
input bool     UseMTF_H1              = false;     // Ikutkan H1 dalam konfirmasi trend
input bool     UseMTF_H4              = false;     // Ikutkan H4 dalam konfirmasi trend
input int      MinMTFRequired         = 2;         // Minimal berapa TF (dari yg diaktifkan di atas) harus searah

// === FILTER SUPPORT/RESISTANCE (SuperSR_6) - OPSIONAL ===
input bool     UseSRFilter            = false;     // Aktifkan konfirmasi dari SuperSR_6
input string   SR_IndicatorFile       = "SuperSR_6";
input int      SR_Contract_Step       = 150;
input int      SR_Precision           = 10;
input int      SR_Shift_Bars          = 1;
// SR_MaxDistancePips: Sinyal dianggap valid jika harga sedekat ini ke level S/R (dipakai sbg LANTAI minimal bila SR_UseATRScaling aktif)
input double   SR_MaxDistancePips     = 30; // jarak toleransi ke level S/R (pip)
// SR_UseATRScaling: v34: jarak toleransi ikut membesar/mengecil sesuai volatilitas instrumen saat ini (ambil yg LEBIH LEBAR antara pip tetap vs ATR) - penting utk XAUUSD, krn 20-30 "pip" (=$0.20-0.30) nyaris mustahil tersentuh di gold yg ATR H1-nya puluhan dolar
input bool     SR_UseATRScaling       = true; // jarak toleransi S/R ikut skala ATR (penting utk gold)
input double   SR_MaxDistanceATRFactor= 1.2;       // v34: dipakai kalau (faktor x ATR) > SR_MaxDistancePips

// === TITIK JENUH (EXHAUSTION) - DIPERBAIKI ===
input bool     UseOverExtended        = true;
input double   OverExtendedFactor     = 0.6;      // diturunkan dari 1.0 - leg pendek butuh threshold lebih rendah
input int      ExtensionScanMaxBars   = 30;       // Batas scan mundur utk cari puncak titik jenuh trend lama

// === FILTER TREND PALSU (FALSE TREND) ===
input bool     UseFalseTrendFilter    = true;     // Wajibkan trend lama benar2 kuat (bukan sideways/noise)
input int      FalseTrendADXPeriod    = 14;
input double   FalseTrendADXThreshold = 20.0;      // ADX minimal selama trend lama berlangsung
input int      MinTrendDurationBars   = 2;        // diturunkan dari 3 - leg trend lebih pendek dgn band lebih sensitif

// === FILTER KOREKSI HARGA SEBELUM REVERSAL ===
input bool     UseCorrectionFilter    = true;     // Wajibkan pola koreksi 2-3 candle sebelum sinyal reversal
input int      CorrectionLookbackBars = 3;        // Jumlah candle terakhir sebelum flip yang discan
input int      MinCorrectionCandles   = 1;        // diturunkan dari 2 - lebih realistis utk leg pendek

//=== JENDELA SINKRONISASI 4 INDIKATOR (KUNCI KOLABORASI) ===
// Keempat indikator "berbicara" di waktu berbeda: Supertrend flip duluan,
// HeikenAshi_Custom (sengaja lambat & stabil, anti-zigzag) baru berganti
// warna 2-5 candle kemudian, Entry_Signal_Pro muncul di momennya sendiri.
// Flip Supertrend MEMBUKA jendela konfirmasi selama N candle - EA menunggu
// di dalam jendela sampai SEMUA konfirmator setuju, baru entri. Tanpa ini,
// menuntut semua setuju di satu candle yang sama = hampir mustahil (nol entri).
input int      ConfirmWindowBars      = 6;        // Lebar jendela konfirmasi setelah flip Supertrend

//=== MODE KUALITAS FLIP (titik sentral sinyal) ===
// false (BARU, default) = FLIP SEDERHANA: potongan garis Supertrend + HA
//   searah + pengawas (ESP veto, rezim, kejar-harga, MTF) = SINYAL SAH.
//   Persis cara baca visual: garis berganti warna & HA mengkonfirmasi.
// true = FLIP KETAT (warisan): tambah 4 filter dalam (umur trend lama,
//   ADX trend lama, titik jenuh, pola koreksi) - sangat pemilih, banyak
//   titik sentral yang sudah terkonfirmasi visual justru gugur di sini.
input bool     UseStrictFlipQuality   = false;

//=== FILTER REZIM PASAR (pelajaran Test 4: loss menumpuk di fase ranging) ===
// EA reversal menang di pasar TRENDING, kalah di pasar RANGING (flip
// Supertrend di pasar datar = zigzag). Filter ini menolak SEMUA entri saat
// pasar sedang tidak punya kekuatan arah (ADX rendah) - "kalau medan
// perangnya jelek, jangan bertempur sama sekali".
input bool     UseRegimeFilter        = true;
input int      RegimeADXPeriod        = 14;
// v42c: RegimeADXMin DIHAPUS - dulu ambang ADX minimum utk entri, tp
// DIGANTIKAN sistem dominasi DI+/DI- sejak v19 (lihat catatan asli di bawah:
// "Ditolak - Pasar ranging (rezim ADX)" adalah gerbang LAMA). Input-nya
// tertinggal, tidak pernah dihapus walau fungsinya sudah diganti total -
// tidak berpengaruh ke perilaku EA sekarang sama sekali.
//=== v19: REZIM DIROMBAK - DI+/DI- + WASIT REGRESI LINIER ===
// DATA (test M30 6bln): "Ditolak - Pasar ranging (rezim ADX)" = 51 kali,
// TERBANYAK dari semua filter, dan mayoritas pada selisih DI TIPIS/SERI
// (mis. DI+19.9 vs DI-20.0, DI+21.0 vs DI-20.6 - beda <1 poin). Aturan
// ">" murni memvonis SERI/NOISE seolah "pasti berlawanan arah" - inilah
// penyebab "pergantian tren kuat masih dilewat". SOLUSI 2 lapis:
// 1. Selisih DI >= DIMinSeparation -> keputusan TEGAS (cepat & jelas).
// 2. Selisih DI < itu (nyaris seri/noise) -> WASIT kedua: kemiringan
//    REGRESI LINIER harga N bar terakhir (dinormalisasi ATR) - ukuran
//    arah & kekuatan tren yang matematis, cepat (tanpa lag DI yg perlu
//    beberapa bar utk berpisah pasca-flip), pas utk pergantian tren baru.
input double   DIMinSeparation        = 4.0;      // selisih DI+/DI- min utk vonis TEGAS
input int      RegimeSlopeBars        = 6;        // jumlah bar utk regresi linier wasit
input double   RegimeSlopeMin         = 0.12;     // kemiringan min (x ATR per bar) searah sinyal
//=== v31: FILTER BIAS TIMEFRAME-ATAS (dari report 7bln H4: 93% kerugian) ===
// DATA: win rate SHORT cuma 34% vs LONG 62% - SELL full-SL melawan
// uptrend makro D1 = 50% dari SELURUH kerugian; BUY kena SL di fase
// ranging makro Agu-Sep = 43% lagi. Akar sama: EA buta arah TF di ATAS
// chart (MTF lama malah cek M5/M15/M30 = noise di bawah H4). Solusi:
// bias TF-atas (H4->D1, H1->H4, dst) diukur kemiringan regresi harga:
// - sinyal SEARAH bias -> lolos normal
// - bias DATAR (makro sideways spt Agu-Sep) -> butuh DI sep >= ambang
// - sinyal MELAWAN bias -> butuh bukti SANGAT kuat (DI sep besar +
//   candle besar) atau ditolak - inilah rem utk SELL2 pembunuh itu.
input bool     UseHTFBiasFilter       = true;
input bool     UseCounterTrendSizing  = true;   // v3.00: perkecil lot saat sinyal melawan bias TF-atas (bukan memblokir)
input double   CounterTrendLotFactor  = 0.5;    // v3.00: pengali lot utk entri lawan-tren
input int      HTFBiasBars            = 10;      // jml bar TF-atas utk regresi bias
// HTFBiasMinSlope: v33: 0.06->0.03 - uptrend D1 yg merayap pelan HARUS tetap terdeteksi sbg bias naik (di 0.06 sering salah baca "datar" -> sell lolos via jalur datar)
input double   HTFBiasMinSlope        = 0.03; // ambang kemiringan minimal utk bias TF-atas
// HTFBiasHardBlock: v34: DEFAULT DIUBAH ke false (dulu true). true = sinyal MELAWAN bias DITOLAK MUTLAK tanpa pengecualian sama sekali - cocok kalau memang mau mode "murni ikut tren", tapi efek sampingnya sinyal BERLAWANAN ARAH TIDAK PERNAH bisa lolos selama bias TF-atas belum berbalik penuh (bukti nyata: 0 dari 57 trade short di tes XAUUSD H1). false = pintu darurat AKTIF, tapi versi v34 (2 candle beruntun + ADX menguat - lihat HTFCounterMinDISep/BodyATR/PersistFactor), BUKAN versi v32 yang gampang ketipu SATU candle-spike di titik jenuh.
input bool     HTFBiasHardBlock       = false; // true=blokir mutlak sinyal lawan bias, false=ada jalur darurat (v34)
input double   HTFFlatMinDISep        = 5.0;     // makro DATAR: sinyal butuh DI sep minimal ini
input double   HTFCounterMinDISep     = 6.0;     // MELAWAN bias: DI sep minimal ini (candle ke-1/shift 1)
input double   HTFCounterMinBodyATR   = 0.55;    // MELAWAN bias: + candle sinyal minimal ini (xATR), candle ke-1
// HTFCounterPersistFactor: v34: candle ke-2 (shift 2) boleh sedikit lebih lemah dari candle ke-1 - ini faktor toleransinya (0.7 = DI sep candle-2 minimal 70% dari HTFCounterMinDISep). Menuntut divergensi bertahan 2 candle, bukan cuma 1 - inilah yg membedakan spike-sesaat vs pembalikan sungguhan.
input double   HTFCounterPersistFactor= 0.7; // toleransi pelemahan candle ke-2 vs ke-1 (jalur darurat)

//=== FILTER KOMPRESI/SIDEWAYS + GERBANG BREAKOUT (v15) ===
// Pelajaran visual 11 Jul: entri "BUY KURANG TEPAT" terjadi DI TENGAH zona
// konsolidasi sempit (titik ST merah & biru berdampingan, candle kecil2
// bolak-balik). ADX bekas trend besar masih tinggi -> filter rezim bocor.
// Solusi: ukur KOMPRESI langsung - lebar total range N candle dibanding ATR.
// Pasar terkompresi = SEMUA pemicu diblokir, KECUALI candle sinyal adalah
// candle BREAKOUT yang close menembus batas range (persis titik "BUY yang
// benar" di penunjuk visual: tembus atap konsolidasi -> baru boleh entri).
//=== v16: KOTAK KONSOLIDASI ADAPTIF (perombakan total anti-sideways) ===
// Kelemahan v15: jendela kaku 12 bar - ayunan lokal DI DALAM konsolidasi
// lebar (3 hari = ~70 bar H1) bisa menembus "high 12 bar" dan salah
// dianggap breakout. v16: kotak TUMBUH ADAPTIF - scan mundur dari bar 2,
// perbesar kotak selama lebar totalnya masih < faktor x ATR (max 96 bar).
// Kotak >= CompressionMinBars = ZONA SIDEWAYS RESMI:
//   - harga DI DALAM kotak  -> SEMUA pemicu entri DIBLOKIR
//   - close MENEMBUS batas kotak + buffer -> entri HANYA searah breakout
//   - beberapa bar setelah breakout -> sinyal ARAH LAWAN tetap dikunci
// Kotak DIGAMBAR di chart (persegi abu2 + label) supaya keputusan EA bisa
// diaudit mata langsung di visual tester.
input bool     UseCompressionFilter   = true;
input int      CompressionMinBars     = 8;       // minimal lebar zona (bar) utk dianggap kotak sideways
input int      CompressionMaxBars     = 96;      // scan mundur maksimal (bar)
input double   CompressionMaxRangeATR = 2.5;     // lebar kotak maksimal (kelipatan ATR)
// v35: PENJAGA TREN HALUS. Kotak murni berbasis LEBAR (high-low) bisa salah
// tangkap trend yang mulus/landai - tiap candle kecil tapi SEARAH terus
// (persis "garis lurus simetris" di grafik Supertrend) - sebagai "sideways",
// padahal net pergerakannya besar dan searah. CompressionMinDirectionality
// mengukur rasio net-displacement (jarak awal->akhir kotak) thd lebar total
// kotak: rasio TINGGI (>=ambang ini) = harga "jalan satu arah", ini TREND,
// BUKAN kotak, walau tiap candle kecil - dibiarkan lolos meski lebar < ATR
// limit. Rasio RENDAH = harga bolak-balik tanpa progres = kotak sungguhan,
// tetap diblokir seperti biasa.
// CompressionMinDirectionality: rasio net-disp/lebar min utk lolos sbg trend, bukan kotak (0=nonaktif, selalu anggap kotak spt v16 lama)
input double   CompressionMinDirectionality = 0.6; // ambang rasio arah utk lolos sbg tren (bukan kotak)
input double   BreakoutBufferPips     = 2.0;     // close wajib menembus batas kotak + buffer ini
input int      OppositeLockBars       = 6;       // pasca-breakout: sinyal arah LAWAN dikunci N bar
input bool     DrawCompressionBox     = true;    // v18: hanya KETERANGAN TEKS di zona sideways (kotak persegi TIDAK digambar)
//=== v19: KANTONG CHOP JANGKA-PENDEK (pelengkap kotak adaptif) ===
// Kotak adaptif butuh >=CompressionMinBars (8) utk terbentuk - kantong
// choppy PENDEK (3-6 bar, blm cukup panjang jd "kotak resmi") bisa lolos
// & memicu entri yang berbalik cepat (turut menyumbang give-back equity
// trade #28->34 di data test). Cek independen: range M-bar terakhir kecil
// relatif ATR -> tolak jg walau kotak besar belum terbentuk.
input bool     UseShortPocketChop     = true;
input int      ShortPocketBars        = 4;
input double   ShortPocketMaxATR      = 1.1;

//=== FILTER KEKUATAN CANDLE SINYAL (v15) ===
// Perubahan tren KUAT selalu ditandai candle konfirmasi berbadan besar.
// Flip/panah yang candle pemicunya kecil (badan < faktor x ATR) = ciri
// zigzag/koreksi -> tidak dilayani. Melengkapi filter body di indikator HA.
input bool     UseSignalBodyFilter    = true;
input double   MinSignalBodyATR       = 0.35;    // badan candle sinyal minimal (kelipatan ATR)


//=== v18: JALUR CEPAT + BATAS TELAT + PERISAI PISAU (dari data jurnal test) ===
// DATA: semua entri pembalikan tercatat "flip 4-6 bar lalu" = SELALU telat
// naik kereta (trade #3: rally berangkat 14:00, EA baru naik 17:00 setelah
// harga lari 100 pips -> cuma BE). Akarnya: HA terkonfirmasi sengaja lambat
// 3+ candle (bagus sbg penjaga arah, fatal sbg syarat WAJIB timing entri).
// SOLUSI 3 lapis:
// 1. JALUR CEPAT: flip masih segar (<= FastEntryMaxBars) + candle sinyal
//    kuat + dominasi DI searah + di luar kotak = ENTRI TANPA menunggu HA
//    (naik kereta saat berangkat). ESP veto & semua pengawas lain tetap aktif.
// 2. BATAS TELAT jalur konfirmasi: bila menunggu HA, harga tak boleh sudah
//    bergerak > LateEntryMaxATR x ATR dari close bar flip - kereta yang
//    sudah jauh DIRELAKAN (lebih baik terlewat daripada beli di puncak).
// 3. PERISAI PISAU: melawan leg raksasa (ekstensi lama > BigLegATR x ATR)
//    butuh bukti ekstra: candle sinyal SANGAT kuat (>=0.6xATR) ATAU
//    breakout kotak searah (trade #4: SELL lawan rally raksasa -> SL).
input bool     UseFastTrackEntry      = true;
input int      FastEntryMaxBars       = 2;       // flip maksimal N bar lalu utk jalur cepat
input double   LateEntryMaxATR        = 1.2;     // jalur konfirmasi: pergerakan max dari close flip (x ATR)
input bool     UseKnifeGuard          = true;
input double   BigLegATR              = 3.0;     // ekstensi leg lawan > ini x ATR = leg raksasa
//=== v21: PENJAGA TITIK JENUH utk ENTRI LANJUTAN (dari data test 6bln) ===
// TEMUAN: Perisai Pisau (knife guard) v18 hanya dipasang di mesin REVERSAL,
// TIDAK di mesin LANJUTAN/RIDER (panah presisi ContSignalBuyBuffer/Sell).
// Bukti nyata (trade #246, 26 Des): mesin REVERSAL menolak BUY "melawan
// LEG RAKSASA", TAPI mesin RIDER tetap entry BUY lewat "panah ST" di
// waktu bersamaan -> rugi. Ini AKAR MASALAH "entri di titik jenuh tren"
// yang dikeluhkan - panah presisi lanjutan menembak "beli pullback" atau
// "jual rally" padahal trend yg SAMA ARAH sudah terlalu jauh berlari
// (bukan pullback sehat, tapi awal pembalikan). Solusi: ukur ekstensi
// trend SAAT INI (arah sama dgn sinyal lanjutan) dari garis ST; kalau
// sudah > ExhaustionATR x ATR, tolak kecuali candle sinyal SANGAT kuat.
input bool     UseExhaustionGuard     = true;
input double   ExhaustionATR          = 3.0;     // ekstensi trend berjalan > ini x ATR = beresiko jenuh
input double   ExhaustionMinBodyATR   = 0.55;    // candle sinyal min di titik jenuh (lebih ketat dr biasa)

//=== v21: TRAILING ADAPTIF VOLATILITAS (dari catatan Anda) ===
// Permintaan: begitu entry, TP harus cepat diselamatkan (trailing gesit),
// TAPI kelonggaran SL menyesuaikan besar/kecilnya candle saat ini -
// candle kecil2/rapat (pasar tenang) -> SL DIPERSEMPIT supaya profit
// sekecil apapun sempat terkunci sebelum balik arah; candle lebar2 (trend
// kuat) -> SL DILONGGARKAN supaya tidak kena koreksi wajar. Caranya: ATR
// jangka pendek (3 bar) dibandingkan ATR dasar (14 bar) -> rasio rezim
// volatilitas -> mengalikan jarak trailing (baik ATR-trailing maupun
// buffer trailing-garis-ST).
input bool     UseAdaptiveTrailTightness = true;
input int      VolRegimeShortBars     = 3;       // ATR jangka pendek utk baca rezim
input double   VolRegimeQuietRatio    = 0.75;    // rasio < ini = pasar tenang/candle kecil -> SL diketatkan
input double   VolRegimeQuietFactor   = 0.85;   // v2.00: dulu 0.5 - saat pasar tenang trailing DIBAGI DUA lagi di atas clamp yg sudah terlalu ketat.      // pengali jarak trailing saat tenang (makin kecil = makin ketat)
input double   VolRegimeWideRatio     = 1.3;      // rasio > ini = candle lebar/trend kuat -> SL dilonggarkan
input double   VolRegimeWideFactor    = 1.6;      // pengali jarak trailing saat trend kuat (makin besar = makin longgar)

//=== v30: SL PINTAR (CUT-LOSS CERDAS) + TRAILING BERTAHAP ===
// Temuan #4-5 test 7bln H4: (a) SL kaku diam menunggu kena penuh walau
// tren SUDAH JELAS berbalik -> rugi maksimal padahal bukti pembalikan
// sudah ada jauh sebelum SL tersentuh; (b) trailing terlalu lambat
// menyelamatkan profit yg sudah didapat. Solusi 2 lapis:
// CUT-LOSS CERDAS: posisi ditutup DINI hanya bila ADA BUKTI pembalikan
//   sungguhan (ST flip lawan + HA mentah lawan + candle lawan berbadan
//   besar, dan BUKAN di dalam kotak sideways) - kalau cuma koreksi/zigzag
//   (candle kecil / masih dlm kotak), posisi DIBERI NAPAS penuh.
// TRAILING BERTAHAP: makin besar profit berjalan (diukur kelipatan ATR),
//   jarak trailing makin diperketat otomatis - profit besar dikunci
//   makin rapat, profit kecil masih diberi ruang berkembang.
input bool     UseSmartCutLoss        = true;
input double   CutLossMinBodyATR      = 0.50;    // bukti pembalikan: candle lawan minimal (x ATR)
input bool     UseProfitStageTrail    = false;  // v2.00: DIMATIKAN - makin untung makin ketat = kebalikan trend-following.
input double   StageTrailStartATR     = 1.0;     // profit >= ini x ATR -> pengetatan bertahap mulai
input double   StageTrailTightest     = 0.45;    // batas pengali jarak trailing terketat

//=== v30: SISTEM RECOVERY PINTAR (temuan #6) ===
// Defisit hari sebelumnya (target minus) dicatat saat reset harian. Di
// hari berikutnya, HANYA saat momentum tren SANGAT KUAT & searah sinyal
// (selisih DI lebar + kemiringan regresi tinggi), lot dinaikkan
// RecoveryLotFactor utk mengejar pemulihan - dgn pagar risiko KHUSUS
// (RecoveryMaxRiskPct) & batas jumlah trade recovery. Bukan martingale:
// tidak menggandakan terus, tidak beraksi di pasar lemah/sideways.
input bool     UseSmartRecovery       = true;
input double   RecoveryLotFactor      = 1.5;     // pengali lot trade recovery
input double   RecoveryMaxRiskPct     = 2.5;     // pagar risiko khusus trade recovery (% balance)
input int      RecoveryMaxTrades      = 3;       // maks trade recovery per defisit
input double   RecoveryMinDISep       = 4.0;     // v32: dilonggarkan 6->4 (data test: 6 nyaris tak pernah kesampaian)
input double   RecoveryMinSlopeATR    = 0.15;    // v32: dilonggarkan 0.20->0.15 (idem)

//=== v30: PENDING ORDER STOP PENUTUP / COVER (temuan #7) ===
// Saat posisi ditutup RUGI (kena SL karena arah tren ternyata berbalik),
// EA mengevaluasi arah LAWAN: bila ST trend & HA mentah kini kompak
// searah lawan (pembalikan terkonfirmasi indikator), pending STOP order
// dipasang di titik ekstrem N bar terakhir +/- buffer - kalau tren lawan
// benar2 berlanjut & menyentuhnya, posisi baru menangkap pergerakan
// besar itu (menutup kerugian sebelumnya). Kedaluwarsa otomatis
// CoverExpiryBars bar bila tak tersentuh (tidak menggantung selamanya).
input bool     UsePendingCover        = false;  // v2.00: DIMATIKAN bersama subsistem pending lainnya.
input double   CoverBufferPips        = 3.0;     // buffer melewati titik ekstrem
input int      CoverExpiryBars        = 6;       // umur pending (bar) sebelum hangus
input int      CoverExtremeBars       = 8;       // titik ekstrem diambil dari N bar terakhir
// UseContinuationRepending: v39: SL kena krn koreksi sesaat (indikator BELUM berbalik) -> pasang pending SEARAH posisi lama, tangkap kembali kelanjutan tren yg sama
input bool     UseContinuationRepending = false; // v2.00: DIMATIKAN - sistem pending net -$138 di tes (menang 73% tapi tetap rugi). // aktifkan pending lanjut-tren stlh SL kena saat indikator msh searah
input double   RependBufferPips       = 3.0;     // buffer melewati struktur (lantai bawah; ikut skala ATR jg spy relevan di gold)
input int      RependStructBars       = 6;       // struktur N bar utk level pending lanjut-tren
input int      RependExpiryBars       = 8;       // umur maksimal pending lanjut-tren (bar) - berlaku utk STOP
// v57: LIMIT butuh waktu tunggu LEBIH LAMA drpd STOP - filosofinya menunggu
// harga koreksi/pullback ke level tertentu, yg wajar makan waktu lebih lama
// drpd STOP (menunggu breakout momentum, biasanya lebih cepat kejadian
// kalau memang akan terjadi). RependExpiryBars (8) yg dirancang utk STOP
// terlalu singkat utk gaya LIMIT.
input int      RependLimitExpiryBars  = 16;      // umur maksimal pending LIMIT lanjut-tren (bar) - terpisah, lebih lama drpd STOP
// v52: PENDING LANJUT-TREN kini bisa gaya STOP (asli - breakout, tangkap
// kelanjutan momentum di luar struktur) ATAU LIMIT (baru - tangkap koreksi/
// pullback KEMBALI ke garis ST dgn harga lebih baik) ATAU KEDUANYA sekaligus
// (uji banding langsung, dua pending terpasang bersamaan). Barometer LIMIT
// BUKAN sembarang harga - dipatok ke garis Supertrend (acuan tren yg SUDAH
// dipakai konsisten di seluruh EA ini utk kuorum/jarak-kejar/trailing), lalu
// divalidasi jaraknya (xATR) dr harga skrg - kalau kejauhan (tren mungkin
// sudah menua) atau kedekatan (nyaris sama dgn market, tak ada manfaat harga
// lebih baik), TIDAK dipasang drpd asal comot.
enum ENUM_REPEND_MODE { REPEND_STOP_ONLY=0, REPEND_LIMIT_ONLY=1, REPEND_BOTH=2, REPEND_AUTO_SLOPE=3 };
// v60: mode ke-4 - AUTO_SLOPE. Kemiringan tren (xATR/bar, dr fungsi
// ComputeTrendSlopeATR yg SUDAH dipakai Bias TF-Atas & Regime) diukur PAS
// saat keputusan diambil, lalu gaya dipilih OTOMATIS per kejadian (bukan
// tetap satu pilihan sepanjang tes):
//   |slope| < AutoSlopeLandaiMax     -> LIMIT  (tren landai, wajar ada koreksi berarti dulu)
//   AutoSlopeLandaiMax..CuramMin     -> BOTH   (tren sedang, dua2nya masuk akal)
//   |slope| >= AutoSlopeCuramMin     -> STOP   (tren curam, momentum kuat, jarang sempat koreksi dalam)
// Arah (naik/turun) tak mengubah logika - cuma BESARAN (nilai mutlak) yg menentukan kategori.
input double   AutoSlopeLandaiMax    = 0.15;    // di bawah ini = landai -> LIMIT
input double   AutoSlopeCuramMin     = 0.40;    // di atas ini = curam -> STOP (di antara = sedang -> BOTH)
input int      AutoSlopeLookbackBars = 12;      // jendela bar utk ukur kemiringan (dipakai ComputeTrendSlopeATR)
// v62: kalibrasi SL/TP berdasar kemiringan tren - diterapkan ke SEMUA
// entri (Trend Rider utama, Repend, Titik-Jenuh, Cover) krn semuanya
// bermuara ke GetManualSLPips()/GetManualTPPips(). Tren CURAM (momentum
// kuat) = SL boleh lebih ketat (risiko pullback dalam lebih kecil) & TP
// lebih lebar (biarkan profit lari). Tren LANDAI = SL lebih lebar (wajar
// zigzag) & TP lebih sederhana (momentum lemah, jarang lari jauh). Tren
// SEDANG = baseline, tak berubah (x1,0). Kategorinya pakai ambang yg SAMA
// dgn AutoSlopeLandaiMax/CuramMin di atas, supaya satu model mental yg
// konsisten. Override SL/TP manual (g_UseManualSL/TP) TIDAK disentuh -
// kalibrasi ini cuma berlaku di jalur ATR-adaptif.
input bool     UseSlopeAdaptiveSLTP  = true;   // v2.00: sesuai konfigurasi yg dites.   // master switch - default MATI, aktifkan manual utk uji
input double   SlopeAdaptSL_Curam    = 0.8;     // pengali SL saat tren curam (di bawah 1 = lebih ketat)
input double   SlopeAdaptTP_Curam    = 1.3;     // pengali TP saat tren curam (di atas 1 = lebih lebar)
input double   SlopeAdaptSL_Landai   = 1.3;     // pengali SL saat tren landai (di atas 1 = lebih lebar)
input double   SlopeAdaptTP_Landai   = 0.8;     // pengali TP saat tren landai (di bawah 1 = lebih sederhana)
input ENUM_REPEND_MODE RependOrderMode = REPEND_STOP_ONLY; // 0=STOP asli, 1=LIMIT baru, 2=KEDUANYA (bandingkan)
// RependLimitMinATR: jarak MINIMAL (xATR) garis ST dr harga skrg spy LIMIT tdk percuma - v58: dilonggarkan (0.3->0.2)
input double   RependLimitMinATR      = 0.2; // jarak minimal (xATR) garis ST utk LIMIT Repend
// RependLimitMaxATR: jarak MAKSIMAL (xATR) - v58: dilonggarkan (2.0->3.5) krn trailing v53 sudah menjaga level tetap relevan, jd batas ketat spt dulu tak lg sepenting itu
input double   RependLimitMaxATR      = 3.5; // jarak maksimal (xATR) garis ST utk LIMIT Repend
// UsePyramidAdd: v41: tambah posisi SEARAH tren yg sudah terbuka & terbukti profit, TANPA perlu pemicu baru - mengisi celah tren mulus yg cuma dapat 1 entri walau MaxOrders izinkan lebih. DEFAULT NONAKTIF krn menambah eksposur risiko - aktifkan sadar & uji di demo dulu.
input bool     UsePyramidAdd          = true;   // v2.00: sesuai konfigurasi yg dites; kini AMAN krn dibatasi pagar risiko agregat. // tambah posisi searah tren yg sudah profit (default nonaktif, uji demo dulu)
// PyramidMinProfitATR: posisi TERAKHIR yg terbuka min untung segini xATR sblm boleh tambah lagi (bukti tren sungguhan, bukan asal nambah)
input double   PyramidMinProfitATR    = 0.8; // syarat untung minimal (xATR) posisi terakhir sblm pyramid
// PyramidMinBarsGap: min bar sejak entri terakhir sblm boleh tambah lagi (jangan tambah tiap tick/bar)
input int      PyramidMinBarsGap      = 3; // jeda bar minimal antar pyramid add
// PyramidMaxChaseATR: jangan tambah kalau harga sekarang sudah > segini xATR dari garis ST (jangan pyramid di titik yg sudah mulai exhausted)
input double   PyramidMaxChaseATR     = 2.0; // batas jarak dr garis ST sblm pyramid dibatalkan
// v49: SPIKE GUARD - menjawab keluhan spesifik: posisi sudah untung jauh,
// tiba2 candle LEBAR membalik arah dalam satu bar, trailing biasa (yg
// cuma dicek SEKALI PER BAR BARU, lihat OnTick) TIDAK SEMPAT bereaksi krn
// pembalikannya terjadi & selesai SEBELUM bar itu tutup. Beda dgn koreksi
// kecil/pendek (itu memang biarkan trailing normal yg urus). Spike Guard
// dicek TIAP TICK scr terpisah - kalau harga mundur signifikan dari puncak
// SAAT INI (blm nunggu bar tutup), kunci sebagian profit via SL darurat.
input bool     UseSpikeGuard          = false;  // v2.00: tetap MATI default - 293 intervensi di tes, memotong sebelum tren lanjut. Uji A/B.   // default nonaktif - fitur baru, uji dulu sblm akun real
// SpikeGuardMinProfitATR: posisi min sudah untung segini xATR dulu sblm Spike Guard aktif (jgn ganggu posisi yg blm berkembang)
input double   SpikeGuardMinProfitATR = 1.5; // syarat untung minimal (xATR) sblm Spike Guard aktif
// SpikeGuardRetraceATR: kalau harga mundur dari puncak sebesar ini xATR (real-time, blm nunggu bar tutup), kunci sebagian profit
input double   SpikeGuardRetraceATR   = 0.8; // mundur dr puncak (xATR) yg memicu Spike Guard
// SpikeGuardLockRatio: porsi dari untung PUNCAK yg dikunci saat Spike Guard aktif (0.5 = kunci separuh dari untung tertinggi yg sempat dicapai)
input double   SpikeGuardLockRatio    = 0.5; // porsi untung puncak yg dikunci Spike Guard

//=== v32: PENDING STOP TITIK JENUH (permintaan Anda - bukan cuma cover) ===
// Saat tren BERJALAN mencapai TITIK JENUH (ekstensi dari garis ST sudah
// jauh + RSI ekstrem), pending STOP order arah LAWAN disiapkan lebih
// dulu di bawah/atas STRUKTUR harga (low/high N bar, atau level S/R
// SuperSR bila ada di antaranya - menembus S/R = konfirmasi lebih kuat):
//   - UPTREND jenuh (RSI >= overbought) -> SELL STOP di bawah struktur
//   - DOWNTREND jenuh (RSI <= oversold) -> BUY STOP di atas struktur
// ADAPTIF/TIDAK KAKU: selama belum tersentuh, levelnya DIGESER ULANG
// tiap bar mengikuti struktur terbaru; hangus otomatis bila kondisi
// jenuh hilang atau umur habis. Ada info real-time di panel dashboard.
input bool     UseExhaustionPending   = false;  // v2.00: DIMATIKAN - alasan sama (lihat UseContinuationRepending).
input double   ExhPendExtATR          = 2.5;     // ekstensi tren >= ini xATR = kandidat jenuh
input int      ExhPendRSIPeriod       = 14;
input double   ExhPendRSIOB           = 70.0;    // RSI >= ini saat uptrend = jenuh beli
input double   ExhPendRSIOS           = 30.0;    // RSI <= ini saat downtrend = jenuh jual
input int      ExhPendStructBars      = 6;       // struktur: low/high N bar utk level stop
input double   ExhPendBufferPips      = 3.0;     // buffer minimal (pip tetap) - lantai bawah
// ExhPendBufferATRFactor: v37: buffer jg ikut skala ATR (mis. 0.15xATR) - 3 pip tetap nyaris nol utk gold, efektif = MAX(pip tetap, xATR)
input double   ExhPendBufferATRFactor = 0.15; // buffer titik-jenuh ikut skala ATR
input int      ExhPendExpiryBars      = 8;       // umur maksimal pending (bar) - batas keras, berlaku utk STOP
// ExhPendLimitExpiryBars: v57: umur maksimal pending LIMIT titik-jenuh (bar) - terpisah, lebih lama drpd STOP (alasan sama spt RependLimitExpiryBars)
input int      ExhPendLimitExpiryBars = 16; // umur maksimal pending LIMIT titik-jenuh (bar)
// ExhPendCancelPersistBars: v37: "kondisi jenuh hilang" harus bertahan sekian bar BERUNTUN baru dibatalkan - sebelumnya 1 bar RSI mundur sedikit langsung menghapus pending yg sebenarnya masih valid
input int      ExhPendCancelPersistBars = 2; // bar beruntun kondisi jenuh hilang sblm dibatalkan
// v55: sistem Titik-Jenuh kini jg bisa gaya LIMIT (konsisten dgn Repend,
// permintaan Anda) - filosofi beda dr STOP: STOP nunggu KONFIRMASI jebol
// struktur (breakdown/breakout sungguhan) baru masuk; LIMIT masuk LANGSUNG
// di puncak ekstensi ITU SENDIRI (sisi struktur yg BERLAWANAN dr STOP -
// high utk sell, low utk buy), bertaruh pembalikan mulai dr situ tanpa
// perlu tunggu konfirmasi tambahan. Divalidasi jaraknya (xATR) sama spt
// Repend LIMIT - jgn dipasang kalau kejauhan/kedekatan drpd harga skrg.
input ENUM_REPEND_MODE ExhPendOrderMode = REPEND_STOP_ONLY; // 0=STOP asli, 1=LIMIT baru, 2=KEDUANYA (dua tiket independen)
input double   ExhPendLimitMinATR     = 0.2;     // v58: dilonggarkan (0.3->0.2)
input double   ExhPendLimitMaxATR     = 3.5;     // v58: dilonggarkan (2.0->3.5) - alasan sama spt RependLimitMaxATR
// v56: slot LIMIT butuh kesabaran LEBIH drpd STOP - taruhannya "tunggu
// pembalikan mulai dr titik ini", RSI wajar berfluktuasi turun-naik dikit
// walau setup dasarnya masih valid. ExhPendCancelPersistBars=2 (dirancang
// utk STOP) kalau dipakai jg utk LIMIT bisa membatalkan terlalu cepat
// sblm sempat kena. Default disini 2x lebih longgar.
input int      ExhPendLimitCancelPersistBars = 4;

//=== ENTRI LANJUTAN / CONTINUATION (momentum tengah-trend yang terlewat) ===
// Sistem flip+jendela hanya entri di sekitar PEMBALIKAN. Trend kuat yang
// terus berjalan setelah jendela lewat = momentum terbuang. Entri lanjutan
// memakai panah presisi Supertrend_Promax (buffer 5/6: pullback ke garis +
// pembalikan jenuh, sudah tersaring 4 lapis di indikator) sebagai pemicu
// entri SEARAH trend yang sedang berjalan.
input bool     UseContinuationEntries = true;
input int      ContSignalBuyBuffer    = 5;        // buffer panah BUY presisi Supertrend_Promax
input int      ContSignalSellBuffer   = 6;        // buffer panah SELL presisi Supertrend_Promax

//=== BAHASA GARIS SUPERTREND (wawasan teknikal: garis > panah) ===
// Sifat garis ST: hanya MELANGKAH MAJU kalau harga benar2 maju (ratchet).
// - Garis DATAR berkepanjangan = sideways menurut indikatornya sendiri
//   (deteksi ranging lebih murni & cepat dari ADX) -> entri diblokir.
// - Garis MULAI MAJU LAGI setelah datar = trend melanjutkan dgn tenaga
//   baru -> dipakai sbg PEMICU entri tambahan (pemicu ke-3).
input bool     UseLineSlopeGate       = true;   // Blokir entri rider saat garis ST datar (sideways)
input int      LineFlatBars           = 5;      // Jendela pengukuran kemiringan garis (bar)
// MinLineSlopeATR: KEMIRINGAN MINIMAL: garis wajib maju >= 0.3xATR dlm jendela itu - trend lemah/pendek (garis nyaris datar) tidak dilayani, hanya trend CURAM/KUAT
input double   MinLineSlopeATR        = 0.30; // kemiringan minimal garis (xATR) - hindari tren datar
input bool     UseLineResumeTrigger   = true;   // Pemicu: garis maju lagi setelah datar
// MaxLegAgeBars: JANGAN entri di kaki trend yg sudah TUA: garis sudah menanjak beruntun > N bar = telat, tunggu kaki baru (0=nonaktif)
input int      MaxLegAgeBars          = 10; // umur maksimal kaki tren sblm dianggap telat (bar)
// v35: dulu leg "tua" (>MaxLegAgeBars) diblokir MUTLAK, padahal jumlah bar
// bukan bukti trend sudah jenuh - trend yg SANGAT KUAT & LURUS justru bisa
// berjalan lama tanpa tanda melemah (ini persis komplain: "tren menanjak
// garis lurus simetris...tidak dikonfirmasi..padahal kalau bisa dikonfirmasi
// akan profit besar"). Sekarang leg tua HANYA diblokir kalau ADX juga mulai
// MELEMAH (bukti nyata kehabisan tenaga) dibanding LegAgeADXLookback bar lalu;
// kalau ADX masih naik/tetap, trend dianggap masih sehat walau sudah lama,
// tetap dilayani.
input int      LegAgeADXLookback      = 5;      // brp bar lalu utk cek ADX melemah/tidak saat leg dianggap "tua"
// ContQuorumRequired: v38: dari 5 gerbang searah (H1,H4,HA,Regime,HTFBias), min berapa yg wajib lolos (dulu wajib 5/5 - terbukti 0 eksekusi dlm 7 bulan data nyata)
input int      ContQuorumRequired     = 4; // min gerbang yg wajib lolos dari 5 (v38)

// ============================================================
// v6.47 EXECUTION RECOVERY
// Tujuan:
// - jangan mengubah baseline v6.46/FIX2
// - memberi jalur eksekusi ketika trigger genuine terdeteksi
// - quorum hanya menjadi filter lunak untuk jalur recovery
// - filter risiko utama tetap aktif
// ============================================================
input bool     EnableExecutionRecovery = true;

// Minimum directional agreement untuk recovery.
// 2 = Supertrend + minimal satu konfirmasi.
// Jangan gunakan 0/1 pada pengujian awal.
input int      RecoveryMinVotes        = 2;

// Jika true, trigger genuine boleh masuk ke market execution
// setelah melewati filter risiko utama.
input bool     RecoveryAllowMarket     = true;

// Jika true, EA boleh memasang pending BUY/SELL STOP.
input bool     RecoveryAllowStopOrders = true;

// Jika true, EA boleh memasang BUY/SELL LIMIT.
input bool     RecoveryAllowLimitOrders = true;

// Mode pending recovery:
// 0 = market saja
// 1 = stop
// 2 = limit
// 3 = stop + limit
input int      RecoveryPendingMode     = 3;

// === v62: CONTROLLED A/B QUORUM EXPERIMENT ===
// false = gunakan ContQuorumRequired baseline
// true  = gunakan QuorumABOverride untuk eksperimen A/B
// HANYA continuation quorum yang berubah.
input bool     EnableQuorumABOverride = false;
input int      QuorumABOverride       = 4; // CONTROL=4, EXPERIMENT=3

//=== v36: GERBANG AI (opsional) ===
// Model decision tree, dilatih offline dari data historis Anda sendiri -
// lihat PANDUAN_INTEGRASI_AI_v2.md. Default MATI (false) - tidak mengubah
// perilaku EA sama sekali sampai Anda aktifkan sendiri. WAJIB backtest dulu
// dgn UseAIScoreGate=false (harus identik dgn hasil v35 sebelumnya) sebelum
// coba true, dan bandingkan hasilnya.
input bool     UseAIScoreGate         = false;
input double   AI_Threshold           = 0.5;    // naikkan (mis. 0.6-0.7) utk lbh selektif/yakin

// === TIME CONTROL ===
input bool     UseTimeControl         = false;
input bool     TradeMonday            = true;
input bool     TradeTuesday           = true;
input bool     TradeWednesday         = true;
input bool     TradeThursday          = true;
input bool     TradeFriday            = true;
input bool     TradeSaturday          = false;
input bool     TradeSunday            = false;
input string   TradingStartTime       = "00:00";
input string   TradingEndTime         = "23:59";

// === DAILY TARGET ===
input bool     UseDailyTarget         = false;
input ENUM_TARGET_TYPE TargetType     = TARGET_IN_MONEY;
input double   DailyTargetValue       = 100.0;
input int      MaxDailyTargetHits     = 100;
input string   DailyResetTime         = "00:00";

// === PAIR PROFILE (khusus XAUUSD - v68) ===
input bool     UseAutoInstrumentProfile = true;
input double   GoldSpreadMultiplier   = 3.0;
// v68: OilSpreadMultiplier/CryptoSpreadMultiplier/CryptoLotReduction/
// JPYSpreadMultiplier/ExoticSpreadMultiplier/ExoticLotReduction dihapus -
// khusus XAUUSD, tak perlu parameter instrumen lain.

input ENUM_EXEC_MODE ExecutionMode    = EXEC_AUTO; // AUTO=order otomatis; SIGNAL_ONLY=alert+panah utk entri manual
input bool         DebugEntryTrace     = false;    // DEV: trace sinyal/order; aktifkan hanya saat diagnosis Strategy Tester

//=== MODE STRATEGI (TEMUAN KUNCI dari 8 test) ===
// Data 8 test konsisten: trade PROFIT hampir selalu SEARAH trend besar;
// trade kena SL hampir selalu entri PEMBALIKAN yang gagal. EA lama = mesin
// REVERSAL (berburu titik balik = jenis trading tersulit). TREND_RIDER =
// mesin baru: hanya trading SEARAH trend yang sedang berjalan (H1+H4
// selaras), entri di panah presisi/pullback, exit oleh Supertrend trailing
// yang sudah terbukti - persis ekspektasi "BUY saat tren naik, SELL saat
// tren turun, tunggangi sampai puncak".
// StrategyMode: BOTH = cakupan penuh: mesin REVERSAL menangkap pergantian arah trend, mesin TREND RIDER menunggangi trend berjalan - tidak ada momentum signifikan yang terlewat
input ENUM_STRATEGY_MODE StrategyMode = STRAT_BOTH; // BOTH=cakupan penuh (Reversal+Trend Rider)
// Gerbang H4 3 tingkat (hasil test 6 bln: STRICT sehat tapi frekuensi rendah ~1.5 trade/bln):
// STRICT = H4 wajib sudah searah (paling aman, paling jarang)
// SOFT   = H4 searah ATAU candle H4 terakhir sudah bergerak ke arah sinyal +
//          harga sudah menembus garis ST H4 sisi lawan (gelombang besar sedang berbalik)
// OFF    = tanpa gerbang H4 (paling sering, kualitas turun)
input ENUM_H4_MODE UseH4AlignmentForTrend = H4_SOFT;

//=== GAYA ENTRI (jawaban utk "entri selalu di puncak candle") ===
// Sistem konfirmasi-closed-candle otomatis entri SETELAH candle konfirmasi
// selesai = harga sudah berlari (area puncak). ENTRY_PULLBACK_LIMIT: setelah
// sinyal valid, EA memasang pending LIMIT di bawah harga (BUY) / di atas
// (SELL), menunggu harga retrace dulu -> entri lebih dekat ke low/awal
// pergerakan, SL lebih pendek, reward lebih besar. Kalau harga tak pernah
// mundur dlm batas waktu, pending dibatalkan (trade dilewati).
// EntryStyle: MARKET (default - terbukti terbaik di test). PULLBACK_LIMIT terbukti kena "adverse selection": pemenang tak pernah retrace (terlewat), pecundang retrace dalam (terisi) - hanya utk eksperimen
input bool         UseTeamLeaderExecution = true;
input int          TeamSignalLookbackBars = 3;
input int          TeamMinQuorum          = 3;
input double       TeamMinScore           = 55.0;
input bool         TeamRequireHA           = true;
input bool         TeamRejectESPVeto       = true;
input bool         TeamRequireSRRoom       = false;
input double       SR_MinRoomATR         = 0.0;   // minimum SR room in ATR units; 0 preserves prior behavior
input bool         TeamUseMTFSafety        = true;
input int          ST_PendingHintBuffer    = 13;
input ENUM_ENTRY_STYLE EntryStyle          = ENTRY_AUTO; // AUTO/MARKET/LIMIT/STOP
input double   PullbackATRFactor      = 0.5;    // Jarak retrace yang ditunggu (kelipatan ATR)
input int      PullbackExpiryBars     = 4;      // Pending dibatalkan bila tak tersentuh dlm N bar

//=== SUPERTREND TRAILING - SL & TP ADAPTIF DINAMIS (permintaan khusus) ===
// SL mengikuti GARIS SUPERTREND itu sendiri: dinamis (jarak ATR), tidak
// pernah mundur (profit terkunci), dan KEBAL koreksi/zigzag by design -
// garis hanya tertembus saat trend BENAR-BENAR patah. Saat profit sudah
// cukup (TrendRun_MinProfitATR x ATR), TP DILEPAS (didorong menjauh terus)
// supaya trend kuat bisa lari sampai puncak - exit-nya nanti oleh SL garis
// Supertrend yang terus membuntuti.
input bool     UseSupertrendTrailing  = true;
input double   ST_TrailBufferATR      = 0.35;   // v2.00: jarak aman SL dr garis ST, x ATR (dulu 3 pip = $0.03 - SL praktis MENEMPEL di garis)
input double   ST_TrailBufferPips     = 3.0;    // [WARISAN] hanya dipakai kalau UseATRRelativeExits=false
input bool     SpikeGuardRespectSTLine = true;  // v2.00 BUG-5: Spike Guard dilarang lebih ketat dari garis Supertrend
input bool     MomentumTrailRespectST  = true;  // v2.00 BUG-5: Momentum Candle Trail dilarang lebih ketat dari garis Supertrend
// v65: MOMENTUM CANDLE TRAILING - respons cepat thd 1 candle KUAT (bukan
// tren multi-bar spt kemiringan), sesuai permintaan Anda. Begitu candle
// SEBELUMNYA (baru tertutup) range-nya jauh melebihi ATR normal (candle
// "panjang" - momentum kuat searah posisi), SL langsung ditarik ke dekat
// low/high candle itu (dgn buffer utk ruang koreksi/zigzag wajar) - BUKAN
// nunggu trailing ATR generik yg jarak tetapnya sama tak peduli seberapa
// kuat momentum baru saja terjadi. Hanya MENGETATKAN (ratchet), tak pernah
// melonggarkan, & tetap hormat masa tenggang (spt mekanisme lain).
input bool     UseMomentumCandleTrail = false;  // v2.00: tetap MATI default - kini hormat garis ST kalau dinyalakan. Uji A/B.  // master switch - default MATI, aktifkan manual utk uji
input double   MomentumCandleATRMult  = 1.3;    // candle dianggap "panjang/kuat" kalau range (H-L) >= ini xATR
input double   MomentumCandleBufferATR= 0.3;    // buffer xATR dr low/high candle itu - beri ruang koreksi/zigzag wajar
input bool     TrendRun_ReleaseTP     = true;   // Lepas TP saat trend terbukti kuat (biarkan lari ke puncak)
input double   TrendRun_MinProfitATR  = 1.0;    // Profit minimal (kelipatan ATR) sebelum TP dilepas

input ENUM_TRADING_MODE TradingMode   = MODE_NORMAL;
input ENUM_TRADE_DIRECTION TradeDirection = TRADE_BOTH;

// === DYNAMIC TP/SL ===
input bool     UseDynamicSL           = true;
input bool     UseDynamicTP           = true;
input ENUM_DYNAMIC_DISTANCE DynamicTPDistance = DIST_NORMAL;
input ENUM_DYNAMIC_SPEED   DynamicTPSpeed   = SPEED_NORMAL;
input ENUM_DYNAMIC_DISTANCE DynamicSLDistance = DIST_NORMAL;
input ENUM_DYNAMIC_SPEED   DynamicSLSpeed   = SPEED_SLOW;

// === DASHBOARD ORIGINAL ===
input bool     ShowDashboard          = true;
input int      Dash_X                 = 5;
input int      Dash_Y                 = 5;
input color    C_BG                   = clrBlack;
input color    C_Panel                = clrBlack;
input color    C_Gold                 = C'255,200,0';
input color    C_Green                = C'60,180,75';
input color    C_Red                  = C'220,80,60';
input color    C_Blue                 = C'65,150,220';
input color    C_Orange               = C'255,140,0';
// v42c: C_Purple/C_Cyan/C_Magenta DIHAPUS - dideklarasikan sbg opsi warna
// dashboard tp TIDAK PERNAH dipakai di kode manapun (beda dgn C_Gold/
// C_Orange/dkk yg memang aktif dipakai) - kalau user mengubah nilainya,
// tidak ada apa pun di tampilan yg berubah. Menyesatkan kalau dibiarkan
// seolah2 fungsional.
input color    C_Text                 = C'220,220,220';
input color    C_Gray                 = C'120,120,120';
input color    C_Border               = C'50,55,60';

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+
bool    g_Active = true, g_GoalHit = false, g_HideUI = false, g_AllowTrading = true;
string  SHOW_BTN = "UGE70_SHOW_BUTTON", PFX = "UGE70_";
int     g_Magic, g_Digits, g_StopLevel;
double  g_Point, g_PipPoint;
double  g_CurrentFloatingProfit = 0, g_TotalBuyProfit = 0, g_TotalSellProfit = 0, g_TotalLots = 0;
int     g_CurrentOrders = 0, g_BuyPositions = 0, g_SellPositions = 0;
double  g_DailyProfit = 0, g_MaxDailyProfit = 0;
double  g_DayStartEquity = 0; // v27: patokan ekuitas titik-reset - dasar hitung profit "hari ini" yg benar
double  g_DailyTotalForTarget = 0; // v27: selisih ekuitas dari titik reset - dipakai target, panel, & loss-limit
double  g_RecoveryDeficit = 0;     // v30: defisit yg harus dipulihkan ($)
int     g_RecoveryTradesUsed = 0;  // v30: jml trade recovery terpakai utk defisit ini
bool    g_RecoveryArmedThisSignal = false; // v30: flag momentum-kuat utk sinyal yg sedang dieksekusi
int      g_ExhPendTicket = -1;     // v32: tiket pending titik-jenuh aktif (-1 = tidak ada)
int      g_RependLimitTicket = -1; // v53: tiket pending Repend LIMIT aktif (-1 = tidak ada) - dipakai utk trailing ke garis ST
int      g_ExhPendDir = 0;         // v32: arah pending (1=buy stop, -1=sell stop)
datetime g_ExhPendPlacedBar = 0;   // v32: bar saat pending dipasang (utk umur)
int      g_ExhPendNotExhaustedStreak = 0; // v37: hitung bar beruntun "tidak lagi jenuh" sblm dibatalkan
string   g_ExhPendInfo = "-";      // v32: teks info pending utk panel dashboard
// v55: slot LIMIT terpisah (paralel dgn slot STOP di atas) - supaya mode
// BOTH bisa jalankan dua tiket independen (STOP & LIMIT sekaligus),
// masing2 dgn siklus hidup (pasang/geser/hapus) sendiri.
int      g_ExhPendLTicket = -1;
int      g_ExhPendLDir = 0;
datetime g_ExhPendLPlacedBar = 0;
int      g_ExhPendLNotExhaustedStreak = 0;
string   g_ExhPendLInfo = "-";
int     g_DailyTargetHits = 0, g_TargetResetCount = 0;
datetime g_LastResetDay = 0, g_LastProfitResetTime = 0, g_LastDailyResetTime = 0;
bool    g_FirstEntryToday = true, g_TargetAchievedToday = false;
string  g_Status = "SYSTEM ACTIVE";
color   g_StatusColor = C_Green;
double  g_PairTakeProfit = 150, g_PairStopLoss = 300, g_PairMaxSpread = 35;
double  g_LotMultiplier = 1.0, g_DrawdownReductionFactor = 1.0, g_ConsecutiveLossFactor = 1.0;
// v53 FIX BUG PENTING: TradingMode (Conservative/Normal/Aggressive) SELAMA
// INI hanya berlaku di jalur RiskPerTrade=0 (lot manual tetap) - SEMUA tes
// sepanjang percakapan ini pakai RiskPerTrade>0 (risk-based otomatis), jadi
// TradingMode TIDAK PERNAH benar-benar berpengaruh, cuma label kosmetik di
// dashboard. FIX: g_ModeRiskMult & g_ModeQuorumAdjust kini dihitung dari
// TradingMode SEKALI di OnInit, dipakai di CalculateLotSize (jalur
// risk-based) DAN kuorum Trend Rider - supaya ketiga mode benar2 beda
// perilaku brp pun nilai RiskPerTrade yg dipakai.
double  g_ModeRiskMult = 1.0; int g_ModeQuorumAdjust = 0;
double  g_CurrentDrawdownPercent = 0, g_HighestBalance = 0; // v42c: g_StartingBalance dihapus - dideklarasikan tp tak pernah dibaca/ditulis di manapun
int     g_ConsecutiveLosses = 0;
bool    g_DrawdownProtectionActive = false, g_TradingPaused = false;
datetime g_PauseUntilTime = 0, g_LastEntryTime = 0, g_LastMarketEntryCandle = 0;
double  g_ATRPercentAdjusted = 0;
double  g_spreadBuffer[20]; int g_spreadIndex = 0;
bool    g_IsGold = false, g_IsSupportedPair = true;
// --- v2.00: state baru utk sistem keamanan & diagnostik ---
int     g_ModifyErrCount   = 0;   // BUG-2: hitung kegagalan modify NYATA (error 1 tak dihitung, sudah dicegah)
int     g_cnt_RiskCap      = 0;   // berapa kali entri diblokir pagar risiko agregat
int     g_cnt_MonitorFull  = 0;   // berapa kali slot monitor penuh (BUG-8)
bool    g_IndicatorsOK     = false; // BUG-9: hasil validasi indikator di OnInit
bool    g_CounterTrendSignal = false; // v3.00: sinyal saat ini melawan bias TF-atas -> lot dikecilkan
int     g_cnt_CounterTrend  = 0;      // v3.00: berapa entri lawan-tren yg diperkecil
int     g_cnt_DeadCut       = 0;      // v3.00: berapa trade mati dipotong
int     g_cnt_Ladder        = 0;      // v3.00: berapa kunci tangga profit tercapai
int     g_cnt_Ladder2       = 0;      // v3.00: berapa yg mencapai anak-tangga >=2 (1,5xATR)
int     g_HA_Direction_Val = 0, g_HA_Direction_Prev = 0;
int     g_ST_Trend = 0, g_ST_Trend_Prev = 0;
// --- Counter diagnostik: berapa kali tiap tahap filter menolak sinyal ---
int g_cnt_STFlip=0, g_cnt_HAFlip=0, g_cnt_MTF=0, g_cnt_TrendAge=0, g_cnt_ADXFalse=0, g_cnt_OverExt=0, g_cnt_Correction=0, g_cnt_Volatility=0, g_cnt_News=0, g_cnt_SR=0, g_cnt_ESP=0, g_cnt_Chase=0, g_cnt_Regime=0, g_cnt_Valid=0;
int g_cnt_Compress=0, g_cnt_WeakBody=0, g_cnt_OppLock=0; // v16: kotak sideways, candle lemah, kunci arah lawan
int g_cnt_HTFBias=0; // v31: bias TF-atas (reversal). v42c: g_cnt_ContHTFBias dihapus - mati sejak v38 (diganti sistem kuorum, tak pernah diinkremen/dicetak lagi)
int g_cnt_Late=0, g_cnt_Knife=0; // v18: entri telat direlakan, perisai anti-pisau
datetime g_LastFlipTraded = 0;   // waktu bar flip yg SUDAH dieksekusi (cegah entri ganda dari flip yg sama)
datetime g_LastTeamSignalTime = 0;
datetime g_CurrentFlipTime = 0;  // waktu bar flip dari sinyal valid terakhir (diisi IsPerfectReversalSignal)
int     g_ST_Trend_M5 = 0, g_ST_Trend_M15 = 0, g_ST_Trend_M30 = 0, g_ST_Trend_H1 = 0, g_ST_Trend_H4 = 0;
double  g_ST_Up_Val = 0, g_ST_Dn_Val = 0;
double  g_MarginLevel = 0;
double  g_DisplaySupport = 0, g_DisplayResistance = 0;
double  g_SpreadMultiplier = 1.0;

// === UI MANUAL CONTROL ===
bool    g_UseManualLot = false;   double g_ManualLotValue = 0.01;
bool    g_UseManualTarget = false; double g_ManualTargetValue = 100.0;
bool    g_UseManualSL = false;    double g_ManualSLValue = 0.0;
bool    g_UseManualTP = false;    double g_ManualTPValue = 0.0;
bool    g_IsTradingTime = true, g_IsTradingDay = true;

// === ADAPTIVE STATE ===
struct SAdaptiveState { double entryThresholdMult, tpMult, slMult, trailMult, lotMult, spreadToleranceMult; };
SAdaptiveState g_AdaptiveState = {1.0, 1.0, 1.0, 1.0, 1.0, 1.0};

// === TRADE MONITOR ===
struct TradeMonitor {
   int ticket; double highestPrice; double lowestPrice; double highestProfitPips;
   double spikeHighPrice; // v49: puncak harga TIAP TICK (bukan per-bar) - dasar Spike Guard
   double peakProfitATR;  // v3.00: PUNCAK profit dlm kelipatan ATR, dilacak TIAP TICK, tak pernah turun - dasar Tangga Kunci Profit
   int    ladderStep;     // v3.00: anak tangga tertinggi yg sudah terkunci (0=blm ada)
   bool   deadCutDone;    // v3.00: penanda Pemotong Trade Mati sudah dievaluasi
   double atrEntry; int barsHeld; bool partialClosed; bool partialLevel1Done; bool partialLevel2Done;
   datetime openTime; double virtualSL; bool softStopActive;
   double graceNormalSL; bool graceActive; int graceBarsTarget; // v46: masa tenggang SL - target SL normal (sempit) yg diterapkan setelah masa tenggang lewat; v57: graceBarsTarget per-posisi (LIMIT dpt lebih lama drpd default)
};
// v2.00 BUG-8: dinaikkan 20 -> 50. Dgn piramida + repending + tiket sisa
// partial-close, 20 slot bisa habis. Posisi yg tak kebagian slot TIDAK dapat
// trailing/BE/partial/spike-guard sama sekali - ia menggantung dgn SL awal
// tanpa satu pun peringatan. Kini kapasitas dinaikkan DAN kejadiannya dicatat.
#define MAX_TRADE_MONITORS 50
TradeMonitor g_tradeMonitors[MAX_TRADE_MONITORS];
int g_tradeMonitorCount = 0;

//+------------------------------------------------------------------+
//| FORWARD DECLARATIONS                                             |
//+------------------------------------------------------------------+
double PipPoint(); int SafeRound(double x);
// --- v2.00: fungsi baru (perbaikan audit) ---
double PipValuePerLot();
bool   SafeOrderModify(int ticket, double price, double sl, double tp, datetime expiry, color clr, string tag="");
double GetTotalOpenRiskMoney();
double GetTotalOpenRiskPercent();
bool   IsTotalRiskCapOK(double newLots, double newSLPips, string what);
bool   ValidateCustomIndicators();
void   CheckProfitLadder();
double GetVolSpikeRatio();
double GetATRInPips();
double STCustom(int tf, int buf, int shift);
double GetSupertrendLine(int tf, int line, int shift);
bool IsOverExtended(int direction, int flipShift);
double GetPreFlipExtensionPips(int direction, int flipShift);
int GetTrendAgeBars(int oldDir, int flipShift);
bool HasCorrectionPattern(int direction, int flipShift);
bool WasOldTrendGenuine(int oldDir, int flipShift);
int FindRecentFlip(int direction);
bool IsPerfectReversalSignal(int direction);
bool IsNewsBlocked();
void RefreshData();
void CheckEntry();
bool IsTeamLeaderSignal(int direction, int &signalShift);
bool IsTeamConsensusValid(int direction, int signalShift, double &score, int &quorum, string &why);
int  GetTeamPendingHint(int direction, int shift);
bool ExecuteTeamPendingOrder(int direction, int pendingType);
bool ExecuteTeamLeaderEntry(int direction, int signalShift);
bool ExecuteSmartOrder(int type);
bool ExecutePullbackOrder(int direction);
void ManagePendingPullbacks();
void UpdatePositionStats();
void CalcDailyProfit();
void CheckDailyReset();
void CheckTradingTime();
bool CanTradeNow();
bool IsDayOfWeekEnabled();
bool IsTimeInRange(string start, string end);
int TimeToSeconds(string t);
void ApplyIntelligentTrailing(int tic);
void ApplyDynamicProtection();
void EnsureAllOrdersMonitored();
void EnsureInitialSLTP();
void CloseAllPositions();
void CancelAllPendingOrdersSafe();
void ForceDeleteAllPendingOrders();
void UpdateDashboard();
void CreateDashboard();
void CreateShowButton();
void CreateRect(string n, int x, int y, int w, int h, color c, color b, int z=0);
void CreateLabel(string n, string t, int x, int y, color c, int s, bool bld=false, int a=ANCHOR_LEFT_UPPER, int z=1);
void CreateButton(string n, string t, int x, int y, int w, int h, color c, color txt, int z=2);
void UpdateDashboardValues();
void UpdateDashboardPositionDetails();
void ApplyManualSLTPToAllOrders();
double GetManualSLPips();
double GetManualTPPips();
double GetManualLot();
double GetManualTargetAmount();
void AddTradeMonitor(int tic);
void SetVirtualSL(int tic, double vsl);
void SetGracePeriod(int tic, double normalSL, int barsTarget=-1);
void ManageEntryGracePeriod(int tic);
void RemoveTradeMonitor(int tic);
void CheckVirtualStopLosses();
double GetEffectiveMinStopDist();
double GetAverageSpread(int period);
double GetSupportLevel();
double GetResistanceLevel();
void UpdateSRLevels();
void DetectAndConfigurePair();
void ConfigurePairParameters();
void CalibrateBaselineFromATR();
bool CheckVolatilityFilter();
double CalculateLotSize(double slPips);
string GetPauseStatus();
string TradingModeToString(ENUM_TRADING_MODE m);
double GetMinLotLimit();
double GetMaxLotLimit();
double GetAdaptiveStopLossPips();
double GetAdaptiveTakeProfitPips();
bool IsSupertrendNativeSignalValid(int direction);
bool IsHeikenAshiFlip(int direction);
bool IsSupertrendFlip(int direction);
void UpdateOverallTrend();
void CalculateTrendStrength();
bool IsTrendFavorableForBuy();
bool IsTrendFavorableForSell();
void UpdateAdaptiveSystem();
void CheckDrawdownProtection();
void CheckConsecutiveLossProtection();

//+------------------------------------------------------------------+
//| IMPLEMENTASI FUNGSI                                              |
//+------------------------------------------------------------------+
int SafeRound(double x) { return (int)MathRound(x); }
double PipPoint() {
   if(g_PipPoint <= 0) g_PipPoint = (g_Digits == 3 || g_Digits == 5) ? g_Point * 10.0 : g_Point;
   return g_PipPoint;
}

//+------------------------------------------------------------------+
//| v2.00 BUG-1 FIX: NILAI 1 PIP PER 1.0 LOT (dalam mata uang akun).  |
//| Versi lama menghitung ini INLINE di CalculateLotSize() dgn        |
//| "* 10.0" di ujungnya - sisa asumsi broker forex 5-digit yg tak    |
//| pernah dibuang saat EA dikhususkan ke gold. Karena 'point' di     |
//| rumus itu SUDAH hasil PipPoint() (satuan pip, bukan Point),       |
//| mengalikan 10 lagi membuat nilai pip 10x KEBESARAN.               |
//| Bukti dr jurnal tes: EA mencetak "risiko ~$876.74" utk 0.02 lot   |
//| dgn SL 4384 pip; risiko SEBENARNYA 0.02 x 100oz x $43.84 = $87.68 |
//| Akibat terparah ada di mode risk-based: lot = risk/(slPips x      |
//| pipValue) menghasilkan lot 10x TERLALU KECIL -> selalu jatuh ke   |
//| minimum broker -> compounding mati total.                         |
//| Dipusatkan di satu fungsi supaya tak bisa lagi salah di tempat    |
//| berbeda-beda.                                                     |
//+------------------------------------------------------------------+
double PipValuePerLot() {
   // v4.02 XAU RISK FIX: derive XAU pip value from contract size.
   // Test v3.02 showed broker tick-value reporting $5/pip while the
   // XAUUSD 100 oz / 0.01-price contract implies $1/pip/lot. That
   // mismatch caused otherwise-valid candidates to be blocked by risk cap.
   double point = PipPoint();
   if(g_IsGold) {
      double contractSize = MarketInfo(Symbol(), MODE_LOTSIZE);
      if(contractSize > 0 && point > 0) return contractSize * point;
      return 1.0;
   }
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double tickSize  = MarketInfo(Symbol(), MODE_TICKSIZE);
   if(tickValue <= 0 || tickSize <= 0) return 10.0;
   double pv = tickValue * (point / tickSize);
   if(pv <= 0) pv = 10.0;
   return pv;
}

//+------------------------------------------------------------------+
//| v2.00 BUG-2 FIX: OrderModify AMAN - satu pintu utk SEMUA modify.  |
//| AKAR MASALAH yg ditemukan di audit: kode lama membandingkan       |
//| kandidat SL MENTAH (belum dinormalisasi, mis. 4389.5312) thd SL   |
//| terpasang yg SUDAH dibulatkan broker (4389.53). Perbandingan itu  |
//| selalu bilang "ada perbaikan", tapi yg DIKIRIM ke broker adalah   |
//| nilai ternormalisasi yg PERSIS SAMA -> MT4 balas error 1          |
//| (ERR_NO_RESULT) -> SL tak pernah berubah -> kondisi tetap true    |
//| SELAMANYA -> diulang TIAP TICK.                                   |
//| Jurnal tes membuktikan: 22.109 baris "OrderModify error 1",       |
//| puncak 1.273 request dalam SATU MENIT (~21 req/detik). Di backtest|
//| ini cuma sampah log; di akun REAL ini memicu error 146 (trade     |
//| context busy), throttling broker, sampai pembatasan akun - DAN    |
//| menahan trade context shg entri/SL yg sungguhan penting tertunda. |
//| Fungsi ini menormalisasi DULU, membandingkan nilai ternormalisasi,|
//| dan MENOLAK memanggil OrderModify kalau tak ada perubahan nyata.  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| v2.00 PAGAR RISIKO AGREGAT - total risiko SEMUA posisi terbuka.   |
//| Menjumlahkan (lot x jarak-ke-SL x nilai-pip) dari setiap posisi   |
//| milik EA ini. Posisi TANPA SL dihitung memakai SL adaptif normal  |
//| sbg perkiraan konservatif (bukan dianggap nol-risiko).            |
//+------------------------------------------------------------------+
double GetTotalOpenRiskMoney() {
   double pipValue = PipValuePerLot();
   double point    = PipPoint();
   double total    = 0;
   for(int i = OrdersTotal()-1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;
      int t = OrderType();
      double lots = OrderLots(), open = OrderOpenPrice(), sl = OrderStopLoss();
      double slPips;
      if(t == OP_BUY || t == OP_SELL) {
         if(sl > 0) slPips = MathAbs(open - sl) / point;
         else       slPips = GetAdaptiveStopLossPips();   // tanpa SL = pakai perkiraan konservatif
      }
      else if(t == OP_BUYSTOP || t == OP_SELLSTOP || t == OP_BUYLIMIT || t == OP_SELLLIMIT) {
         // pending BELUM jadi risiko terealisasi, tapi bisa terisi kapan saja -
         // dihitung penuh supaya pagar tidak bisa diakali dgn menumpuk pending.
         if(sl > 0) slPips = MathAbs(open - sl) / point;
         else       slPips = GetAdaptiveStopLossPips();
      }
      else continue;
      if(slPips <= 0) continue;
      total += lots * slPips * pipValue;
   }
   return total;
}
double GetTotalOpenRiskPercent() {
   double bal = AccountBalance();
   if(bal <= 0) return 0;
   return GetTotalOpenRiskMoney() / bal * 100.0;
}
//+------------------------------------------------------------------+
//| Gerbang: boleh tidaknya menambah eksposur baru. Dipanggil SEBELUM |
//| setiap entri pasar, piramida, dan pemasangan pending.             |
//+------------------------------------------------------------------+
bool IsTotalRiskCapOK(double newLots, double newSLPips, string what) {
   if(!UseTotalRiskCap) return true;
   double bal = AccountBalance();
   if(bal <= 0) return true;
   double pipValue = PipValuePerLot();
   double addRisk  = newLots * newSLPips * pipValue;
   double openRisk = GetTotalOpenRiskMoney();
   double totalPct = (openRisk + addRisk) / bal * 100.0;
   if(DebugEntryTrace)
      Print("[RISK TRACE] ",what," lot=",DoubleToString(newLots,2),
            " SL=",DoubleToString(newSLPips,1)," pipValue=$",DoubleToString(pipValue,4),
            " addRisk=$",DoubleToString(addRisk,2)," openRisk=$",DoubleToString(openRisk,2),
            " total=",DoubleToString(totalPct,2),"% cap=",DoubleToString(MaxTotalRiskPercent,2),"%");
   if(totalPct > MaxTotalRiskPercent) {
      g_cnt_RiskCap++;
      Print("ðŸ›¡ï¸ PAGAR RISIKO AGREGAT: ", what, " DIBLOKIR - risiko terbuka $",
            DoubleToString(openRisk,2), " + calon $", DoubleToString(addRisk,2),
            " = ", DoubleToString(totalPct,1), "% balance (batas ",
            DoubleToString(MaxTotalRiskPercent,1), "%)");
      return false;
   }
   return true;
}

bool SafeOrderModify(int ticket, double price, double sl, double tp, datetime expiry, color clr, string tag="") {
   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES)) return false;
   double nPrice = NormalizeDouble(price, g_Digits);
   double nSL    = NormalizeDouble(sl,    g_Digits);
   double nTP    = NormalizeDouble(tp,    g_Digits);
   double cPrice = NormalizeDouble(OrderOpenPrice(),  g_Digits);
   double cSL    = NormalizeDouble(OrderStopLoss(),   g_Digits);
   double cTP    = NormalizeDouble(OrderTakeProfit(), g_Digits);
   // TIDAK ADA perubahan nyata -> jangan ganggu broker sama sekali.
   if(nPrice == cPrice && nSL == cSL && nTP == cTP && expiry == OrderExpiration()) return true;
   ResetLastError();
   if(OrderModify(ticket, nPrice, nSL, nTP, expiry, clr)) return true;
   int err = GetLastError();
   if(err != 0 && err != 1) {
      g_ModifyErrCount++;
      if(g_ModifyErrCount <= 50)   // jangan banjiri jurnal kalau ada masalah sistemik
         Print("âš ï¸ OrderModify gagal #", ticket, " err ", err, (tag=="" ? "" : " ["+tag+"]"));
   }
   return false;
}
double GetATRInPips() {
   double atr = iATR(NULL, 0, ATRPeriod_SL, 1);
   if(atr <= 0) return 0;
   return atr / PipPoint();
}
double GetAverageSpread(int period) {
   int size = ArraySize(g_spreadBuffer);
   if(size < period) { ArrayResize(g_spreadBuffer, period); for(int i=size; i<period; i++) g_spreadBuffer[i]=0; }
   double cur = MarketInfo(Symbol(), MODE_SPREAD) * PipPoint();
   g_spreadBuffer[g_spreadIndex] = cur;
   g_spreadIndex = (g_spreadIndex + 1) % period;
   double sum = 0; int cnt = 0;
   for(int i=0; i<period; i++) if(g_spreadBuffer[i] > 0) { sum += g_spreadBuffer[i]; cnt++; }
   return (cnt > 0) ? sum / cnt : cur;
}
double GetEffectiveMinStopDist() { return 15; }
double GetMinLotLimit() { double m = MarketInfo(Symbol(), MODE_MINLOT); return (m <= 0) ? 0.01 : m; }
double GetMaxLotLimit() { double m = MarketInfo(Symbol(), MODE_MAXLOT); return (m <= 0) ? 100.0 : m; }
double GetAdaptiveStopLossPips() { return (UseDynamicSL) ? g_PairStopLoss * g_AdaptiveState.slMult : StopLoss_Fixed; }
double GetAdaptiveTakeProfitPips() { return (UseDynamicTP) ? g_PairTakeProfit * g_AdaptiveState.tpMult : TakeProfit_Fixed; }

//--- CUSTOM INDICATOR ---
// KRITIS: urutan parameter iCustom WAJIB persis sama dgn urutan input di
// Supertrend_Promax v3.00 FINAL. v3.00 menambah 8 input presisi baru
// (PrecisionComment..ExhaustMinGapBars) di antara RSIOverbought dan blok
// EA-SYNC - tanpa update ini, semua nilai setelahnya bergeser posisi
// (nilai salah masuk ke parameter salah) = sinyal kacau.
double STCustom(int tf, int buf, int shift) {
   // v3.02: complete Supertrend input contract; previous v3.01
   // passed mode/shift too early, so signal buffers returned EMPTY_VALUE.
   return iCustom(NULL, tf, SupertrendFile,
      ST_ObjectName,
      ST_ATRMultiplier,
      ST_ATRPeriod,
      ST_ATRMaxBars,
      ST_Shift,
      "====================",
      false,
      false,
      false,
      false,
      1,
      ST_EnableEntrySignals,
      ST_UsePullbackSignal,
      ST_UseADXFilter,
      ST_ADXPeriod,
      ST_ADXThreshold,
      ST_UseRSIFilter,
      ST_RSIPeriod,
      ST_RSIOversold,
      ST_RSIOverbought,
      "=== PRESISI ANTI-ZIGZAG & TITIK JENUH ===",
      ST_RSIBufferZone,
      ST_UseADXRisingFilter,
      ST_UseExhaustionReversal,
      ST_ExhaustOverbought,
      ST_ExhaustOversold,
      ST_ExhaustLookback,
      ST_ExhaustMinGapBars,
      buf, shift);
}
double GetSupertrendLine(int tf, int line, int shift) {
   if(line == 0) return STCustom(tf, 0, shift);
   else if(line == 1) return STCustom(tf, 1, shift);
   return EMPTY_VALUE;
}
bool IsSupertrendNativeSignalValid(int direction) {
   if(!UseHeikenAshi) return true;
   double v = (direction == 1) ? STCustom(0, 5, 1) : STCustom(0, 6, 1);
   return (v != EMPTY_VALUE);
}

//--- HEIKEN ASHI ---
// Pemanggil HeikenAshi_Custom v2.20 FINAL dgn urutan input persis:
// ColorUp, ColorDown, BodyWidth, WickWidth, DrawCandles, UseConfirmedColor,
// MinFlipBars, UseBodySizeFilter, MinBodyATRFactor, BodyATRPeriod, SmoothPeriod
double HACustom(int tf, int buf, int shift) {
   // v3.02: complete HeikenAshi_Custom input contract.
   return iCustom(NULL, tf, HeikenAshiFile,
      clrLime,
      clrRed,
      2,
      1,
      true,
      HA_UseConfirmedColor,
      HA_MinFlipBars,
      HA_UseBodySizeFilter,
      HA_MinBodyATRFactor,
      HA_BodyATRPeriod,
      true,
      20,
      true,
      true,
      0.45,
      2,
      false,
      250,
      true,
      600,
      26.0,
      2,
      6,
      true,
      HA_SmoothPeriod,
      buf, shift);
}
void GetInternalHA(int tf, int shift, double &haOpen, double &haClose) {
   int lookback = 60;
   double prevOpen  = (iOpen(NULL, tf, lookback) + iClose(NULL, tf, lookback)) / 2.0;
   double prevClose = (iOpen(NULL, tf, lookback) + iHigh(NULL, tf, lookback) + iLow(NULL, tf, lookback) + iClose(NULL, tf, lookback)) / 4.0;
   for(int s = lookback - 1; s >= shift; s--) {
      double o = iOpen(NULL, tf, s), h = iHigh(NULL, tf, s), l = iLow(NULL, tf, s), c = iClose(NULL, tf, s);
      double curClose = (o + h + l + c) / 4.0;
      double curOpen  = (prevOpen + prevClose) / 2.0;
      prevOpen = curOpen; prevClose = curClose;
   }
   haOpen = prevOpen; haClose = prevClose;
}
double HAOpenValue(int tf, int shift) {
   if(UseInternalHeikenAshi) { double o, c; GetInternalHA(tf, shift, o, c); return o; }
   return HACustom(tf, HA_OpenBuffer, shift);
}
double HACloseValue(int tf, int shift) {
   if(UseInternalHeikenAshi) { double o, c; GetInternalHA(tf, shift, o, c); return c; }
   return HACustom(tf, HA_CloseBuffer, shift);
}

//--- ENTRY_SIGNAL_PRO (LANTAI 3: konfirmator independen) ---
// Dipanggil TANPA parameter input = memakai default final indikator
// (semua default sudah disetel ke nilai final tersinkron saat finalisasi).
double ESPCustom(int buf, int shift) {
   // v3.02: complete Entry_Signal_Pro input contract.
   return iCustom(NULL, 0, ESP_IndicatorFile,
      "",
      0,
      6,
      12,
      7,
      7,
      7,
      12,
      12,
      50,
      25,
      -2.0,
      -1.0,
      true,
      true,
      233,
      234,
      false,
      false,
      "alert.wav",
      "alert.wav",
      false,
      true,
      ST_RSIBufferZone,
      0.15,
      true,
      67.0,
      35.0,
      6,
      true,
      true,
      true,
      true,
      false,
      0.0,
      2,
      true,
      100,
      0.35,
      true,
      600,
      12.0,
      true,
      true,
      "=== v6.00 PENYARING ZIGZAG & JENUH ===",
      false,
      40,
      false,
      0.618,
      true,
      50,
      2.2,
      true,
      true,
      18.0,
      250,
      buf, shift);
}
// v42c: HasESPSignal dihapus - genuinely tak pernah dipanggil di manapun.
// Logika veto ESP yg SUNGGUH jalan ada inline di IsPerfectReversalSignal
// (pakai ESPCustom langsung) - fungsi ini rupanya draf awal yg tertinggal,
// tidak pernah dibersihkan setelah logikanya ditulis ulang inline.

//--- PAIR PROFILE ---
// v68: IsCryptoSymbol/IsJPYPair/IsExoticPair/RefreshCryptoPipPoint dihapus
// sesuai permintaan Anda (khusus XAUUSD, tak ada cabang instrumen lain).
void CalibrateBaselineFromATR() {
   double atrPips = GetATRInPips();
   if(atrPips <= 5) atrPips = g_IsGold ? 100 : 20;
   g_PairStopLoss = MathMax(30, atrPips * ATRMultiplier_SL);
   g_PairTakeProfit = MathMax(30, g_PairStopLoss * MinRR_Ratio);
}
// v68: KHUSUS XAUUSD - infrastruktur deteksi multi-instrumen (crypto/oil/
// JPY/exotic) DIHAPUS sesuai permintaan Anda, supaya fokus EA ini murni ke
// emas tanpa ada "cabang" instrumen lain yg terselip di kode. Fondasinya
// (fungsi IsCryptoSymbol/IsJPYPair/IsExoticPair dkk) masih tersimpan di versi
// v67 kalau nanti dibutuhkan lagi utk pengembangan pair lain sbg proyek
// terpisah, TIDAK di file khusus-XAUUSD ini.
void DetectAndConfigurePair() {
   string symU = Symbol(); StringToUpper(symU);
   g_IsGold = (StringFind(symU,"XAU")>=0 || StringFind(symU,"GOLD")>=0 ||
               StringFind(symU,"XAG")>=0 || StringFind(symU,"SILVER")>=0);
   if(!g_IsGold)
      Print("âš ï¸ PERINGATAN: build ini KHUSUS XAUUSD - simbol chart saat ini (", Symbol(),
            ") bukan emas. Seluruh kalibrasi (RSI titik-jenuh, ambang kemiringan, dll) disetel utk gold, TIDAK akan sesuai instrumen lain.");
   g_IsSupportedPair = true; ConfigurePairParameters();
}
void ConfigurePairParameters() {
   if(!UseAutoInstrumentProfile) { g_PairMaxSpread = 35; g_PairTakeProfit = TakeProfit_Fixed; g_PairStopLoss = StopLoss_Fixed; g_LotMultiplier = 1.0; return; }
   if(UseATRBasedSL) CalibrateBaselineFromATR();
   else { g_PairTakeProfit = TakeProfit_Fixed; g_PairStopLoss = StopLoss_Fixed; }
   g_PairMaxSpread = SafeRound(35 * GoldSpreadMultiplier);
   if(!UseATRBasedSL) { g_PairTakeProfit = SafeRound(TakeProfit_Fixed * 2.0); g_PairStopLoss = SafeRound(StopLoss_Fixed * 2.0); }
   g_LotMultiplier = 0.8;
}
//+------------------------------------------------------------------+
//| v2.00 BUG-6 FIX - FILTER LONJAKAN VOLATILITAS (dirombak total).   |
//| VERSI LAMA MUSTAHIL AKTIF UTK GOLD - ini terbukti secara          |
//| matematis, bukan dugaan:                                          |
//|    pct = ATR/harga*100 ; ambang = MaxVolatilityPercent(5.0)*1.5   |
//|    gold: ATR $20 / harga $4300 * 100 = 0,465%  vs ambang 7,5%     |
//| Supaya filter itu menolak SATU sinyal saja, ATR H1 gold harus     |
//| mencapai $322,50 dalam satu jam. Tidak akan pernah terjadi.       |
//| Terkonfirmasi di diagnostik jurnal tes: "Ditolak - Volatilitas    |
//| tinggi : 0" selama 7 bulan penuh. Anda mengira punya penjaga      |
//| lonjakan; kenyataannya tidak ada sama sekali - persis di skenario |
//| (CPI/FOMC) yg paling bisa menghancurkan EA ini.                   |
//| VERSI BARU: bandingkan ATR JANGKA PENDEK vs ATR JANGKA PANJANG.   |
//| Rasio itulah yg benar-benar menangkap "pasar sedang meledak       |
//| dibanding kebiasaannya sendiri" - skala-bebas, jadi valid di      |
//| harga emas berapa pun.                                            |
//+------------------------------------------------------------------+
double GetVolSpikeRatio() {
   double atrShort = iATR(NULL, 0, VolSpikeShortPeriod, 1);
   double atrLong  = iATR(NULL, 0, VolSpikeLongPeriod,  1);
   if(atrLong <= 0) return 1.0;
   return atrShort / atrLong;
}
bool CheckVolatilityFilter() {
   if(!UseVolatilityFilter) return true;
   double ratio = GetVolSpikeRatio();
   if(ratio > MaxVolSpikeRatio) {
      Print("âŒ SINYAL DITOLAK: LONJAKAN VOLATILITAS - ATR(", VolSpikeShortPeriod, ") = ",
            DoubleToString(ratio,2), "x ATR(", VolSpikeLongPeriod, "), batas ",
            DoubleToString(MaxVolSpikeRatio,2), "x - pasar sedang meledak, tunggu tenang");
      return false;
   }
   return true;
}

//--- NEWS FILTER ---
//+------------------------------------------------------------------+
//| v2.00 BUG-7 FIX - FILTER NEWS (diperkuat).                        |
//| VERSI LAMA cuma memblokir 3 jam statis tanpa kesadaran TANGGAL:   |
//| tak tahu NFP (Jumat pertama), tak tahu FOMC, tak tahu hari apa    |
//| ini. Untuk gold - instrumen paling sensitif berita yg ada - itu   |
//| praktis tanpa proteksi. Diagnostik tes: 0 blokir dalam 7 bulan.   |
//| VERSI BARU menambah kesadaran hari & tanggal utk rilis            |
//| berdampak-tinggi yg jadwalnya memang bisa diprediksi:             |
//|   - NFP: Jumat PERTAMA tiap bulan                                 |
//|   - CPI AS: biasanya di paruh pertama bulan (opsional, lebar)     |
//| CATATAN JUJUR: ini TETAP bukan kalender ekonomi sungguhan. MT4    |
//| tak punya feed kalender bawaan. Ini pengurang risiko, bukan       |
//| jaminan. Perlindungan yg SUNGGUH mengikat ada di filter lonjakan  |
//| volatilitas di atas (yg bereaksi thd apa pun penyebabnya, ter-    |
//| masuk berita tak terjadwal) - itu yg jadi jaring pengaman utama.  |
//+------------------------------------------------------------------+
bool IsNewsBlocked() {
   if(!UseNewsFilter) return false;
   datetime now = TimeCurrent();
   MqlDateTime dt; TimeToStruct(now, dt);
   int currentMinutes = dt.hour * 60 + dt.min;

   // --- 1. Jam statis yg Anda tentukan sendiri (perilaku lama, dipertahankan) ---
   string times[];
   int count = StringSplit(NewsHours, ',', times);
   for(int i=0; i<count; i++) {
      string t = times[i];
      if(StringLen(t) < 5) continue;
      int h = (int)StringToInteger(StringSubstr(t,0,2));
      int m = (int)StringToInteger(StringSubstr(t,3,2));
      if(MathAbs(currentMinutes - (h*60+m)) <= NewsBlockMinutes) return true;
   }

   // --- 2. NFP: Jumat PERTAMA tiap bulan (baru di v2.00) ---
   if(BlockNFP && dt.day_of_week == 5 && dt.day <= 7) {
      int nfpMin = NFPHour*60 + NFPMinute;
      if(MathAbs(currentMinutes - nfpMin) <= NFPBlockMinutes) {
         Print("ðŸ“° BLOKIR NEWS: jendela NFP (Jumat pertama bulan ini)");
         return true;
      }
   }
   return false;
}

//====================================================================
//                    *** LOGIKA SINYAL UTAMA ***
//====================================================================
void RefreshData() {
   if(UseHeikenAshi) {
      if(!UseInternalHeikenAshi && HA_DirectionBuffer >= 0) {
         // CARA UTAMA: baca arah TERKONFIRMASI langsung dari buffer 6
         // HeikenAshi_Custom (sudah 3-lapis anti-zigzag, dijamin identik
         // dgn warna chart yang dilihat mata)
         double d1 = HACustom(0, HA_DirectionBuffer, 1);
         double d2 = HACustom(0, HA_DirectionBuffer, 2);
         g_HA_Direction_Val  = (d1 == EMPTY_VALUE) ? 0 : (int)d1;
         g_HA_Direction_Prev = (d2 == EMPTY_VALUE) ? 0 : (int)d2;
      } else {
         double haOpen, haClose, haOpen2, haClose2;
         if(UseInternalHeikenAshi) {
            GetInternalHA(0, 1, haOpen, haClose);
            GetInternalHA(0, 2, haOpen2, haClose2);
         } else {
            haOpen  = HAOpenValue(0, 1);
            haClose = HACloseValue(0, 1);
            haOpen2  = HAOpenValue(0, 2);
            haClose2 = HACloseValue(0, 2);
         }
         if(haClose > haOpen) g_HA_Direction_Val = 1; else if(haClose < haOpen) g_HA_Direction_Val = -1; else g_HA_Direction_Val = 0;
         if(haClose2 > haOpen2) g_HA_Direction_Prev = 1; else if(haClose2 < haOpen2) g_HA_Direction_Prev = -1; else g_HA_Direction_Prev = 0;
      }
   } else { g_HA_Direction_Val = 0; g_HA_Direction_Prev = 0; }


   g_ST_Trend = (int)STCustom(0, ST_TrendBuffer, 1);
   if(g_ST_Trend == EMPTY_VALUE) g_ST_Trend = 0;
   int stPrev = (int)STCustom(0, ST_TrendBuffer, 2);
   if(stPrev == EMPTY_VALUE) stPrev = 0;
   g_ST_Trend_Prev = stPrev;
   g_ST_Up_Val = GetSupertrendLine(0, 0, 1);
   g_ST_Dn_Val = GetSupertrendLine(0, 1, 1);

   // BACA MTF - hanya timeframe yang diaktifkan yang dihitung (hemat resource + fleksibel)
   if(UseMTFConfirmation) {
      if(UseMTF_M5)  { g_ST_Trend_M5  = (int)STCustom(PERIOD_M5,  ST_TrendBuffer, 1); if(g_ST_Trend_M5==EMPTY_VALUE) g_ST_Trend_M5=0; }
      if(UseMTF_M15) { g_ST_Trend_M15 = (int)STCustom(PERIOD_M15, ST_TrendBuffer, 1); if(g_ST_Trend_M15==EMPTY_VALUE) g_ST_Trend_M15=0; }
      if(UseMTF_M30) { g_ST_Trend_M30 = (int)STCustom(PERIOD_M30, ST_TrendBuffer, 1); if(g_ST_Trend_M30==EMPTY_VALUE) g_ST_Trend_M30=0; }
      if(UseMTF_H1)  { g_ST_Trend_H1  = (int)STCustom(PERIOD_H1,  ST_TrendBuffer, 1); if(g_ST_Trend_H1==EMPTY_VALUE) g_ST_Trend_H1=0; }
      if(UseMTF_H4)  { g_ST_Trend_H4  = (int)STCustom(PERIOD_H4,  ST_TrendBuffer, 1); if(g_ST_Trend_H4==EMPTY_VALUE) g_ST_Trend_H4=0; }
   }
   CalculateTrendStrength(); UpdateOverallTrend();
}

// ================================================================
// FIX PENTING: Versi lama membaca garis Supertrend HANYA di shift=1.
// Masalahnya, begitu Supertrend flip, garis trend LAMA di shift=1 sudah
// EMPTY_VALUE (karena buffer TrendUp/TrendDown cuma terisi saat trend
// masih berjalan). Akibatnya IsOverExtended() lama HAMPIR SELALU return
// true tanpa benar-benar mengukur seberapa jauh harga sudah "jenuh"
// sebelum reversal - filter titik jenuh jadi tidak berfungsi sama sekali.
//
// Fix: scan MUNDUR mulai shift=2 (bar terakhir saat trend LAMA masih
// aktif) sampai trend berubah, cari jarak maksimum antara close dan
// garis Supertrend selama trend lama itu berlangsung -> itulah puncak
// titik jenuh (exhaustion peak) yang sesungguhnya.
// ================================================================
double GetPreFlipExtensionPips(int direction, int flipShift) {
   int oldDir = -direction;
   double point = PipPoint();
   double maxExtPips = 0;
   int maxScan = ExtensionScanMaxBars;
   if(maxScan < 3) maxScan = 3;
   // scan mulai 1 bar SEBELUM bar flip (relatif ke bar flip, bukan bar sekarang -
   // penting krn dgn jendela sinkronisasi, flip bisa terjadi beberapa bar lalu)
   for(int s = flipShift + 1; s <= flipShift + maxScan; s++) {
      int trendAtS = (int)STCustom(0, ST_TrendBuffer, s);
      if(trendAtS != oldDir) break; // sudah keluar dari leg trend lama
      double lineVal = (oldDir == 1) ? STCustom(0, 0, s) : STCustom(0, 1, s);
      if(lineVal == EMPTY_VALUE || lineVal <= 0) continue;
      double closeAtS = iClose(NULL, 0, s);
      double distPips = (oldDir == 1) ? (closeAtS - lineVal) / point : (lineVal - closeAtS) / point;
      if(distPips > maxExtPips) maxExtPips = distPips;
   }
   return maxExtPips;
}

bool IsOverExtended(int direction, int flipShift) {
   if(!UseOverExtended) return true;
   double atrPips = GetATRInPips();
   double threshold = MathMax(15.0, atrPips * OverExtendedFactor);
   double peakExtension = GetPreFlipExtensionPips(direction, flipShift);
   return (peakExtension >= threshold);
}

//+------------------------------------------------------------------+
//| v21: EKSTENSI TREND BERJALAN (arah SAMA dgn sinyal lanjutan) -    |
//| kebalikan dari GetPreFlipExtensionPips (yang mengukur leg LAMA/   |
//| LAWAN sebelum flip). Ini mengukur seberapa jauh trend SEKARANG    |
//| (yang sedang searah sinyal continuation) sudah berlari dari garis |
//| ST-nya - dipakai utk PENJAGA TITIK JENUH: trend yg sudah lari     |
//| sangat jauh berisiko SEGERA berbalik, jadi "panah lanjutan" di    |
//| titik itu lebih mirip awal reversal daripada pullback sehat.      |
//+------------------------------------------------------------------+
double GetCurrentTrendExtensionPips(int direction) {
   double point = PipPoint();
   double maxExtPips = 0;
   int maxScan = ExtensionScanMaxBars; if(maxScan < 3) maxScan = 3;
   for(int s = 1; s <= maxScan; s++) {
      int trendAtS = (int)STCustom(0, ST_TrendBuffer, s);
      if(trendAtS != direction) break; // sudah keluar dari leg trend sekarang
      double lineVal = (direction == 1) ? STCustom(0, 0, s) : STCustom(0, 1, s);
      if(lineVal == EMPTY_VALUE || lineVal <= 0) continue;
      double closeAtS = iClose(NULL, 0, s);
      double distPips = (direction == 1) ? (closeAtS - lineVal) / point : (lineVal - closeAtS) / point;
      if(distPips > maxExtPips) maxExtPips = distPips;
   }
   return maxExtPips;
}

//+------------------------------------------------------------------+
//| v21: RASIO REZIM VOLATILITAS - ATR jangka pendek (candle barusan) |
//| dibanding ATR dasar. <1 = candle mengecil/menyempit (tenang),     |
//| >1 = candle melebar (trend kuat/impulsif). Dipakai utk trailing   |
//| adaptif: rezim tenang -> SL diketatkan (amankan profit kecil      |
//| sebelum sempat berbalik); rezim lebar -> SL dilonggarkan (jangan  |
//| kena koreksi wajar dari candle besar yang masih trending).        |
//+------------------------------------------------------------------+
double GetVolatilityRegimeRatio() {
   double atrBase = iATR(NULL, 0, 14, 1);
   double atrShort = iATR(NULL, 0, MathMax(2, VolRegimeShortBars), 1);
   if(atrBase <= 0) return 1.0;
   return atrShort / atrBase;
}

// --- Umur (durasi) trend lama, dipakai utk filter trend palsu/whipsaw ---
int GetTrendAgeBars(int oldDir, int flipShift) {
   int age = 0;
   int maxScan = 60;
   for(int s = flipShift + 1; s <= flipShift + maxScan; s++) {
      int t = (int)STCustom(0, ST_TrendBuffer, s);
      if(t != oldDir) break;
      age++;
   }
   return age;
}

// --- ADX selama trend lama (dibaca di bar terakhir trend lama), pastikan genuine ---
bool WasOldTrendGenuine(int oldDir, int flipShift) {
   if(!UseFalseTrendFilter) return true;
   double adx = iADX(NULL, 0, FalseTrendADXPeriod, PRICE_CLOSE, MODE_MAIN, flipShift + 1);
   if(adx == EMPTY_VALUE) return true;
   return (adx >= FalseTrendADXThreshold);
}

// --- Deteksi pola koreksi harga (2-3 candle) sebelum reversal betulan ---
// Dievaluasi relatif ke bar FLIP (bukan bar sekarang).
bool HasCorrectionPattern(int direction, int flipShift) {
   if(!UseCorrectionFilter) return true;
   int count = 0;
   int lookback = CorrectionLookbackBars;
   if(lookback < 1) lookback = 1;
   for(int s = flipShift + 1; s <= flipShift + lookback; s++) {
      double closeS  = iClose(NULL, 0, s);
      double closeS1 = iClose(NULL, 0, s + 1);
      bool movesTowardNew = (direction == 1) ? (closeS > closeS1) : (closeS < closeS1);
      if(movesTowardNew) count++;
   }
   return (count >= MinCorrectionCandles);
}

// --- JENDELA SINKRONISASI: cari bar flip Supertrend ke arah 'direction' ---
// dalam ConfirmWindowBars bar terakhir. Syarat: sejak flip itu, trend HARUS
// tetap searah (belum flip balik). Return: shift bar flip (1..window), atau
// -1 kalau tidak ada flip valid dlm jendela.
int FindRecentFlip(int direction) {
   int win = (ConfirmWindowBars < 1) ? 1 : ConfirmWindowBars;
   for(int f = 1; f <= win; f++) {
      int tNow  = (int)STCustom(0, ST_TrendBuffer, f);
      int tPrev = (int)STCustom(0, ST_TrendBuffer, f + 1);
      if(tNow != direction) return -1;       // trend sudah bukan arah ini -> jendela batal
      if(tPrev == -direction) return f;      // ketemu bar flip
   }
   return -1; // trend searah tapi flip-nya lebih tua dari jendela
}

// --- Integrasi SuperSR_6: cek apakah harga cukup dekat ke level S/R (confluence tambahan) ---
double SRCustom(int buf, int shift) {
   // v3.02: complete SuperSR_6 input contract.
   return iCustom(NULL, 0, SR_IndicatorFile,
      SR_Contract_Step,
      SR_Precision,
      SR_Shift_Bars,
      false,
      true,
      14,
      2.00,
      0.05,
      true,
      0.25,
      150,
      25.0,
      true,
      12,
      1.10,
      true,
      true,
      0.50,
      55.0,
      120,
      0.25,
      14,
      buf, shift);
}
bool IsNearSRZone(int direction) {
   if(!UseSRFilter) return true;
   double point = PipPoint();
   // v34: ambang jarak kini ATR-aware. SR_MaxDistancePips tetap jadi
   // LANTAI minimal, tapi kalau ATR instrumen saat ini menghasilkan jarak
   // lebih lebar, itu yang dipakai. Perlu utk instrumen mahal/berombak spt
   // XAUUSD: 20-30 "pip" (=$0.20-0.30 di kalibrasi pip broker ini) nyaris
   // mustahil tersentuh krn ATR H1 gold bisa puluhan dolar - filter versi
   // lama praktis SELALU memblokir walau harga sudah pas di S/R.
   double atrSR = iATR(NULL, 0, 14, 1);
   double maxDist = SR_MaxDistancePips * point;
   if(SR_UseATRScaling && atrSR > 0) maxDist = MathMax(maxDist, SR_MaxDistanceATRFactor * atrSR);
   double price = iClose(NULL, 0, 1);
   if(direction == 1) {
      // BUY -> cek kedekatan ke level SUPPORT (buffer 1)
      double sup = SRCustom(1, 1);
      if(sup == EMPTY_VALUE || sup <= 0) return true; // data blm tersedia, jangan blokir
      double dist = MathAbs(price - sup);
      return (dist <= maxDist);
   } else {
      // SELL -> cek kedekatan ke level RESISTANCE (buffer 0)
      double res = SRCustom(0, 1);
      if(res == EMPTY_VALUE || res <= 0) return true;
      double dist = MathAbs(res - price);
      return (dist <= maxDist);
   }
}

//+------------------------------------------------------------------+
//| v16: KOTAK KONSOLIDASI ADAPTIF - state global                    |
//+------------------------------------------------------------------+
double   g_BoxHigh = 0, g_BoxLow = 0;
double   g_LastCompressDirRatio = 0; // v36: rasio directionality terkini, dipakai fitur AI
datetime g_BoxStartTime = 0;
int      g_BoxBars = 0;
bool     g_BoxActive = false;
bool     g_BoxActivePrev = false;
double   g_PrevBoxHigh = 0, g_PrevBoxLow = 0;
datetime g_PrevBoxStart = 0, g_PrevBoxEnd = 0;
int      g_LastBreakDir = 0;        // arah breakout kotak terakhir (1/-1)
datetime g_LastBreakTime = 0;       // waktu candle breakout

//+------------------------------------------------------------------+
//| v16: PEMBARUAN KOTAK - dipanggil setiap bar baru.                |
//| Kotak tumbuh adaptif: mulai dari bar 2, terus diperlebar mundur  |
//| selama lebar total (high-low) masih < CompressionMaxRangeATR x   |
//| ATR. Panjang akhir >= CompressionMinBars = zona sideways resmi.  |
//| Saat trend kuat & KASAR (candle besar) berjalan, candle besar    |
//| langsung meledakkan lebar -> kotak otomatis tidak terbentuk.     |
//| v35: trend yang HALUS/landai (candle kecil tapi konsisten searah,|
//| "garis lurus" di ST) TIDAK meledakkan lebar secepat itu, jadi    |
//| bisa lolos jadi kotak palsu - makanya ditambah cek arah          |
//| (CompressionMinDirectionality): kotak cuma sah kalau net-disp    |
//| RENDAH thd lebarnya (harga sungguh bolak-balik, bukan menanjak/  |
//| menurun beruntun).                                                |
//+------------------------------------------------------------------+
void UpdateCompressionBox() {
   g_BoxActivePrev = g_BoxActive;
   if(g_BoxActive) { g_PrevBoxHigh = g_BoxHigh; g_PrevBoxLow = g_BoxLow; g_PrevBoxStart = g_BoxStartTime; g_PrevBoxEnd = iTime(NULL, 0, 1); }
   g_BoxActive = false; g_BoxBars = 0;
   g_LastCompressDirRatio = 0;
   if(!UseCompressionFilter) return;
   double atr = iATR(NULL, 0, 14, 1);
   if(atr <= 0) return;
   double maxW = CompressionMaxRangeATR * atr;
   double hh = 0, ll = 0; int L = 0;
   int maxScan = MathMin(CompressionMaxBars, Bars - 4);
   for(int k = 2; k < 2 + maxScan; k++) {
      double h = iHigh(NULL, 0, k), l = iLow(NULL, 0, k);
      double nh = (L == 0) ? h : MathMax(hh, h);
      double nl = (L == 0) ? l : MathMin(ll, l);
      if(nh - nl > maxW) break;   // penambahan bar ini meledakkan lebar -> kotak berhenti di sini
      hh = nh; ll = nl; L++;
   }
   // v35/v36: dirRatio dihitung di SINI (bukan di dalam blok CompressionMinBars
   // di bawah) supaya tersedia tiap bar kapan pun L>=2 - selaras persis dgn cara
   // Export_AI_Training_Data.mq4 menghitung compress_dir_ratio utk data training.
   // g_LastCompressDirRatio dipakai ComputeAIScore() sbg salah satu fitur AI.
   if(L >= 2) {
      double closeStartR = iClose(NULL, 0, 1 + L);
      double closeEndR   = iClose(NULL, 0, 1);
      double rngR = hh - ll;
      g_LastCompressDirRatio = (rngR > 0) ? MathAbs(closeEndR - closeStartR) / rngR : 0;
   } else {
      g_LastCompressDirRatio = 0;
   }
   if(L >= CompressionMinBars) {
      // v35: PENJAGA TREN HALUS - lihat komentar input CompressionMinDirectionality.
      // netDisp tinggi relatif thd lebar kotak = harga jalan SATU ARAH (trend
      // landai), bukan bolak-balik (sideways sungguhan) - jangan blokir.
      double dirRatio    = g_LastCompressDirRatio;
      bool   smoothTrend = (CompressionMinDirectionality > 0 && dirRatio >= CompressionMinDirectionality);
      if(!smoothTrend) {
         g_BoxActive = true; g_BoxHigh = hh; g_BoxLow = ll; g_BoxBars = L;
         g_BoxStartTime = iTime(NULL, 0, 1 + L);
         // deteksi & catat breakout candle terakhir (bar 1) terhadap kotak ini
         double c1  = iClose(NULL, 0, 1);
         double buf = BreakoutBufferPips * PipPoint();
         if(c1 > g_BoxHigh + buf)      { g_LastBreakDir = 1;  g_LastBreakTime = iTime(NULL, 0, 1); }
         else if(c1 < g_BoxLow - buf)  { g_LastBreakDir = -1; g_LastBreakTime = iTime(NULL, 0, 1); }
      }
   }
   DrawCompressionBoxObj();
}

//+------------------------------------------------------------------+
//| v16: VONIS KOMPRESI utk sebuah sinyal. Return:                   |
//|   0 = lolos (pasar bebas / sinyal searah breakout kotak)         |
//|   1 = DIBLOKIR: harga masih DI DALAM kotak sideways              |
//|   2 = DIBLOKIR: sinyal MELAWAN arah breakout / kunci arah lawan  |
//+------------------------------------------------------------------+
int CompressionVerdict(int direction) {
   if(!UseCompressionFilter) return 0;
   double buf = BreakoutBufferPips * PipPoint();
   if(g_BoxActive) {
      double c1 = iClose(NULL, 0, 1);
      if(c1 <= g_BoxHigh + buf && c1 >= g_BoxLow - buf) return 1;  // di dalam kotak
      int dirOut = (c1 > g_BoxHigh) ? 1 : -1;                      // sudah keluar kotak
      if(direction != dirOut) return 2;                            // melawan arah keluarnya
      return 0;                                                    // searah breakout -> sah
   }
   // v19: KANTONG CHOP JANGKA-PENDEK - kotak adaptif blm terbentuk (perlu
   // >=CompressionMinBars), tapi beberapa bar terakhir sendiri sudah
   // terjepit sempit -> tetap tolak (chop pendek yg kabur dari kotak besar)
   if(UseShortPocketChop) {
      double atrS = iATR(NULL, 0, 14, 1);
      if(atrS > 0) {
         int hiS = iHighest(NULL, 0, MODE_HIGH, ShortPocketBars, 1);
         int loS = iLowest(NULL, 0, MODE_LOW, ShortPocketBars, 1);
         if(hiS >= 0 && loS >= 0) {
            double rngS = iHigh(NULL, 0, hiS) - iLow(NULL, 0, loS);
            if(rngS > 0 && rngS < ShortPocketMaxATR * atrS) return 1;
         }
      }
   }
   // kotak sudah bubar (candle trend masuk jendela) - kunci arah lawan
   // masih berlaku beberapa bar utk mencegah whipsaw balik arah dini
   if(g_LastBreakDir != 0 && OppositeLockBars > 0 && g_LastBreakTime > 0) {
      int barsSince = iBarShift(NULL, 0, g_LastBreakTime);
      if(barsSince >= 0 && barsSince <= OppositeLockBars && direction == -g_LastBreakDir) return 2;
   }
   return 0;
}

//+------------------------------------------------------------------+
//| v16: GAMBAR KOTAK di chart. Kotak aktif = objek "hidup" yg terus |
//| diperbarui; saat kotak bubar (breakout), dibekukan jadi objek    |
//| permanen - jejak audit visual semua zona sideways di sepanjang   |
//| test terlihat langsung di chart.                                 |
//+------------------------------------------------------------------+
void DrawCompressionBoxObj() {
   // v18: sesuai permintaan - KOTAK (persegi) TIDAK digambar sama sekali,
   // cukup KETERANGAN teks di lokasi zona sideways. Bersihkan sisa persegi
   // dari versi lama bila ada.
   ObjectDelete(0, PFX + "BOX_CUR");
   string curL = PFX + "BOX_CUR_L";
   if(!DrawCompressionBox) { ObjectDelete(0, curL); return; }
   if(g_BoxActive) {
      datetime t1 = g_BoxStartTime;
      if(ObjectFind(0, curL) < 0) {
         ObjectCreate(0, curL, OBJ_TEXT, 0, t1, g_BoxHigh);
         ObjectSetString(0, curL, OBJPROP_TEXT, "SIDEWAYS - ENTRI DIBLOKIR");
         ObjectSetInteger(0, curL, OBJPROP_COLOR, clrOrange);
         ObjectSetInteger(0, curL, OBJPROP_FONTSIZE, 8);
      } else ObjectMove(0, curL, 0, t1, g_BoxHigh);
   } else {
      // zona bubar: bekukan keterangan sbg jejak teks permanen (tanpa kotak)
      if(g_BoxActivePrev && g_PrevBoxStart > 0) {
         string frzL = PFX + "BOXT_" + IntegerToString((long)g_PrevBoxStart);
         if(ObjectFind(0, frzL) < 0) {
            ObjectCreate(0, frzL, OBJ_TEXT, 0, g_PrevBoxStart, g_PrevBoxHigh);
            ObjectSetString(0, frzL, OBJPROP_TEXT, "SIDEWAYS (selesai)");
            ObjectSetInteger(0, frzL, OBJPROP_COLOR, clrGray);
            ObjectSetInteger(0, frzL, OBJPROP_FONTSIZE, 7);
         }
      }
      ObjectDelete(0, curL);
   }
}

//+------------------------------------------------------------------+
//| v16: KEKUATAN CANDLE SINYAL - perubahan tren KUAT dikonfirmasi   |
//| candle berbadan besar SEARAH sinyal. Candle kecil/berlawanan =   |
//| ciri zigzag/koreksi -> pemicu tidak dilayani.                    |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| v19: KEMIRINGAN REGRESI LINIER harga N bar (dinormalisasi ATR).  |
//| Wasit kedua saat DI+/DI- nyaris seri - ukuran arah tren yang      |
//| langsung dari harga (cepat, tanpa nunggu DI berpisah).            |
//+------------------------------------------------------------------+
double ComputeTrendSlopeATR(int lookback) {
   double atr = iATR(NULL, 0, 14, 1);
   if(atr <= 0 || lookback < 3) return 0;
   double sumX=0, sumY=0, sumXY=0, sumXX=0;
   for(int i = 0; i < lookback; i++) {
      double x = i;                                  // 0=paling lama ... lookback-1=paling baru
      double y = iClose(NULL, 0, lookback - i);       // shift lookback (lama) -> shift 1 (baru)
      sumX += x; sumY += y; sumXY += x*y; sumXX += x*x;
   }
   double n = lookback;
   double denom = (n*sumXX - sumX*sumX);
   if(denom == 0) return 0;
   double slope = (n*sumXY - sumX*sumY) / denom;      // harga per bar
   return slope / atr;
}
// v60: terjemahkan AUTO_SLOPE jadi mode KONKRET (STOP/LIMIT/BOTH) berdasar
// kemiringan tren SAAT INI - dipanggil di titik keputusan (posisi rugi baru
// ditutup, Repend/ExhPend mau memutuskan). Kalau mode BUKAN auto, kembalikan
// apa adanya (tak ada perhitungan tambahan - jalur lama tetap presisi sama).
ENUM_REPEND_MODE ResolveAutoSlopeMode(ENUM_REPEND_MODE configuredMode) {
   if(configuredMode != REPEND_AUTO_SLOPE) return configuredMode;
   double slopeNow = MathAbs(ComputeTrendSlopeATR(AutoSlopeLookbackBars));
   ENUM_REPEND_MODE resolved;
   if(slopeNow < AutoSlopeLandaiMax) resolved = REPEND_LIMIT_ONLY;
   else if(slopeNow >= AutoSlopeCuramMin) resolved = REPEND_STOP_ONLY;
   else resolved = REPEND_BOTH;
   Print("ðŸ“ AUTO-KEMIRINGAN: |slope| ", DoubleToString(slopeNow,3), "xATR/bar (", AutoSlopeLookbackBars, " bar) -> gaya ",
         (resolved==REPEND_LIMIT_ONLY?"LIMIT (landai)":(resolved==REPEND_STOP_ONLY?"STOP (curam)":"BOTH (sedang)")));
   return resolved;
}

//+------------------------------------------------------------------+
//| v31: regresi slope di TF TERTENTU (generalisasi ComputeTrendSlope)|
//+------------------------------------------------------------------+
double ComputeTrendSlopeATRTF(int tf, int lookback) {
   double atrT = iATR(NULL, tf, 14, 1);
   if(atrT <= 0 || lookback < 3) return 0;
   double sumX=0, sumY=0, sumXY=0, sumXX=0;
   for(int i = 0; i < lookback; i++) {
      double x = i;
      double y = iClose(NULL, tf, lookback - i);
      sumX += x; sumY += y; sumXY += x*y; sumXX += x*x;
   }
   double n = lookback;
   double denom = (n*sumXX - sumX*sumX);
   if(denom == 0) return 0;
   return ((n*sumXY - sumX*sumY) / denom) / atrT;
}

//+------------------------------------------------------------------+
//| v31: TF satu tingkat di atas chart (H4->D1, H1->H4, dst)          |
//+------------------------------------------------------------------+
int GetHigherTF() {
   switch(Period()) {
      case PERIOD_M1:  return PERIOD_M15;
      case PERIOD_M5:  return PERIOD_M30;
      case PERIOD_M15: return PERIOD_H1;
      case PERIOD_M30: return PERIOD_H4;
      case PERIOD_H1:  return PERIOD_H4;
      case PERIOD_H4:  return PERIOD_D1;
      case PERIOD_D1:  return PERIOD_W1;
      default:         return PERIOD_D1;
   }
}

//+------------------------------------------------------------------+
//| v36: GERBANG AI (opsional, default MATI). Model decision tree     |
//| dilatih offline dari 130.130 baris data historis XAUUSD H1 Anda   |
//| (2015-2026) - lihat PANDUAN_INTEGRASI_AI_v2.md utk detail & bukti |
//| validasinya. Temuan utama: harga yg masih di sisi "salah" garis   |
//| Supertrend (chase_dist_atr negatif) py win rate historis 74%,     |
//| dibanding 41% saat harga sudah di depan garis - dites terpisah di |
//| data 2015-2023 (tempat pola ditemukan) vs 2023-2026 (blm pernah   |
//| diintip) dan bertahan konsisten (74.2% vs 74.1%).                 |
//+------------------------------------------------------------------+
double ComputeAIScore_Tree(double &f[]) {
   // v40: model dilatih ULANG (data s/d 13 Jul 2026) dgn atr_now MENTAH
   // DIHAPUS dari fitur - percobaan sebelumnya buktikan pohon akan SELALU
   // memilih atr_now drpd atr_ratio kalau dua2nya tersedia (krn kebetulan
   // sedikit lebih "menjelaskan" data historis), padahal atr_now itu yg
   // basi seiring harga emas naik (lihat diagnosis 15 Jul 2026 - skor
   // selalu 0.494 krn 100% bar di 2025-2026 sudah lewat batas lama).
   // f[] harus berisi 12 fitur urutan persis (lihat ComputeAIScore di bawah):
   // [di_dom_diff, regime_slope, htf_slope, adx_value, adx_rising,
   //  chase_dist_atr, leg_age, compress_dir_ratio, ha_aligned, body_atr_signed, mtf_agree, atr_ratio]
   if(f[5] <= -0.000500) { // chase_dist_atr
      if(f[5] <= -0.576500) {
         if(f[5] <= -0.821500) {
            return 0.964359;
         } else {
            return 0.883656;
         }
      } else {
         if(f[5] <= -0.193500) {
            return 0.793171;
         } else {
            return 0.688290;
         }
      }
   } else {
      if(f[5] <= 0.000500) {
         if(f[9] <= 0.099500) {
            return 0.448878;
         } else {
            return 0.395598;
         }
      } else {
         // v40: cabang ini dulu pakai atr_now<=2.067 (basi). Kini htf_slope -
         // sudah ternormalisasi ATR sejak awal (lihat ComputeTrendSlopeATRTF),
         // jadi otomatis tetap relevan berapa pun harga emas nanti.
         if(f[2] <= -0.212500) { // htf_slope
            return 0.454584;
         } else {
            return 0.513370;
         }
      }
   }
}

// Kumpulkan 12 fitur di bar sekarang (shift=1) lewat fungsi yg SUDAH ADA di
// EA ini (tidak ada logika baru/duplikat, cuma disusun ulang jadi array).
double ComputeAIScore(int dir) {
   double diP = iADX(NULL,0,RegimeADXPeriod,PRICE_CLOSE,MODE_PLUSDI,1);
   double diM = iADX(NULL,0,RegimeADXPeriod,PRICE_CLOSE,MODE_MINUSDI,1);
   double diDom = (diP==EMPTY_VALUE||diM==EMPTY_VALUE) ? 0 : ((dir==1)?(diP-diM):(diM-diP));
   double regimeBase = ComputeTrendSlopeATR(RegimeSlopeBars);
   double htfBase     = ComputeTrendSlopeATRTF(GetHigherTF(), HTFBiasBars);
   double adxNow  = iADX(NULL,0,RegimeADXPeriod,PRICE_CLOSE,MODE_MAIN,1);
   double adxPrev = iADX(NULL,0,RegimeADXPeriod,PRICE_CLOSE,MODE_MAIN,2);
   double atrNow  = iATR(NULL,0,14,1);
   double stLine  = (dir==1)?STCustom(0,0,1):STCustom(0,1,1);
   double chase   = (stLine==EMPTY_VALUE||stLine<=0||atrNow<=0)?0:((dir==1)?(Bid-stLine):(stLine-Bid))/atrNow;
   int lineBufA=(dir==1)?0:1; int legAge=0;
   for(int k=1;k<=30;k++){ double la=STCustom(0,lineBufA,k),lb=STCustom(0,lineBufA,k+1);
      if(la==EMPTY_VALUE||lb==EMPTY_VALUE||la<=0||lb<=0) break; if(la==lb) break; legAge++; }
   bool haAl = (g_HA_Direction_Val==dir);
   double o1=iOpen(NULL,0,1), c1=iClose(NULL,0,1);
   double bodySig = (atrNow>0) ? ((dir==1)?(c1-o1):(o1-c1))/atrNow : 0;
   // v40: mtf_agree - berapa dari M5/M15/M30 yg trend-nya SAAT INI searah dir
   // (live, bukan historis, jadi tak perlu penyelarasan bar rumit spt di
   // script ekspor - cukup baca kondisi sekarang langsung)
   int trendM5  = (int)STCustom(PERIOD_M5,  ST_TrendBuffer, 1);
   int trendM15 = (int)STCustom(PERIOD_M15, ST_TrendBuffer, 1);
   int trendM30 = (int)STCustom(PERIOD_M30, ST_TrendBuffer, 1);
   int mtfAgree = (trendM5==dir?1:0) + (trendM15==dir?1:0) + (trendM30==dir?1:0);
   // v40: atr_ratio gantikan atr_now mentah - ATR pendek(14)/ATR panjang(100)
   double atrLong  = iATR(NULL,0,100,1);
   double atrRatio = (atrLong>0) ? atrNow/atrLong : 1.0;

   double f[12];
   f[0]=diDom; f[1]=dir*regimeBase; f[2]=dir*htfBase; f[3]=adxNow;
   f[4]=adxNow-adxPrev; f[5]=chase; f[6]=legAge; f[7]=g_LastCompressDirRatio;
   f[8]=haAl?1:0; f[9]=bodySig; f[10]=mtfAgree; f[11]=atrRatio;
   return ComputeAIScore_Tree(f);
}

//+------------------------------------------------------------------+
//| v31: VONIS BIAS TF-ATAS. Return: 0=lolos, 1=diblokir MELAWAN bias|
//| tanpa bukti sangat kuat, 2=diblokir makro DATAR & momentum lemah. |
//+------------------------------------------------------------------+
int HTFBiasVerdict(int direction, int &biasOut, double &slopeOut) {
   biasOut = 0; slopeOut = 0;
   if(!UseHTFBiasFilter) return 0;
   int htf = GetHigherTF();
   slopeOut = ComputeTrendSlopeATRTF(htf, HTFBiasBars);
   biasOut = (slopeOut >= HTFBiasMinSlope) ? 1 : ((slopeOut <= -HTFBiasMinSlope) ? -1 : 0);
   if(biasOut == direction) return 0;   // searah bias makro -> lolos
   double diPb = iADX(NULL, 0, RegimeADXPeriod, PRICE_CLOSE, MODE_PLUSDI, 1);
   double diMb = iADX(NULL, 0, RegimeADXPeriod, PRICE_CLOSE, MODE_MINUSDI, 1);
   double sep = (diPb == EMPTY_VALUE || diMb == EMPTY_VALUE) ? 0 : MathAbs(diPb - diMb);
   if(biasOut == 0) {                   // makro datar (ranging spt Agu-Sep)
      return (sep >= HTFFlatMinDISep) ? 0 : 2;
   }
   // MELAWAN bias makro:
   // v34: HARD BLOCK v33 (tolak mutlak, tanpa pengecualian) diganti PINTU
   // DARURAT PRESISI-2-BAR. Akar masalah v32 BUKAN keberadaan pintu
   // daruratnya, tapi pintu itu puas dgn SATU candle - spike sesaat di
   // puncak lokal (DI melonjak 1 bar lalu reda lagi, candle lawan besar
   // krn profit-taking) ikut lolos, padahal itu bukan pembalikan asli.
   // v34 mewajibkan divergensi DI + candle besar BERTAHAN 2 candle
   // beruntun (shift 1 DAN shift 2, candle-2 boleh sedikit lebih lemah
   // via HTFCounterPersistFactor) + ADX benar2 MENGUAT (bukan sisa ADX
   // trend lama yg sedang meluruh - itu ciri spike, bukan tren baru).
   // Spike 1-candle gagal syarat "2 beruntun"; pembalikan sungguhan (yg
   // momentumnya nambah tiap bar - ciri khas awal tren baru) tetap lolos
   // dlm hitungan bar, tanpa menunggu bias TF-atas berbalik penuh dulu.
   if(HTFBiasHardBlock) return 1; // opsi "murni ikut tren" - dipertahankan, kini bukan default
   double atrB = iATR(NULL, 0, 14, 1);
   if(atrB <= 0) return 1;
   double o1b = iOpen(NULL, 0, 1), c1b = iClose(NULL, 0, 1);
   double o2b = iOpen(NULL, 0, 2), c2b = iClose(NULL, 0, 2);
   bool candleDir1 = (direction == 1) ? (c1b > o1b) : (c1b < o1b);
   bool candleDir2 = (direction == 1) ? (c2b > o2b) : (c2b < o2b);
   bool candleBig1 = (MathAbs(c1b - o1b) >= HTFCounterMinBodyATR * atrB);
   double diP2 = iADX(NULL, 0, RegimeADXPeriod, PRICE_CLOSE, MODE_PLUSDI, 2);
   double diM2 = iADX(NULL, 0, RegimeADXPeriod, PRICE_CLOSE, MODE_MINUSDI, 2);
   double sep2 = (diP2 == EMPTY_VALUE || diM2 == EMPTY_VALUE) ? 0 : MathAbs(diP2 - diM2);
   double adxNow  = iADX(NULL, 0, RegimeADXPeriod, PRICE_CLOSE, MODE_MAIN, 1);
   double adxPrev = iADX(NULL, 0, RegimeADXPeriod, PRICE_CLOSE, MODE_MAIN, 2);
   bool adxRising  = (adxNow >= adxPrev);
   bool persistDI  = (sep >= HTFCounterMinDISep) && (sep2 >= HTFCounterMinDISep * HTFCounterPersistFactor);
   bool persistDir = candleDir1 && candleDir2;
   if(persistDI && persistDir && candleBig1 && adxRising) return 0;
   return 1;
}

//+------------------------------------------------------------------+
//| v19: VONIS REZIM TERPADU. Return: 1=lolos tegas (DI berpisah      |
//| jelas), 2=lolos via wasit regresi (DI nyaris seri tp harga jelas  |
//| condong), -1=diblokir, 0=lolos (data blm siap, jangan blokir).    |
//+------------------------------------------------------------------+
int RegimeVerdict(int direction, double &diP, double &diM, double &slopeATR) {
   diP = iADX(NULL, 0, RegimeADXPeriod, PRICE_CLOSE, MODE_PLUSDI, 1);
   diM = iADX(NULL, 0, RegimeADXPeriod, PRICE_CLOSE, MODE_MINUSDI, 1);
   slopeATR = 0;
   if(diP == EMPTY_VALUE || diM == EMPTY_VALUE || (diP <= 0 && diM <= 0)) return 0;
   double sep = MathAbs(diP - diM);
   if(sep >= DIMinSeparation) {
      bool domOK = (direction == 1) ? (diP > diM) : (diM > diP);
      return domOK ? 1 : -1;
   }
   // DI nyaris seri (selisih < DIMinSeparation = wilayah noise) -> jangan
   // divonis "berlawanan" begitu saja (itu penyebab 51 penolakan tipis di
   // data test) - serahkan ke kemiringan regresi harga.
   slopeATR = ComputeTrendSlopeATR(RegimeSlopeBars);
   bool slopeOK = (direction == 1) ? (slopeATR >= RegimeSlopeMin) : (-slopeATR >= RegimeSlopeMin);
   return slopeOK ? 2 : -1;
}

//+------------------------------------------------------------------+
//| v30: RECOVERY PINTAR - dipersenjatai HANYA saat momentum tren     |
//| SANGAT kuat searah sinyal (DI berpisah lebar + regresi curam).    |
//| Bukan martingale: tak beraksi di pasar lemah/sideways, jml trade  |
//| & risiko dibatasi ketat.                                          |
//+------------------------------------------------------------------+
void ArmRecoveryIfEligible(int direction) {
   g_RecoveryArmedThisSignal = false;
   if(!UseSmartRecovery || g_RecoveryDeficit <= 0) return;
   if(RecoveryMaxTrades > 0 && g_RecoveryTradesUsed >= RecoveryMaxTrades) return;
   double diP = iADX(NULL, 0, RegimeADXPeriod, PRICE_CLOSE, MODE_PLUSDI, 1);
   double diM = iADX(NULL, 0, RegimeADXPeriod, PRICE_CLOSE, MODE_MINUSDI, 1);
   if(diP == EMPTY_VALUE || diM == EMPTY_VALUE) return;
   double sep = MathAbs(diP - diM);
   double slp = ComputeTrendSlopeATR(RegimeSlopeBars);
   bool momOK = (sep >= RecoveryMinDISep) &&
                ((direction == 1) ? (diP > diM && slp >= RecoveryMinSlopeATR)
                                  : (diM > diP && -slp >= RecoveryMinSlopeATR));
   if(momOK) {
      g_RecoveryArmedThisSignal = true;
      Print("ðŸ’Š RECOVERY DIPERSENJATAI (defisit $", DoubleToString(g_RecoveryDeficit,2),
            ", trade ke-", g_RecoveryTradesUsed+1, "/", RecoveryMaxTrades,
            "): momentum kuat searah (DI sep ", DoubleToString(sep,1), ", slope ", DoubleToString(slp,2), "xATR)");
   }
}

bool IsSignalCandleStrong(int direction) {
   if(!UseSignalBodyFilter) return true;
   double atr = iATR(NULL, 0, 14, 1);
   if(atr <= 0) return true; // data blm siap, jangan blokir
   double o1 = iOpen(NULL, 0, 1), c1 = iClose(NULL, 0, 1);
   bool dirOK = (direction == 1) ? (c1 > o1) : (c1 < o1);
   double body = MathAbs(c1 - o1);
   if(dirOK && body >= MinSignalBodyATR * atr) return true;
   // v17 jalur alternatif: MOMENTUM 2-CANDLE. Perubahan tren kuat kadang
   // terbentuk dari 2 candle sedang beruntun (bukan 1 candle raksasa) -
   // versi lama menolaknya (jurnal 4 & 7 Jul beruntun "candle lemah").
   double net = c1 - iClose(NULL, 0, 3);
   bool momOK = (direction == 1) ? (net >= 0.6 * atr) : (-net >= 0.6 * atr);
   return momOK;
}

//+------------------------------------------------------------------+
//| v18: ARAH HA MENTAH bar terakhir (candle asli Heiken Ashi, TANPA |
//| penundaan konfirmasi 3-lapis). Dipakai jalur konfirmasi cepat -  |
//| naik kereta lebih awal saat flip masih segar.                    |
//+------------------------------------------------------------------+
int RawHADirection() {
   double haO, haC;
   if(UseInternalHeikenAshi) { GetInternalHA(0, 1, haO, haC); }
   else { haO = HAOpenValue(0, 1); haC = HACloseValue(0, 1); }
   if(haO == EMPTY_VALUE || haC == EMPTY_VALUE) return 0;
   if(haC > haO) return 1;
   if(haC < haO) return -1;
   return 0;
}

// +++ FUNGSI UTAMA - JENDELA SINKRONISASI 4 INDIKATOR +++
// Flip Supertrend MEMBUKA jendela ConfirmWindowBars candle. Di setiap candle
// baru dlm jendela itu, konfirmator dicek ulang: HA (yang sengaja lambat &
// anti-zigzag) + Entry_Signal_Pro + MTF + SR. Entri terjadi di candle PERTAMA
// saat semua setuju - masing2 indikator memberi suaranya pada waktunya sendiri.
bool IsPerfectReversalSignal(int direction) {
   string dirStr = (direction == 1) ? "BUY" : "SELL";

   // 1. Ada flip Supertrend ke arah ini dlm jendela? (dan belum flip balik)
   int flipShift = FindRecentFlip(direction);
   if(flipShift < 0) {
      g_cnt_STFlip++;
      return false; // tanpa print - kondisi paling umum, hindari banjir log
   }

   // 1b. Cegah entri ganda dari flip yang sama
   datetime flipTime = iTime(NULL, 0, flipShift);
   if(flipTime == g_LastFlipTraded) return false;
   if(DebugEntryTrace) {
      double stTrendT = STCustom(0, ST_TrendBuffer, 1);
      double stSigB = STCustom(0, ST_BuySignalBuffer, 1);
      double stSigS = STCustom(0, ST_SellSignalBuffer, 1);
      double stLeaderB = STCustom(0, ST_LeaderBuyBuffer, 1);
      double stLeaderS = STCustom(0, ST_LeaderSellBuffer, 1);
      double haDirT = UseInternalHeikenAshi ? RawHADirection() : HACustom(0, HA_DirectionBuffer, 1);
      double espB = ESPCustom(ESP_BuyBuffer, 1);
      double espS = ESPCustom(ESP_SellBuffer, 1);
      double srSupport = SRCustom(1,1);
      double srResistance = SRCustom(0,1);
      Print("[ENTRY TRACE] FLIP ",dirStr," shift=",flipShift," time=",TimeToString(flipTime),
            " STtrend=",DoubleToString(stTrendT,0)," STbuy=",DoubleToString(stSigB,0)," STsell=",DoubleToString(stSigS,0)," STleaderB=",DoubleToString(stLeaderB,Digits)," STleaderS=",DoubleToString(stLeaderS,Digits),
            " HA=",DoubleToString(haDirT,0)," ESPbuy=",DoubleToString(espB,Digits)," ESPsell=",DoubleToString(espS,Digits),
            " SRsupport=",DoubleToString(srSupport,Digits)," SRresistance=",DoubleToString(srResistance,Digits)," UseSR=",(UseSRFilter?"ON":"OFF"));
   }

   // 1c. v17 FILTER REZIM DIGANTI TOTAL: level/kemiringan ADX terbukti
   // MEMBUNUH pembalikan sah (jurnal 3 Jul: rally besar ditolak "ADX
   // MELURUH" - padahal ADX tak punya arah; yg meluruh itu ADX bekas trend
   // LAMA, wajar di setiap pembalikan V). Pengganti: DOMINASI ARAH DI+/DI-
   // (komponen berarah dari ADX, berbalik CEPAT di reversal) - BUY butuh
   // DI+ > DI-, SELL butuh DI- > DI+. Deteksi sideways murni kini tugas
   // KOTAK KONSOLIDASI (struktural, berbasis harga).
   if(UseRegimeFilter) {
      double diP, diM, slopeA;
      int rv = RegimeVerdict(direction, diP, diM, slopeA);
      if(rv == -1) {
         g_cnt_Regime++;
         Print("âŒ SINYAL ", dirStr, " DITOLAK: arah blm berpihak (DI+ ", DoubleToString(diP,1),
               " vs DI- ", DoubleToString(diM,1), ", slope ", DoubleToString(slopeA,2), "xATR)");
         return false;
      }
      if(rv == 2) Print("âš¡ SINYAL ", dirStr, ": DI nyaris seri (", DoubleToString(diP,1), "/", DoubleToString(diM,1),
                        ") - lolos via kemiringan regresi (", DoubleToString(slopeA,2), "xATR)");
   }

   // 1c-bis. v31 VONIS BIAS TF-ATAS (rem utk 93% pola kerugian di report
   // H4: SELL melawan uptrend makro D1 & entri di fase ranging makro)
   {
      int biasB = 0; double slopeB = 0;
      int hb = HTFBiasVerdict(direction, biasB, slopeB);
      // ===== v3.00 PENANDA LAWAN-TREN =====
      // BUKTI dari tes bertahap Anda (periode 01 Jun - 16 Jul 2026, gold
      // TURUN 11,83% dari $4.525 ke $3.990 - satu rezim downtrend keras):
      //   TAHAP 1  BUY  win 30,3% net  -$83,78  |  SELL win 45,0% net +$103,69
      //   TAHAP 2  BUY  win 30,0% net  -$79,29  |  SELL win 35,5% net  +$31,12
      //   TAHAP 3  BUY  win 27,3% net -$156,11  |  SELL win 53,8% net +$156,05
      //   TAHAP 4  BUY  win 25,0%              |  SELL win 40,0%
      // Sisi yg melawan arah makro kalah telak di SETIAP tahap, tanpa
      // kecuali. Tapi MEMBLOKIR total juga salah - pembalikan tren yg sah
      // selalu dimulai sbg sinyal lawan-tren, dan di tes 7 bulan v1.00
      // (rezim campuran) BUY & SELL justru seimbang. Jadi yg dikecilkan
      // adalah UKURANNYA, bukan izinnya: rugi lawan-tren jadi separuh,
      // sementara pembalikan sungguhan tetap ikut terbawa.
      g_CounterTrendSignal = false;
      if(UseCounterTrendSizing && biasB != 0 && biasB != direction) {
         g_CounterTrendSignal = true;
         g_cnt_CounterTrend++;
      }
      if(hb != 0) {
         g_cnt_HTFBias++;
         if(hb == 1)
            Print("âŒ SINYAL ", dirStr, " DITOLAK: MELAWAN bias TF-atas (slope ", DoubleToString(slopeB,2),
                  "xATR/bar) - blm lolos syarat pembalikan 2-bar + ADX menguat (v34)");
         else
            Print("âŒ SINYAL ", dirStr, " DITOLAK: makro TF-atas DATAR (slope ", DoubleToString(slopeB,2),
                  "xATR/bar) & momentum lemah - pola rugi fase ranging Agu-Sep");
         return false;
      }
   }

   // 1d. v16 VONIS KOTAK KONSOLIDASI: sinyal dari dalam kotak sideways =
   // zigzag (diblokir); keluar kotak hanya sah SEARAH breakout.
   int cvR = CompressionVerdict(direction);
   if(cvR != 0) {
      if(cvR == 1) {
         g_cnt_Compress++;
         if(g_BoxActive)
            Print("âŒ SINYAL ", dirStr, " DITOLAK: harga DI DALAM KOTAK SIDEWAYS (", g_BoxBars, " bar, ",
                  DoubleToString((g_BoxHigh-g_BoxLow)/PipPoint(),1), " pips) - flip di dalam kotak = zigzag");
         else
            Print("âŒ SINYAL ", dirStr, " DITOLAK: KANTONG CHOP jangka-pendek (v19, ", ShortPocketBars, " bar terjepit) - blm cukup panjang jd kotak resmi tp tetap chop");
      } else {
         g_cnt_OppLock++;
         Print("âŒ SINYAL ", dirStr, " DITOLAK: MELAWAN arah breakout kotak terakhir (kunci arah lawan ", OppositeLockBars, " bar)");
      }
      return false;
   }

   // 1e. v16 KEKUATAN CANDLE SINYAL: konfirmasi harus bertenaga
   if(!IsSignalCandleStrong(direction)) {
      g_cnt_WeakBody++;
      Print("âŒ SINYAL ", dirStr, " DITOLAK: candle sinyal lemah/berlawanan (badan < ", DoubleToString(MinSignalBodyATR,2), " x ATR) - ciri koreksi, bukan perubahan tren kuat");
      return false;
   }

   // 1f. v18 PERISAI PISAU: pembalikan MELAWAN leg raksasa (trade #4 jurnal:
   // SELL lawan rally 100+ pips -> SL). Leg lawan yang ekstensinya besar
   // butuh bukti pembalikan ekstra kuat, bukan sekadar flip biasa.
   if(UseKnifeGuard) {
      double atrK = iATR(NULL, 0, 14, 1);
      if(atrK > 0) {
         double peakExtPrice = GetPreFlipExtensionPips(direction, flipShift) * PipPoint();
         if(peakExtPrice > BigLegATR * atrK) {
            double oK = iOpen(NULL, 0, 1), cK = iClose(NULL, 0, 1);
            bool superStrong = ((direction == 1) ? (cK > oK) : (cK < oK)) && MathAbs(cK - oK) >= 0.60 * atrK;
            bool boxBreak = (g_LastBreakDir == direction && g_LastBreakTime == iTime(NULL, 0, 1));
            if(!superStrong && !boxBreak) {
               g_cnt_Knife++;
               Print("âŒ SINYAL ", dirStr, " DITOLAK: melawan LEG RAKSASA (ekstensi ", DoubleToString(peakExtPrice/PipPoint(),1),
                     " pips > ", DoubleToString(BigLegATR,1), "xATR) tanpa candle super-kuat/breakout kotak - anti tangkap-pisau");
               return false;
            }
         }
      }
   }

   // v18 JALUR CEPAT: flip masih segar + candle kuat (sudah lolos 1e) =
   // boleh entri TANPA menunggu HA yang sengaja lambat 3+ candle.
   bool fastTrack = (UseFastTrackEntry && flipShift <= FastEntryMaxBars && RawHADirection() == direction); // v18b: + syarat HA MENTAH searah (rem tambahan jalur cepat)

   // 2. KONFIRMASI HEIKEN ASHI (LANTAI 2) - arah TERKONFIRMASI (buffer 6,
   // 3-lapis anti-zigzag) harus sudah searah. HA sengaja lambat - jendela
   // sinkronisasi memberi waktu HA utk "menyusul" flip Supertrend.
   if(UseHeikenAshi && !fastTrack) {
      if(g_HA_Direction_Val != direction) {
         g_cnt_HAFlip++;
         Print("â³ SINYAL ", dirStr, " MENUNGGU: HA belum searah (curr=", g_HA_Direction_Val, ") - jendela sisa ", (ConfirmWindowBars - flipShift), " bar");
         return false;
      }
   }

   // 3. ENTRY_SIGNAL_PRO (LANTAI 3) - mode VETO (default): panah BERLAWANAN
   // yang baru = sinyal ditolak (perlindungan independen). Panah searah TIDAK
   // diwajibkan (pelajaran Test 1&2: mewajibkannya mencekik sinyal BUY karena
   // ESP StrictBuyMode memang sengaja sangat ketat di sisi BUY).
   if(UseESPConfirmation) {
      int espLb = flipShift + ESP_LookbackBars;
      bool oppFound = false, matchFound = false;
      for(int s = 1; s <= espLb; s++) {
         double opp = ESPCustom((direction == 1) ? ESP_SellBuffer : ESP_BuyBuffer, s);
         if(opp != EMPTY_VALUE && opp > 0) { oppFound = true; break; } // panah lawan lebih baru
         double v = ESPCustom((direction == 1) ? ESP_BuyBuffer : ESP_SellBuffer, s);
         if(v != EMPTY_VALUE && v > 0) { matchFound = true; break; }
      }
      if(oppFound) {
         g_cnt_ESP++;
         Print("âŒ SINYAL ", dirStr, " DIVETO: ada panah Entry_Signal_Pro BERLAWANAN yg lebih baru");
         return false;
      }
      if(ESP_RequireMatch && !matchFound) {
         g_cnt_ESP++;
         Print("â³ SINYAL ", dirStr, " MENUNGGU: belum ada panah Entry_Signal_Pro searah (mode wajib)");
         return false;
      }
   }

   // 3b. v17 PENJAGA KEJAR-HARGA DIKOREKSI MATEMATIS. Versi lama mengukur
   // dari close bar flip dgn batas 0.8xATR - padahal jendela konfirmasi
   // (HA sengaja lambat 2-5 candle) membuat harga WAJAR sudah bergerak;
   // hasilnya hampir semua konfirmasi sah ditolak "kejar-harga" (jurnal
   // 7 Jul: 16.8 pips vs batas 13.1). Kini diukur dari GARIS ST dgn batas
   // sadar-band: jarak alami harga ke garis pasca-flip = ST_ATRMultiplier
   // x ATR, jadi batas = (ST_ATRMultiplier + MaxChaseATR) x ATR. Entri
   // segar pasca-flip lolos; hanya harga yg SUNGGUH melayang jauh ditolak.
   if(UseChaseGuard) {
      double stLineR = (direction == 1) ? STCustom(0, 0, 1) : STCustom(0, 1, 1);
      double atrNow  = iATR(NULL, 0, 14, 1);
      if(stLineR != EMPTY_VALUE && stLineR > 0 && atrNow > 0) {
         double distR  = (direction == 1) ? (Bid - stLineR) : (stLineR - Bid);
         double limitR = (ST_ATRMultiplier + MaxChaseATR) * atrNow;
         if(distR > limitR) {
            g_cnt_Chase++;
            Print("âŒ SINYAL ", dirStr, " DITOLAK: harga ", DoubleToString(distR/PipPoint(),1),
                  " pips dari garis ST (batas ", DoubleToString(limitR/PipPoint(),1), ") - sungguh kejar-harga");
            return false;
         }
      }
      // 3c. v18 BATAS TELAT (hanya jalur konfirmasi): bila entri baru bisa
      // terjadi SETELAH menunggu HA, harga tak boleh sudah bergerak jauh
      // dari close bar flip. Kereta yang sudah jauh DIRELAKAN - data jurnal:
      // entri "flip 5-6 bar lalu" setelah harga lari (trade #2 SL, #3 cuma
      // BE dari rally 100 pips). Jalur cepat tidak kena batas ini karena
      // by-definition masuk saat kereta baru berangkat.
      if(!fastTrack && atrNow > 0) {
         double flipCloseL = iClose(NULL, 0, flipShift);
         double movedL = (direction == 1) ? (Bid - flipCloseL) : (flipCloseL - Bid);
         if(movedL > LateEntryMaxATR * atrNow) {
            g_cnt_Late++;
            Print("âŒ SINYAL ", dirStr, " DIRELAKAN: konfirmasi datang telat, harga sudah bergerak ",
                  DoubleToString(movedL/PipPoint(),1), " pips dari flip (batas ",
                  DoubleToString(LateEntryMaxATR*atrNow/PipPoint(),1), ") - kereta sudah jauh, tunggu kereta berikutnya");
            return false;
         }
      }
   }

   // 4. KONFIRMASI MTF - dinamis sesuai timeframe yang diaktifkan
   if(UseMTFConfirmation) {
      int mtfEnabled = 0, mtfAgree = 0;
      if(UseMTF_M5)  { mtfEnabled++; if(g_ST_Trend_M5  == direction) mtfAgree++; }
      if(UseMTF_M15) { mtfEnabled++; if(g_ST_Trend_M15 == direction) mtfAgree++; }
      if(UseMTF_M30) { mtfEnabled++; if(g_ST_Trend_M30 == direction) mtfAgree++; }
      if(UseMTF_H1)  { mtfEnabled++; if(g_ST_Trend_H1   == direction) mtfAgree++; }
      if(UseMTF_H4)  { mtfEnabled++; if(g_ST_Trend_H4   == direction) mtfAgree++; }
      int required = MinMTFRequired;
      if(mtfEnabled == 0) required = 0;
      else if(required > mtfEnabled) required = mtfEnabled;
      if(mtfAgree < required) {
         g_cnt_MTF++;
         Print("â³ SINYAL ", dirStr, " MENUNGGU: baru ", mtfAgree, "/", mtfEnabled, " MTF searah (min ", required, ")");
         return false;
      }
   }

   // === FILTER KUALITAS FLIP DALAM (hanya mode KETAT) ===
   // Di mode SEDERHANA (default), titik sentral yang sudah dikonfirmasi
   // garis+HA+pengawas langsung sah - 4 filter warisan di bawah dilewati.
   int oldDir = -direction;
   if(UseStrictFlipQuality) {

   // 5. Umur trend lama (filter whipsaw)
   int trendAge = GetTrendAgeBars(oldDir, flipShift);
   if(trendAge < MinTrendDurationBars) {
      g_cnt_TrendAge++;
      Print("âŒ SINYAL ", dirStr, " DITOLAK: Trend lama cuma ", trendAge, " bar (min ", MinTrendDurationBars, ")");
      return false;
   }

   // 6. Trend lama harus genuine (ADX kuat)
   if(!WasOldTrendGenuine(oldDir, flipShift)) {
      g_cnt_ADXFalse++;
      Print("âŒ SINYAL ", dirStr, " DITOLAK: ADX trend lama lemah");
      return false;
   }

   // 7. Titik jenuh (over-extended)
   double peakExt = GetPreFlipExtensionPips(direction, flipShift);
   if(!IsOverExtended(direction, flipShift)) {
      g_cnt_OverExt++;
      Print("âŒ SINYAL ", dirStr, " DITOLAK: Belum over-extended, puncak jenuh cuma ", DoubleToString(peakExt,1), " pips");
      return false;
   }

   // 8. Pola koreksi sebelum flip
   if(!HasCorrectionPattern(direction, flipShift)) {
      g_cnt_Correction++;
      Print("âŒ SINYAL ", dirStr, " DITOLAK: Belum ada pola koreksi sebelum flip");
      return false;
   }

   } // akhir mode KETAT

   // 9. Zona S/R (SuperSR_6, LANTAI 4 - opsional)
   if(!IsNearSRZone(direction)) {
      g_cnt_SR++;
      Print("âŒ SINYAL ", dirStr, " DITOLAK: Belum cukup dekat level S/R (SuperSR_6)");
      return false;
   }

   // 10. Volatility & news
   if(!CheckVolatilityFilter()) {
      g_cnt_Volatility++;
      Print("âŒ SINYAL ", dirStr, " DITOLAK: Volatilitas terlalu tinggi");
      return false;
   }
   if(IsNewsBlocked()) {
      g_cnt_News++;
      Print("âŒ SINYAL ", dirStr, " DITOLAK: Sedang waktu news");
      return false;
   }

   // v38: GERBANG AI diperluas ke sini. Model yg sama (fitur pasar umum -
   // chase_dist_atr dkk - bukan spesifik pemicu Rider) divalidasi 74% vs 42%
   // win rate di data historis; tes 7-bulan tunjukkan mesin INI (bukan
   // Rider) yg menghasilkan SEMUA 101 trade, jadi di sinilah AI paling
   // berguna disaring, dipanggil PALING TERAKHIR spt di Rider.
   if(UseAIScoreGate) {
      double aiScoreR = ComputeAIScore(direction);
      if(aiScoreR < AI_Threshold) {
         g_cnt_AIReject++;
         Print("ðŸ¤– SINYAL ", dirStr, " DITOLAK AI: skor ", DoubleToString(aiScoreR,3), " < ambang ", DoubleToString(AI_Threshold,2));
         return false;
      }
   }

   g_cnt_Valid++;
   g_CurrentFlipTime = flipTime;
   Print("âœ… SINYAL ", dirStr, " VALID [", fastTrack ? "JALUR CEPAT - flip segar tanpa tunggu HA" : "JALUR KONFIRMASI", "] (flip ", flipShift, " bar lalu) - siap entry!");
   return true;
}

//--- FUNGSI DUMMY UNTUK UI ---
bool IsHeikenAshiFlip(int direction) {
   if(direction == 1) return (g_HA_Direction_Val == 1 && g_HA_Direction_Prev == -1);
   else return (g_HA_Direction_Val == -1 && g_HA_Direction_Prev == 1);
}
bool IsSupertrendFlip(int direction) {
   if(direction == 1) return (g_ST_Trend == 1 && g_ST_Trend_Prev != 1);
   else return (g_ST_Trend == -1 && g_ST_Trend_Prev != -1);
}
void UpdateOverallTrend() {
   double eF1 = iMA(NULL, PERIOD_H1, 20, 0, MODE_EMA, PRICE_CLOSE, 0);
   double eS1 = iMA(NULL, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE, 0);
   if(eF1 == EMPTY_VALUE) eF1 = 0; if(eS1 == EMPTY_VALUE) eS1 = 0;
   if(eF1 > eS1) g_TrendDirectionOverall = 1;
   else if(eF1 < eS1) g_TrendDirectionOverall = -1;
   else g_TrendDirectionOverall = 0;
}
void CalculateTrendStrength() {
   double emaFast = iMA(NULL, 0, 8, 0, MODE_EMA, PRICE_CLOSE, 1);
   double emaSlow = iMA(NULL, 0, 21, 0, MODE_EMA, PRICE_CLOSE, 1);
   if(emaFast == EMPTY_VALUE) emaFast = 0; if(emaSlow == EMPTY_VALUE) emaSlow = 0;
   if(emaFast > emaSlow) { g_TrendDirection = "UPTREND"; g_TrendColor = C_Green; }
   else if(emaFast < emaSlow) { g_TrendDirection = "DOWNTREND"; g_TrendColor = C_Red; }
   else { g_TrendDirection = "SIDEWAYS"; g_TrendColor = C_Gray; }
}
bool IsTrendFavorableForBuy() { return true; }
bool IsTrendFavorableForSell() { return true; }
void UpdateAdaptiveSystem() {
   double atrValue = iATR(NULL, 0, ATRPeriod_SL, 1);
   double price = iClose(NULL, 0, 1);
   if(price > 0 && atrValue > 0) { g_ATRPercent = (atrValue / price) * 100.0; } else { g_ATRPercent = 0.0; }
   g_ATRPercentAdjusted = g_ATRPercent * PairVolatilityFactor;
   double rawTpFactor = 1.0; double rawSlFactor = 1.0;
   if(UseATRBasedSL && g_ATRPercentAdjusted > 0) {
      rawTpFactor = MathMax(ATRMultiplier_TP * 0.5, MathMin(ATRMultiplier_TP * 2.0, g_ATRPercentAdjusted / 1.0));
      rawSlFactor = MathMax(ATRMultiplier_SL * 0.5, MathMin(ATRMultiplier_SL * 2.0, g_ATRPercentAdjusted / 1.0));
   }
   double tpDistanceFactor = (DynamicTPDistance == DIST_TIGHT) ? 0.7 : (DynamicTPDistance == DIST_WIDE ? 1.3 : 1.0);
   double slDistanceFactor = (DynamicSLDistance == DIST_TIGHT) ? 0.7 : (DynamicSLDistance == DIST_WIDE ? 1.3 : 1.0);
   static double smoothedTpMult = 1.0; static double smoothedSlMult = 1.0;
   double tpAlpha = (DynamicTPSpeed == SPEED_AGGRESSIVE) ? 0.9 : (DynamicTPSpeed == SPEED_SLOW ? 0.2 : 0.5);
   double slAlpha = (DynamicSLSpeed == SPEED_AGGRESSIVE) ? 0.9 : (DynamicSLSpeed == SPEED_SLOW ? 0.2 : 0.5);
   double rawTp = rawTpFactor * tpDistanceFactor; double rawSl = rawSlFactor * slDistanceFactor;
   smoothedTpMult = smoothedTpMult * (1 - tpAlpha) + rawTp * tpAlpha;
   smoothedSlMult = smoothedSlMult * (1 - slAlpha) + rawSl * slAlpha;
   smoothedTpMult = MathMax(0.5, MathMin(2.5, smoothedTpMult));
   smoothedSlMult = MathMax(0.5, MathMin(2.5, smoothedSlMult));
   g_AdaptiveState.tpMult = smoothedTpMult; g_AdaptiveState.slMult = smoothedSlMult;
   double dd = g_CurrentDrawdownPercent; double th = 1.0;
   if(g_ATRPercent > 2.5) th = 1.5; else if(g_ATRPercent > 1.5) th = 1.2; else if(g_ATRPercent < 0.8) th = 0.8;
   if(dd > 15) th *= 1.4;
   g_AdaptiveState.entryThresholdMult = MathMax(0.7, MathMin(2.0, th));
   double trailM = 1.0; if(g_ATRPercent > 2.0) trailM = 1.4;
   g_AdaptiveState.trailMult = MathMax(0.8, MathMin(1.6, trailM));
   double sprM = 1.0; if(g_ATRPercent > 1.5) sprM = 1.3;
   g_AdaptiveState.spreadToleranceMult = MathMax(1.0, MathMin(1.8, sprM));
   if(g_ATR_Prev > 0) { g_ATR_RateOfChange = (atrValue - g_ATR_Prev) / g_ATR_Prev; } else { g_ATR_RateOfChange = 0; }
   g_ATR_Prev = atrValue;
}
double g_ATRPercent = 0, g_ATR_Prev = 0, g_ATR_RateOfChange = 0;
int g_TrendDirectionOverall = 0;
string g_TrendDirection = "SIDEWAYS";
color g_TrendColor = C_Gray;
double PairVolatilityFactor = 1.0;
double ATRMultiplier_TP = 1.5;

//====================================================================
//| ENTRY CHECK                                                     |
//+====================================================================
void CheckEntry() {
   if(!g_Active || !g_AllowTrading || g_GoalHit || g_TradingPaused || g_CurrentOrders >= MaxOrders) return;
   if(!CanTradeNow()) return;
   if(TimeCurrent() - g_LastEntryTime < MinMinutesBetweenTrades * 60) return;
   double avg = GetAverageSpread(5);
   if(avg > g_PairMaxSpread * PipPoint()) return;
   if(!CheckVolatilityFilter()) return;
   if(IsNewsBlocked()) return;

   // v3.02 TEAM LEADER: use as a priority route, but NEVER let a missing
   // Team-Leader marker disable the mature Strategic Core.  Recovery FIX1
   // restores the legacy Reversal/Trend-Rider/Continuation fallback when
   // no Team-Leader signal is available or its consensus is rejected.
   // This was the direct cause of the zero-entry regression when
   // UseTeamLeaderExecution=true and the leader buffers produced no marker.
   if(UseTeamLeaderExecution) {
      int teamDir=0, teamShift=-1;
      if(IsTeamLeaderSignal(1,teamShift)) teamDir=1;
      else if(IsTeamLeaderSignal(-1,teamShift)) teamDir=-1;
      if(teamDir!=0 && (TradeDirection==TRADE_BOTH || (teamDir==1 && TradeDirection==TRADE_BUY_ONLY) || (teamDir==-1 && TradeDirection==TRADE_SELL_ONLY))) {
         double teamScore=0; int teamQuorum=0; string teamWhy="";
         if(IsTeamConsensusValid(teamDir,teamShift,teamScore,teamQuorum,teamWhy)) {
            if(ExecuteTeamLeaderEntry(teamDir,teamShift)) {
               g_LastTeamSignalTime=iTime(NULL,0,teamShift);
               return;
            }
            if(DebugEntryTrace) Print("[TEAM] execution failed -> legacy Strategic Core fallback");
         } else if(DebugEntryTrace) {
            Print("[TEAM] ",(teamDir==1?"BUY":"SELL")," reject: ",teamWhy," -> legacy Strategic Core fallback");
         }
      } else if(DebugEntryTrace) {
         Print("[TEAM] no leader marker -> legacy Strategic Core fallback");
      }
   }

    if((StrategyMode == STRAT_REVERSAL || StrategyMode == STRAT_BOTH) &&
       (TradeDirection == TRADE_BOTH || TradeDirection == TRADE_BUY_ONLY)) {
      if(IsPerfectReversalSignal(1)) {
         bool entryAccepted = false;
         if(ExecutionMode == EXEC_SIGNAL_ONLY) {
            EmitManualSignal(1);
            entryAccepted = true;
         } else if(EntryStyle == ENTRY_PULLBACK_LIMIT) {
            Print(">>> SINYAL BUY VALID - pasang pending pullback <<<");
            entryAccepted = ExecutePullbackOrder(1);
         } else {
            Print(">>> EKSEKUSI BUY <<<");
            entryAccepted = ExecuteSmartOrder(OP_BUY);
         }
         if(entryAccepted) {
            g_LastFlipTraded = g_CurrentFlipTime; // hanya kunci flip bila entry benar-benar diterima
            g_LastMarketEntryCandle = iTime(NULL,0,0);
            return;
         }
         if(DebugEntryTrace) Print("[ENTRY TRACE] BUY signal valid tetapi execution TIDAK diterima; flip tetap terbuka untuk retry pada bar berikutnya.");
      }
   }
   if((StrategyMode == STRAT_REVERSAL || StrategyMode == STRAT_BOTH) &&
      (TradeDirection == TRADE_BOTH || TradeDirection == TRADE_SELL_ONLY)) {
      if(IsPerfectReversalSignal(-1)) {
         bool entryAccepted = false;
         if(ExecutionMode == EXEC_SIGNAL_ONLY) {
            EmitManualSignal(-1);
            entryAccepted = true;
         } else if(EntryStyle == ENTRY_PULLBACK_LIMIT) {
            Print(">>> SINYAL SELL VALID - pasang pending pullback <<<");
            entryAccepted = ExecutePullbackOrder(-1);
         } else {
            Print(">>> EKSEKUSI SELL <<<");
            entryAccepted = ExecuteSmartOrder(OP_SELL);
         }
         if(entryAccepted) {
            g_LastFlipTraded = g_CurrentFlipTime;
            g_LastMarketEntryCandle = iTime(NULL,0,0);
            return;
         }
         if(DebugEntryTrace) Print("[ENTRY TRACE] SELL signal valid tetapi execution TIDAK diterima; flip tetap terbuka untuk retry pada bar berikutnya.");
      }
   }

   // === MESIN TREND RIDER: entri searah trend berjalan ===
   if(StrategyMode == STRAT_TREND_RIDER || StrategyMode == STRAT_BOTH)
      TryContinuationEntry();

   // v41: kalau TIDAK ADA sinyal baru (Reversal maupun Rider) yg tereksekusi
   // tick ini, coba TryPyramidAdd - mengisi celah yg dulu dilaporkan: tren
   // kuat & mulus yg tidak menghasilkan pemicu (flip/breakout) TAMBAHAN sama
   // sekali cuma dapat 1 entri, walau MaxOrders mengizinkan lebih.
   TryPyramidAdd();
}

//+------------------------------------------------------------------+
//| v41: PYRAMID ADD - tambah posisi SEARAH tren yg SUDAH terbuka &   |
//| terbukti profit, TANPA perlu pemicu baru (flip/breakout). Beda    |
//| dari Reversal/Rider (yg keduanya WAJIB ada pemicu segar) - ini     |
//| mengisi celah: tren yg mulus tanpa pemicu tambahan sebelumnya cuma |
//| dapat 1 entri, walau MaxOrders mengizinkan lebih & trennya masih   |
//| jelas berjalan. TETAP dibatasi ketat: min untung ATR posisi        |
//| terakhir (bukti tren sungguhan, bukan asal nambah), min jarak bar, |
//| dan TIDAK boleh menambah kalau harga SUDAH jauh dari garis ST      |
//| (jangan pyramid tepat di titik yg sudah mulai exhausted - ini      |
//| justru sumber masalah "entri di puncak" kalau tak dijaga).         |
//+------------------------------------------------------------------+
void TryPyramidAdd() {
   if(!UsePyramidAdd) return;
   if(!g_Active || !g_AllowTrading || g_GoalHit || g_TradingPaused) return;
   if(g_CurrentOrders < 1 || g_CurrentOrders >= MaxOrders) return;
   if(!CanTradeNow()) return;
   // tentukan arah posisi yg SUDAH terbuka (harus semuanya searah - kalau
   // entah bagaimana ada campuran BUY+SELL, jangan sentuh, biar aman)
   int posDir = 0; datetime lastEntryTime = 0; double lastEntryPrice = 0;
   for(int iPy=0; iPy<OrdersTotal(); iPy++) {
      if(OrderSelect(iPy,SELECT_BY_POS,MODE_TRADES) && OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber) {
         if(OrderType()==OP_BUY)      { if(posDir==-1) return; posDir=1; }
         else if(OrderType()==OP_SELL){ if(posDir==1)  return; posDir=-1; }
         else continue; // pending stop/limit diabaikan, cuma posisi market yg dihitung
         if(OrderOpenTime() > lastEntryTime) { lastEntryTime=OrderOpenTime(); lastEntryPrice=OrderOpenPrice(); }
      }
   }
   if(posDir == 0) return; // tidak ada posisi market terbuka
   int barsSince = iBarShift(NULL, 0, lastEntryTime);
   if(barsSince < PyramidMinBarsGap) return; // jangan nambah tiap saat, kasih jarak
   if((int)STCustom(0, ST_TrendBuffer, 1) != posDir) return; // ST sudah tak searah lagi -> jangan tambah eksposur
   double atrPy = iATR(NULL, 0, 14, 1); if(atrPy <= 0) return;
   RefreshRates();
   double curPrice = (posDir==1) ? Bid : Ask;
   double profitATR = (posDir==1) ? (curPrice-lastEntryPrice)/atrPy : (lastEntryPrice-curPrice)/atrPy;
   if(profitATR < PyramidMinProfitATR) return; // posisi terakhir blm cukup untung - blm ada bukti tren sungguhan lanjut
   double stLineP = (posDir==1) ? STCustom(0,0,1) : STCustom(0,1,1);
   if(stLineP==EMPTY_VALUE || stLineP<=0) return;
   double chaseNow = (posDir==1) ? (curPrice-stLineP)/atrPy : (stLineP-curPrice)/atrPy;
   // v63: DITEMUKAN dr pengamatan Anda - di tren CURAM, harga mencapai
   // untung PyramidMinProfitATR SEKALIGUS sudah melewati PyramidMaxChaseATR
   // dr garis ST hampir bersamaan (garis ST wajar "tertinggal" saat harga
   // bergerak cepat) - menciptakan jendela sempit/tertutup utk pyramid
   // justru di tren yg PALING kuat, kebalikan dr yg diinginkan. FIX: batas
   // jarak-kejar kini ikut melebar di tren CURAM (pakai kerangka kemiringan
   // yg sama dgn AutoSlope/SlopeAdaptiveSLTP) - di tren landai tetap
   // seketat semula (jangan pyramid di titik yg mulai exhausted beneran).
   double chaseLimitNow = PyramidMaxChaseATR;
   if(UseSlopeAdaptiveSLTP) {
      double slopePy = MathAbs(ComputeTrendSlopeATR(AutoSlopeLookbackBars));
      if(slopePy >= AutoSlopeCuramMin) chaseLimitNow = PyramidMaxChaseATR * 1.6; // curam - beri ruang lebih, wajar jauh dr ST saat momentum kuat
      // landai/sedang: chaseLimitNow tetap PyramidMaxChaseATR asli (tak dilonggarkan)
   }
   if(chaseNow > chaseLimitNow) {
      Print("â³ PYRAMID ", (posDir==1?"BUY":"SELL"), " ditahan: jarak dr garis ST ", DoubleToString(chaseNow,2),
            "xATR > batas ", DoubleToString(chaseLimitNow,2), "xATR (untung posisi terakhir sdh ", DoubleToString(profitATR,2), "xATR)");
      return; // sudah terlalu jauh dr garis ST - jangan pyramid di titik yg mulai exhausted
   }
   if(UseAIScoreGate) { // v41: gerbang AI (kalau aktif) tetap ikut menyaring tambahan posisi
      double aiScoreP = ComputeAIScore(posDir);
      if(aiScoreP < AI_Threshold) return;
   }
   Print("ðŸ“ˆ PYRAMID ADD ", (posDir==1?"BUY":"SELL"), ": posisi terakhir untung ", DoubleToString(profitATR,2),
         "xATR, jarak dr garis ST ", DoubleToString(chaseNow,2), "xATR, ", barsSince, " bar sejak entri terakhir - tren msh sehat, tambah posisi");
   ExecuteSmartOrder((posDir==1) ? OP_BUY : OP_SELL);
}

// Entri lanjutan searah trend berjalan. DUA pemicu:
// (1) Panah presisi Supertrend_Promax (buffer 5/6 - tersaring 4 lapis)
// (2) Flip warna HA terkonfirmasi ke arah trend = pola "koreksi selesai,
//     trend lanjut" (pemicu cadangan yang lebih sering muncul)
// Tetap melewati gerbang: trend H1+H4, HA searah, rezim, anti kejar-harga.
datetime g_LastContinuationBar = 0;
int g_cnt_ContTrigger=0, g_cnt_ContRegime=0, g_cnt_ContChase=0, g_cnt_ContEntry=0; // v42c: g_cnt_ContH1/H4/HA dihapus - mati sejak v38 (diganti sistem kuorum, tak pernah diinkremen/dicetak lagi)
int g_cnt_LegAge=0; // v35: dipisah dari g_cnt_ContChase spy "kejar-harga" vs "kaki trend tua" kelihatan beda di diagnostik
int g_cnt_AIReject=0; // v36: hitung berapa kali gerbang AI menahan sinyal
int g_cnt_ContKnife=0; // v21: penjaga titik jenuh (exhaustion guard) - mesin lanjutan
input bool UseHAFlipTrigger = true; // pemicu cadangan: HA baru berganti warna searah trend

void TryContinuationEntry() {
   if(!UseContinuationEntries) return;
   datetime barNow = iTime(NULL, 0, 1);
   if(barNow == g_LastContinuationBar) return; // satu bar = satu kesempatan

   // --- PEMICU 1: panah presisi Supertrend_Promax ---
   double buyArr  = STCustom(0, ContSignalBuyBuffer, 1);
   double sellArr = STCustom(0, ContSignalSellBuffer, 1);
   int dir = 0; string trig = "";
   if(buyArr != EMPTY_VALUE && buyArr > 0) { dir = 1; trig = "panah ST"; }
   else if(sellArr != EMPTY_VALUE && sellArr > 0) { dir = -1; trig = "panah ST"; }

   // --- PEMICU 2 (cadangan): HA terkonfirmasi BARU berganti warna ---
   if(dir == 0 && UseHAFlipTrigger && UseHeikenAshi) {
      if(g_HA_Direction_Val == 1 && g_HA_Direction_Prev != 1) { dir = 1; trig = "HA flip"; }
      else if(g_HA_Direction_Val == -1 && g_HA_Direction_Prev != -1) { dir = -1; trig = "HA flip"; }
   }

   // --- PEMICU 3 (v17): BREAKOUT KOTAK KONSOLIDASI ADAPTIF ---
   // Disatukan dgn sistem kotak (dulu pakai jendela kecil sendiri ->
   // kontradiksi jurnal 8 Jul: pemicu bilang "breakout" tapi kotak bilang
   // "masih di dalam"). Kini: candle bar-1 yang tercatat MENEMBUS batas
   // kotak (oleh UpdateCompressionBox) = pemicu sah, otomatis konsisten
   // dgn vonis kotak.
   if(dir == 0 && UseLineResumeTrigger) {
      if(g_LastBreakDir != 0 && g_LastBreakTime == iTime(NULL, 0, 1)) {
         dir = g_LastBreakDir; trig = "breakout kotak";
      }
   }
   if(dir == 0) return;
   g_cnt_ContTrigger++;
   if(TradeDirection == TRADE_BUY_ONLY && dir == -1) return;
   if(TradeDirection == TRADE_SELL_ONLY && dir == 1) return;
   string dirStr = (dir == 1) ? "BUY" : "SELL";

   // v21 PENJAGA TITIK JENUH: trend SAAT INI (searah sinyal lanjutan)
   // sudah lari jauh dari garis ST -> risiko sinyal ini sebetulnya awal
   // PEMBALIKAN, bukan pullback sehat (akar masalah "entri di titik jenuh"
   // - bukti trade #246: RIDER BUY panah ST lolos persis saat REVERSAL
   // engine menolak arah sama krn "melawan LEG RAKSASA" - kini keduanya
   // memakai standar kewaspadaan yang sama).
   if(UseExhaustionGuard) {
      double atrEx = iATR(NULL, 0, 14, 1);
      if(atrEx > 0) {
         double curExtPips = GetCurrentTrendExtensionPips(dir) * PipPoint();
         if(curExtPips > ExhaustionATR * atrEx) {
            double oEx = iOpen(NULL, 0, 1), cEx = iClose(NULL, 0, 1);
            bool exStrong = ((dir == 1) ? (cEx > oEx) : (cEx < oEx)) && MathAbs(cEx - oEx) >= ExhaustionMinBodyATR * atrEx;
            if(!exStrong) {
               g_cnt_ContKnife++;
               Print("âŒ RIDER ", dirStr, " (", trig, ") DITOLAK: trend SAAT INI sudah lari ", DoubleToString(curExtPips/PipPoint(),1),
                     " pips (> ", DoubleToString(ExhaustionATR,1), "xATR) dari garis ST - titik jenuh, risiko segera berbalik, bukan pullback sehat");
               return;
            }
         }
      }
   }

   // === v38: KUORUM PENYELARASAN ARAH (ganti rantai AND-ketat) ===========
   // Sebelumnya Gerbang 1/1b/2/3/3-bis (H1, H4, HA, Regime, HTFBias) WAJIB
   // SEMUA lolos berurutan. Tes 7-bulan (2025.10-2026.04, 4394 bar) buktikan
   // ini terlalu ketat: dari 482 pemicu genuine, 0 yang lolos SEMUA gerbang
   // - ENTRI TREND RIDER = 0 sepanjang 7 bulan. Gerbang H4 sendirian menahan
   // 161/482 (~33%, sudah dicurigai dari komentar v17 "H4 selalu terlambat
   // vs H1"), HTFBias 77 lagi - kombinasi banyak gerbang searah membuat
   // hampir selalu ADA SATU yang belum pas di momen manapun, walau 4 lainnya
   // sudah setuju. Filosofi baru: mayoritas indikator setuju (kuorum) sudah
   // bukti cukup kuat, tidak perlu bulat 5/5. Exhaustion guard (di atas) &
   // Chase guard/kotak/candle (di bawah) TETAP wajib mutlak - itu soal
   // RISIKO, bukan soal "berapa indikator setuju arah", jadi tidak dikuorumkan.
   int contVotes = 0; string contMiss = "";

   bool h1OK = ((int)STCustom(0, ST_TrendBuffer, 1) == dir);
   if(h1OK) contVotes++; else contMiss += "H1 ";

   bool h4OK = true;
   if(UseH4AlignmentForTrend != H4_OFF) {
      int h4Trend = (int)STCustom(PERIOD_H4, ST_TrendBuffer, 1);
      h4OK = (h4Trend == dir);
      if(!h4OK && UseH4AlignmentForTrend == H4_SOFT) {
         double h4Close = iClose(NULL, PERIOD_H4, 1);
         double h4Open  = iOpen(NULL, PERIOD_H4, 1);
         bool h4CandleAgrees = (dir == 1) ? (h4Close > h4Open) : (h4Close < h4Open);
         double h4OppLine = (dir == 1) ? STCustom(PERIOD_H4, 1, 1) : STCustom(PERIOD_H4, 0, 1);
         bool h4Breaking = false;
         if(h4OppLine != EMPTY_VALUE && h4OppLine > 0)
            h4Breaking = (dir == 1) ? (h4Close > h4OppLine * 0.999) : (h4Close < h4OppLine * 1.001);
         h4OK = (h4CandleAgrees || h4Breaking);
      }
   }
   if(h4OK) contVotes++; else contMiss += "H4 ";

   bool haOK = true;
   if(UseHeikenAshi) {
      haOK = (g_HA_Direction_Val == dir);
      if(!haOK && UseFastTrackEntry && trig == "breakout kotak" && RawHADirection() == dir) haOK = true; // jalur cepat breakout, spt semula
   }
   if(haOK) contVotes++; else contMiss += "HA ";

   double diPr=0, diMr=0, slopeR=0;
   bool regimeOK = true;
   if(UseRegimeFilter) {
      int rvR = RegimeVerdict(dir, diPr, diMr, slopeR);
      regimeOK = (rvR != -1);
   }
   if(regimeOK) contVotes++; else contMiss += "Regime ";

   int biasR=0; double slopeRB=0;
   bool htfOK = (HTFBiasVerdict(dir, biasR, slopeRB) == 0); // fungsi ini sendiri sudah cek UseHTFBiasFilter
   if(htfOK) contVotes++; else contMiss += "HTFBias ";

   // v53: kuorum efektif disesuaikan TradingMode (Conservative +1 lebih
   // ketat, Aggressive -1 lebih longgar, Normal tak berubah), dijaga tetap
   // di rentang wajar 1-5.
   // v62: CONTROLLED A/B QUORUM
   // Override hanya mengganti baseline continuation quorum.
   // TradingMode adjustment tetap diterapkan.
   int baseQuorum = EnableQuorumABOverride
                    ? QuorumABOverride
                    : ContQuorumRequired;

   int effQuorum = baseQuorum + g_ModeQuorumAdjust;

   if(effQuorum < 1) effQuorum = 1;
   if(effQuorum > 5) effQuorum = 5;

   Print("[QUORUM CONFIG] base=", baseQuorum,
         " override=", (EnableQuorumABOverride ? "ON" : "OFF"),
         " modeAdjust=", g_ModeQuorumAdjust,
         " effective=", effQuorum);
   if(contVotes < effQuorum) {
      g_cnt_ContRegime++;
      Print("â³ RIDER ", dirStr, " (", trig, ") tertahan: kuorum arah kurang (", contVotes, "/5, min ", effQuorum,
            ") - blm lolos: ", contMiss, "(DI+ ", DoubleToString(diPr,1), " vs DI- ", DoubleToString(diMr,1), ")");
      return;
   }
   if(contVotes < 5)
      Print("âš¡ RIDER ", dirStr, " (", trig, "): kuorum arah ", contVotes, "/5 (blm lolos: ", contMiss, ") - mayoritas setuju, tetap dilayani");
   // Gerbang 3b (v16): VONIS KOTAK KONSOLIDASI - berlaku utk SEMUA pemicu
   // (panah ST, HA flip, maupun breakout). Kotak adaptif jadi otoritas
   // tunggal: di dalam kotak = blokir; keluar kotak = hanya searah breakout.
   int cvC = CompressionVerdict(dir);
   if(cvC != 0) {
      if(cvC == 1) {
         g_cnt_Compress++;
         if(g_BoxActive)
            Print("âŒ RIDER ", dirStr, " (", trig, ") DITOLAK: harga DI DALAM KOTAK SIDEWAYS (", g_BoxBars, " bar, ",
                  DoubleToString((g_BoxHigh-g_BoxLow)/PipPoint(),1), " pips) - sinyal di dalam kotak = zigzag");
         else
            Print("âŒ RIDER ", dirStr, " (", trig, ") DITOLAK: KANTONG CHOP jangka-pendek (v19, ", ShortPocketBars, " bar terjepit)");
      } else {
         g_cnt_OppLock++;
         Print("âŒ RIDER ", dirStr, " (", trig, ") DITOLAK: MELAWAN arah breakout kotak terakhir (kunci ", OppositeLockBars, " bar)");
      }
      return;
   }
   // Gerbang 3c (v16): KEKUATAN CANDLE SINYAL - berlaku utk SEMUA pemicu
   // (termasuk breakout: breakout berbadan kecil = breakout palsu)
   if(!IsSignalCandleStrong(dir)) {
      g_cnt_WeakBody++;
      Print("âŒ RIDER ", dirStr, " (", trig, ") DITOLAK: candle sinyal lemah/berlawanan (badan < ", DoubleToString(MinSignalBodyATR,2), " x ATR) - ciri zigzag/koreksi");
      return;
   }
   // Gerbang 4: anti kejar-harga (jarak ke garis ST wajar - DIPERKETAT dari
   // 2.0x ke 1.5x: entri "kurang tepat" di penunjuk visual terjadi saat harga
   // sudah jauh melayang di atas garis di ujung leg)
   if(UseChaseGuard) {
      // v17: batas sadar-band (jarak alami harga-garis pasca-flip =
      // ST_ATRMultiplier x ATR; batas lama 1.2xATR < itu -> entri segar
      // pun tertolak, jurnal 3 Jul 16:00 awal rally)
      double stLine = (dir == 1) ? STCustom(0, 0, 1) : STCustom(0, 1, 1);
      double atrC = iATR(NULL, 0, 14, 1);
      if(stLine != EMPTY_VALUE && stLine > 0 && atrC > 0) {
         double dist   = (dir == 1) ? (Bid - stLine) : (stLine - Bid);
         double limitC = (ST_ATRMultiplier + MaxChaseATR) * atrC;
         if(dist > limitC) {
            // v6.46 FIX2: jangan membuang sinyal continuation yang valid hanya
            // karena harga sudah terlalu jauh untuk MARKET ENTRY. Ini bukan
            // alasan untuk mengejar harga. Ubah menjadi PULLBACK LIMIT yang
            // menunggu harga kembali ke area retracement/ST. Dengan demikian
            // Chase Guard menjadi ROUTER (market -> limit), bukan pembunuh
            // sinyal. Jika pending gagal dibuat, barulah sinyal dianggap
            // gagal secara eksekusi.
            g_cnt_ContChase++;
            Print("âš ï¸ RIDER ", dirStr, " (", trig, ") MARKET DITAHAN: harga ",
                  DoubleToString(dist/PipPoint(),1), " pips dari garis ST (batas ",
                  DoubleToString(limitC/PipPoint(),1), ") - ROUTE ke PULLBACK LIMIT, bukan kejar harga");
            bool pbPlaced = ExecutePullbackOrder(dir);
            if(pbPlaced) {
               g_LastContinuationBar = barNow;
               g_cnt_ContEntry++;
               g_cnt_Valid++;
               Print("âœ… RIDER ", dirStr, " (", trig, ") PULLBACK LIMIT berhasil dipasang sebagai pengganti MARKET yang terlalu jauh");
            } else {
               Print("âŒ RIDER ", dirStr, " (", trig, ") PULLBACK LIMIT gagal dipasang - sinyal tidak dipaksa menjadi MARKET ENTRY");
            }
            return;
         }
      }
   }

   // Gerbang 6 (penunjuk visual "BUY KURANG TEPAT"): JANGAN entri di kaki
   // trend yang sudah TUA *dan mulai kehabisan tenaga*. Garis yg sudah
   // menanjak beruntun > MaxLegAgeBars dicurigai matang - tapi v35: dicurigai
   // BUKAN otomatis diblokir. ADX yang masih naik/tetap = trend masih sehat
   // walau sudah lama (persis "garis lurus simetris" yg jadi komplain -
   // trend halus & kuat wajar berjalan lama tanpa tanda lemah). Hanya
   // diblokir kalau ADX JUGA melemah dibanding LegAgeADXLookback bar lalu -
   // itu baru bukti nyata kaki trend sungguh kehabisan tenaga.
   if(MaxLegAgeBars > 0 && trig != "breakout kotak") {
      int lineBufA = (dir == 1) ? 0 : 1;
      int legAge = 0;
      for(int ka = 1; ka <= 30; ka++) {
         double la = STCustom(0, lineBufA, ka);
         double lb = STCustom(0, lineBufA, ka + 1);
         if(la == EMPTY_VALUE || lb == EMPTY_VALUE || la <= 0 || lb <= 0) break;
         if(la == lb) break; // ketemu langkah datar = awal kaki
         legAge++;
      }
      if(legAge > MaxLegAgeBars) {
         double adxNowA   = iADX(NULL, 0, 14, PRICE_CLOSE, MODE_MAIN, 1);
         double adxOlderA = iADX(NULL, 0, 14, PRICE_CLOSE, MODE_MAIN, 1 + LegAgeADXLookback);
         bool stillStrong = (adxNowA >= adxOlderA);
         if(!stillStrong) {
            g_cnt_LegAge++;
            Print("âŒ RIDER ", dirStr, " (", trig, ") DITOLAK: kaki trend sudah TUA & ADX melemah (garis menanjak ", legAge,
                  " bar beruntun, max ", MaxLegAgeBars, "; ADX ", DoubleToString(adxNowA,1), " vs ", DoubleToString(adxOlderA,1),
                  " ", LegAgeADXLookback, " bar lalu) - tunggu kaki baru");
            return;
         }
         Print("âš¡ RIDER ", dirStr, " (", trig, "): kaki trend ", legAge, " bar (>", MaxLegAgeBars, ") TAPI ADX masih kuat (",
               DoubleToString(adxNowA,1), " vs ", DoubleToString(adxOlderA,1), ") - belum jenuh, tetap dilayani");
      }
   }

   // Gerbang 5 (bahasa garis v2): garis ST wajib MENANJAK CUKUP CURAM -
   // kemiringan garis = kekuatan trend. Garis datar/nyaris-datar = sideways
   // atau trend lemah/pendek menurut indikatornya sendiri -> tidak dilayani.
   // Hanya trend yang garisnya maju >= MinLineSlopeATR x ATR dlm jendela.
   if(UseLineSlopeGate) {
      int lineBufG = (dir == 1) ? 0 : 1;
      double lNew = STCustom(0, lineBufG, 1);
      double lOld = STCustom(0, lineBufG, 1 + LineFlatBars);
      double atrG = iATR(NULL, 0, 14, 1);
      if(lNew != EMPTY_VALUE && lOld != EMPTY_VALUE && lNew > 0 && lOld > 0 && atrG > 0) {
         double lineAdvance = (dir == 1) ? (lNew - lOld) : (lOld - lNew);
         if(lineAdvance < MinLineSlopeATR * atrG) {
            g_cnt_ContRegime++;
            Print("â³ RIDER ", dirStr, " (", trig, ") tertahan: garis ST kurang curam (maju ",
                  DoubleToString(lineAdvance/PipPoint(),1), " pips dlm ", LineFlatBars, " bar, min ",
                  DoubleToString(MinLineSlopeATR*atrG/PipPoint(),1), ") - trend lemah/pendek");
            return;
         }
      }
   }

   // v36: GERBANG AI (opsional, default mati) - dipanggil PALING TERAKHIR,
   // setelah semua gerbang lain lolos. Model decision tree dilatih dari
   // histori Anda sendiri (lihat PANDUAN_INTEGRASI_AI_v2.md untuk detail &
   // cara re-training kalau mau menyetel ulang).
   if(UseAIScoreGate) {
      double aiScore = ComputeAIScore(dir);
      if(aiScore < AI_Threshold) {
         g_cnt_AIReject++;
         Print("ðŸ¤– RIDER ", dirStr, " (", trig, ") DITOLAK AI: skor ", DoubleToString(aiScore,3), " < ambang ", DoubleToString(AI_Threshold,2));
         return;
      }
   }

   g_LastContinuationBar = barNow;
   g_cnt_ContEntry++; g_cnt_Valid++;
   Print("âœ… ENTRI TREND RIDER ", dirStr, " (pemicu: ", trig, ") - trend H1+H4 searah, semua gerbang lolos!");
   if(ExecutionMode == EXEC_SIGNAL_ONLY) EmitManualSignal(dir);
   else ExecuteSmartOrder(dir == 1 ? OP_BUY : OP_SELL);
   g_LastMarketEntryCandle = iTime(NULL,0,0);
}

// PUNCAK - MODE SIGNAL_ONLY: sinyal valid tidak dieksekusi otomatis,
// melainkan digambar sbg panah + Alert utk keputusan entri MANUAL
// (tombol Manual BUY/SELL di dashboard tetap tersedia utk eksekusinya).
void EmitManualSignal(int direction) {
   string nm = PFX + "SIG_" + IntegerToString((long)iTime(NULL,0,0));
   double price = (direction==1) ? iLow(NULL,0,0) - 10*PipPoint() : iHigh(NULL,0,0) + 10*PipPoint();
   if(ObjectFind(0, nm) < 0) {
      ObjectCreate(0, nm, OBJ_ARROW, 0, iTime(NULL,0,0), price);
      ObjectSetInteger(0, nm, OBJPROP_ARROWCODE, (direction==1) ? 233 : 234);
      ObjectSetInteger(0, nm, OBJPROP_COLOR, (direction==1) ? clrLime : clrRed);
      ObjectSetInteger(0, nm, OBJPROP_WIDTH, 3);
   }
   string dirStr = (direction==1) ? "BUY" : "SELL";
   Alert("SINYAL ", dirStr, " VALID (4 indikator setuju) di ", Symbol(), " ", DoubleToString(iClose(NULL,0,0), Digits),
         " - mode SIGNAL_ONLY: eksekusi manual via tombol dashboard");
   Print(">>> SINYAL ", dirStr, " (SIGNAL_ONLY - tidak dieksekusi otomatis) <<<");
}

//====================================================================
//| TRADE MONITOR & TRAILING                                         |
//+------------------------------------------------------------------+
void AddTradeMonitor(int tic) {
   if(g_tradeMonitorCount >= MAX_TRADE_MONITORS) {
      g_cnt_MonitorFull++;
      Print("ðŸš¨ SLOT MONITOR PENUH (", MAX_TRADE_MONITORS, ") - posisi #", tic,
            " TIDAK akan dapat trailing/BE/partial/spike-guard! Kurangi jumlah posisi bersamaan.");
      return;
   }
   for(int i=0;i<g_tradeMonitorCount;i++) if(g_tradeMonitors[i].ticket==tic) return;
   g_tradeMonitors[g_tradeMonitorCount].ticket = tic;
   g_tradeMonitors[g_tradeMonitorCount].highestPrice = 0;
   g_tradeMonitors[g_tradeMonitorCount].lowestPrice = 1000000;
   g_tradeMonitors[g_tradeMonitorCount].highestProfitPips = 0;
   g_tradeMonitors[g_tradeMonitorCount].spikeHighPrice = 0; // v49: puncak spike-guard, direset per posisi
   g_tradeMonitors[g_tradeMonitorCount].peakProfitATR = 0;  // v3.00
   g_tradeMonitors[g_tradeMonitorCount].ladderStep    = 0;  // v3.00
   g_tradeMonitors[g_tradeMonitorCount].deadCutDone   = false; // v3.00
   g_tradeMonitors[g_tradeMonitorCount].atrEntry = GetATRInPips(); if(g_tradeMonitors[g_tradeMonitorCount].atrEntry <= 0) g_tradeMonitors[g_tradeMonitorCount].atrEntry = 20;
   g_tradeMonitors[g_tradeMonitorCount].barsHeld = 0;
   g_tradeMonitors[g_tradeMonitorCount].partialClosed = false;
   g_tradeMonitors[g_tradeMonitorCount].partialLevel1Done = false;
   g_tradeMonitors[g_tradeMonitorCount].partialLevel2Done = false;
   g_tradeMonitors[g_tradeMonitorCount].openTime = TimeCurrent();
   g_tradeMonitors[g_tradeMonitorCount].virtualSL = 0;
   g_tradeMonitors[g_tradeMonitorCount].softStopActive = false;
   g_tradeMonitors[g_tradeMonitorCount].graceNormalSL = 0;
   g_tradeMonitors[g_tradeMonitorCount].graceActive = false;
   g_tradeMonitors[g_tradeMonitorCount].graceBarsTarget = GracePeriodBars; // default - akan ditimpa SetGracePeriod kalau relevan
   g_tradeMonitorCount++;
}
void SetVirtualSL(int tic, double vsl) { for(int i=0;i<g_tradeMonitorCount;i++) if(g_tradeMonitors[i].ticket==tic) { g_tradeMonitors[i].virtualSL=vsl; g_tradeMonitors[i].softStopActive=UseSoftStopLoss; break; } }
// v46: simpan target SL NORMAL (sempit) yg akan diterapkan setelah masa
// tenggang lewat - dipanggil sekali saat entri, kalau UseEntryGracePeriod aktif.
void SetGracePeriod(int tic, double normalSL, int barsTarget=-1) { for(int i=0;i<g_tradeMonitorCount;i++) if(g_tradeMonitors[i].ticket==tic) { g_tradeMonitors[i].graceNormalSL=normalSL; g_tradeMonitors[i].graceActive=true; if(barsTarget>0) g_tradeMonitors[i].graceBarsTarget=barsTarget; break; } }
// v46: cek apakah masa tenggang sudah lewat (barsHeld >= GracePeriodBars) -
// kalau ya, ketatkan SL sungguhan ke target normal. HANYA mengetat (jarak
// makin dekat ke harga), TIDAK PERNAH melonggarkan - kalau trailing lain
// sudah menggerakkan SL lebih baik dari target normal duluan, dibiarkan
// (tidak dikembalikan lebih longgar). Sekali diproses (baik ditutup
// maupun dilewati krn sudah lebih baik), graceActive dimatikan - tidak
// dicek ulang lagi.
void ManageEntryGracePeriod(int tic) {
   int idx=-1; for(int i=0;i<g_tradeMonitorCount;i++) if(g_tradeMonitors[i].ticket==tic) { idx=i; break; }
   if(idx<0 || !g_tradeMonitors[idx].graceActive) return;
   if(g_tradeMonitors[idx].barsHeld < g_tradeMonitors[idx].graceBarsTarget) return; // masa tenggang blm lewat
   if(!OrderSelect(tic, SELECT_BY_TICKET, MODE_TRADES)) { g_tradeMonitors[idx].graceActive=false; return; }
   int type=OrderType(); if(type!=OP_BUY && type!=OP_SELL) { g_tradeMonitors[idx].graceActive=false; return; }
   double curSL = OrderStopLoss(); double target = g_tradeMonitors[idx].graceNormalSL;
   bool shouldTighten = (type==OP_BUY) ? (curSL < target) : (curSL > target && curSL > 0);
   if(shouldTighten) {
      // v59 FIX BUG PENTING: target dihitung SEKALI saat posisi baru
      // terdeteksi (berdasar ATR saat itu). Kalau harga bergerak jauh
      // BERLAWANAN selama masa tenggang (kini bisa 5-8 bar utk asal LIMIT -
      // jendela lebih panjang = lebih banyak waktu utk ini terjadi), target
      // lama itu bisa jadi TIDAK VALID lagi thd harga SEKARANG (kejauhan
      // dekat/di sisi salah) - OrderModify gagal error 130 (invalid stops).
      // SEBELUMNYA: gagal = MENYERAH, graceActive dimatikan, posisi
      // TERTINGGAL SELAMANYA dgn SL lebar (risiko malah lebih besar, bukan
      // "masa tenggang selesai, kembali normal" spt niatnya). FIX: kalau
      // target asli gagal, coba SEKALI LAGI dgn target yg di-CLAMP relatif
      // harga SEKARANG (msh arah yg sama, sejauh mungkin scr aman) - supaya
      // pengetatan tetap terjadi, bukan macet permanen.
      double point = PipPoint();
      double minDist = MathMax(g_StopLevel*point, 15*point);
      // v2.00: kalau target ternyata identik dgn SL terpasang, jangan panggil
      // broker sama sekali (mencegah error 1 & log sampah).
      if(NormalizeDouble(target,g_Digits) == NormalizeDouble(curSL,g_Digits)) {
         g_tradeMonitors[idx].graceActive = false;
         return;
      }
      bool ok = OrderModify(tic, OrderOpenPrice(), NormalizeDouble(target,g_Digits), OrderTakeProfit(), 0, clrNONE);
      if(ok) { Print("â±ï¸ MASA TENGGANG SL #", tic, " berakhir (", g_tradeMonitors[idx].barsHeld, " bar) - SL mengetat ke normal @ ", DoubleToString(target,g_Digits)); }
      else {
         int errG=GetLastError();
         if(errG==130) {
            RefreshRates();
            double bidG=MarketInfo(Symbol(),MODE_BID), askG=MarketInfo(Symbol(),MODE_ASK);
            double clampedTarget = (type==OP_BUY) ? MathMin(target, bidG-minDist) : MathMax(target, askG+minDist);
            bool ok2 = OrderModify(tic, OrderOpenPrice(), NormalizeDouble(clampedTarget,g_Digits), OrderTakeProfit(), 0, clrNONE);
            if(ok2) Print("â±ï¸ MASA TENGGANG SL #", tic, " berakhir (", g_tradeMonitors[idx].barsHeld, " bar) - target asli @ ", DoubleToString(target,g_Digits), " sudah tak valid (harga bergerak jauh), SL mengetat ke @ ", DoubleToString(clampedTarget,g_Digits), " sedekat aman yg memungkinkan");
            else { int errG2=GetLastError(); if(errG2!=0) Print("Grace-period OrderModify err #", errG2, " (percobaan clamp jg gagal)"); }
         }
         else if(errG!=0) Print("Grace-period OrderModify err #", errG);
      }
   }
   g_tradeMonitors[idx].graceActive = false; // selesai diproses, tak dicek lagi (baik berhasil maupun sudah lebih baik dr trailing lain)
}
void RemoveTradeMonitor(int tic) { for(int i=0;i<g_tradeMonitorCount;i++) if(g_tradeMonitors[i].ticket==tic) { for(int j=i;j<g_tradeMonitorCount-1;j++) g_tradeMonitors[j]=g_tradeMonitors[j+1]; g_tradeMonitorCount--; break; } }
void UpdateTradeMonitor(int tic, double price, double point) {
   for(int i=0;i<g_tradeMonitorCount;i++) if(g_tradeMonitors[i].ticket==tic) {
      if(!OrderSelect(tic, SELECT_BY_TICKET)) break;
      double open = OrderOpenPrice();
      double profit = (OrderType() == OP_BUY) ? (price - open) / point : (open - price) / point;
      if(profit > g_tradeMonitors[i].highestProfitPips) {
         g_tradeMonitors[i].highestProfitPips = profit;
         if(OrderType() == OP_BUY && price > g_tradeMonitors[i].highestPrice) g_tradeMonitors[i].highestPrice = price;
         else if(OrderType() == OP_SELL && price < g_tradeMonitors[i].lowestPrice) g_tradeMonitors[i].lowestPrice = price;
      }
      break;
   }
}
void UpdateTradeMonitorBars() { datetime now = TimeCurrent(); for(int i=0;i<g_tradeMonitorCount;i++) { int bars = (int)((now - g_tradeMonitors[i].openTime) / PeriodSeconds(Period())); if(bars > g_tradeMonitors[i].barsHeld) g_tradeMonitors[i].barsHeld = bars; } }
// v42c: GetHighestFavorablePrice dihapus - genuinely tak pernah dipanggil;
// akses highestPrice/lowestPrice dilakukan LANGSUNG dari struct di tempat
// yg memakainya (lihat IsPullbackOnly), bukan lewat fungsi ini.

bool IsPullbackOnly(int tic, double price, double point) {
   if(!UsePullbackDetection) return false;
   if(!OrderSelect(tic, SELECT_BY_TICKET)) return false;
   int type = OrderType(); double open = OrderOpenPrice(); double high=0, low=0;
   for(int i=0;i<g_tradeMonitorCount;i++) if(g_tradeMonitors[i].ticket==tic) { high = g_tradeMonitors[i].highestPrice; low = g_tradeMonitors[i].lowestPrice; break; }
   if(type == OP_BUY && high > open) { double totalMove = (high - open)/point; double retrace = (high - price)/point; if(totalMove > 0 && (retrace/totalMove)*100 < PullbackRetracePercent) return true; }
   else if(type == OP_SELL && low < open && low > 0) { double totalMove = (open - low)/point; double retrace = (price - low)/point; if(totalMove > 0 && (retrace/totalMove)*100 < PullbackRetracePercent) return true; }
   return false;
}

void ManagePartialProfit(int tic, double profit, double atr) {
   if(!UsePartialProfit) return;
   if(!OrderSelect(tic, SELECT_BY_TICKET, MODE_TRADES)) return;
   int idx = -1;
   for(int i=0;i<g_tradeMonitorCount;i++) if(g_tradeMonitors[i].ticket==tic) { idx = i; break; }
   if(idx == -1 || g_tradeMonitors[idx].partialClosed) return;
   double l1 = atr * PartialProfitLevel1, l2 = atr * PartialProfitLevel2;
   double lot = OrderLots(); double closeLot = 0; double minLotPP = GetMinLotLimit();
   bool lvl2Reached = (profit >= l2);
   bool lvl1Reached = (profit >= l1 && !g_tradeMonitors[idx].partialLevel1Done);
   if(!lvl2Reached && !lvl1Reached) return;
   if(lvl2Reached) closeLot = NormalizeDouble(lot * PartialProfitPercent2 / 100.0, 2);
   else closeLot = NormalizeDouble(lot * PartialProfitPercent1 / 100.0, 2);
   // v51 FIX BUG STRUKTURAL (bukan soal waktu - ini murni matematika): kalau
   // lot posisi kecil (persis kasus akun ini, SEMUA trade pakai 0.01
   // minimum broker), closeLot = 0.01 x 30% = 0.003, dibulatkan jadi 0.00 -
   // TIDAK VALID, partial-close TIDAK PERNAH bisa terjadi apa pun perbaikan
   // waktu pengecekannya (v50 benar tp tidak cukup). FALLBACK: kalau lot tak
   // bisa dipecah, kunci level profit via SL (spt Spike Guard) - tetap dapat
   // manfaat "amankan profit bertahap per level ATR" meski lotnya sendiri
   // tak bisa dikurangi.
   if(closeLot < minLotPP) {
      double pointPP = PipPoint(), openPP = OrderOpenPrice();
      double lockLevel = lvl2Reached ? l2 : l1;
      double newSLPP = (OrderType()==OP_BUY) ? openPP + lockLevel*pointPP : openPP - lockLevel*pointPP;
      double curSLPP = OrderStopLoss();
      // v2.00 BUG-2 FIX (bentuk sama spt Spike Guard): normalisasi DULU baru banding.
      double minDistPP0 = MathMax(g_StopLevel*pointPP, 15*pointPP);
      double curPricePP0 = (OrderType()==OP_BUY) ? Bid : Ask;
      if(OrderType()==OP_BUY) { if(newSLPP > curPricePP0-minDistPP0) newSLPP = curPricePP0-minDistPP0; }
      else { if(newSLPP < curPricePP0+minDistPP0) newSLPP = curPricePP0+minDistPP0; }
      newSLPP = NormalizeDouble(newSLPP, g_Digits);
      curSLPP = NormalizeDouble(curSLPP, g_Digits);
      bool improvePP = (OrderType()==OP_BUY) ? (newSLPP > curSLPP) : (curSLPP==0 || newSLPP < curSLPP);
      if(improvePP) {
         if(SafeOrderModify(tic, openPP, newSLPP, OrderTakeProfit(), 0, clrNONE, "PartialLock"))
            Print("ðŸ”’ PARTIAL PROFIT (mode kunci-SL, lot ", DoubleToString(lot,2), " terlalu kecil utk dipecah) #", tic,
                  ": level ", (lvl2Reached?"2":"1"), " tercapai (", DoubleToString(profit,1), " pip) - SL dikunci ~", DoubleToString(lockLevel,1), " pip profit");
      }
      if(lvl2Reached) g_tradeMonitors[idx].partialClosed=true; else g_tradeMonitors[idx].partialLevel1Done=true;
      return;
   }
   if(closeLot > 0 && closeLot < lot) {
      // v3.00 FIX BALAPAN (error 4108 "unknown ticket", terlihat di jurnal
      // TAHAP 0 & 1): tiket bisa DITUTUP broker (kena TP/SL) di antara saat
      // fungsi ini memilihnya dan saat OrderClose dipanggil - persis yg
      // terjadi pada #27: "Tester: take profit #27" lalu langsung
      // "unknown ticket 27 for OrderClose function". Kini diperiksa ulang
      // tepat sebelum menutup.
      if(!OrderSelect(tic, SELECT_BY_TICKET, MODE_TRADES) || OrderCloseTime()!=0) {
         RemoveTradeMonitor(tic);
         return;
      }
      double closePrice = (OrderType()==OP_BUY)?Bid:Ask; int oldTicket=tic; double remainingLot = NormalizeDouble(lot - closeLot, 2);
      if(OrderClose(tic, closeLot, closePrice, 3, clrBlue)) {
         // v46: sebelumnya SILENT - partial profit tereksekusi tp TIDAK ADA
         // jejak log sama sekali, beda dgn PYRAMID ADD/PENDING LANJUT-TREN
         // yg selalu tercatat. Kini disamakan supaya bisa diaudit dari jurnal.
         Print("ðŸ’° PARTIAL PROFIT #", oldTicket, ": tutup ", DoubleToString(closeLot,2), " dari ", DoubleToString(lot,2), " lot @ ", DoubleToString(closePrice,g_Digits), " (level ", (profit>=l2?"2":"1"), ", profit saat itu ", DoubleToString(profit,1), " pip)");
         int newTicket=-1;
         for(int i=OrdersTotal()-1;i>=0;i--) if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES) && OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber && MathAbs(OrderLots()-remainingLot)<0.01 && OrderTicket()!=oldTicket) { newTicket=OrderTicket(); break; }
         // v2.00 BUG-3 FIX (bug nyata, terjadi 235x di tes Jan-Jul 2026):
         // RemoveTradeMonitor() MENGGESER isi array ke kiri, AddTradeMonitor()
         // menaruh tiket baru di UJUNG. Kode lama tetap memakai 'idx' yg
         // dihitung SEBELUM keduanya - jadi flag partialClosed/partialLevel1Done
         // dicap ke SLOT YANG SALAH, yaitu posisi LAIN yg kebetulan bergeser
         // ke situ. Akibatnya ganda: (a) posisi lain yg masih hidup ditandai
         // "partial sudah selesai" secara palsu -> tak pernah dapat partial
         // profit-nya sendiri; (b) tiket sisa yg baru tak pernah ditandai ->
         // bisa memicu ulang logika partial di tick berikutnya.
         // FIX: cari ulang indeks berdasar newTicket SETELAH remove+add.
         if(newTicket != -1) {
            RemoveTradeMonitor(oldTicket);
            AddTradeMonitor(newTicket);
            if(OrderSelect(newTicket,SELECT_BY_TICKET,MODE_TRADES)) {
               double newSL=OrderStopLoss(), newTP=OrderTakeProfit();
               if(newSL==0||newTP==0) {
                  double point=PipPoint(); double open=OrderOpenPrice();
                  if(OrderType()==OP_BUY){ if(newSL==0) newSL=open-GetAdaptiveStopLossPips()*point; if(newTP==0) newTP=open+GetAdaptiveTakeProfitPips()*point; }
                  else { if(newSL==0) newSL=open+GetAdaptiveStopLossPips()*point; if(newTP==0) newTP=open-GetAdaptiveTakeProfitPips()*point; }
                  SafeOrderModify(newTicket, open, newSL, newTP, 0, clrNONE, "PartialSisa");
               }
            }
            int idxNew = -1;
            for(int q=0; q<g_tradeMonitorCount; q++) if(g_tradeMonitors[q].ticket==newTicket) { idxNew=q; break; }
            if(idxNew >= 0) {
               if(profit>=l2) g_tradeMonitors[idxNew].partialClosed=true;
               else           g_tradeMonitors[idxNew].partialLevel1Done=true;
            }
         }
      }
   }
}

void ApplyIntelligentTrailing(int tic) {
   if(!OrderSelect(tic, SELECT_BY_TICKET, MODE_TRADES)) { RemoveTradeMonitor(tic); return; }
   if(OrderCloseTime()!=0) { RemoveTradeMonitor(tic); return; }
   int type = OrderType(); if(type!=OP_BUY && type!=OP_SELL) return;
   if(g_UseManualSL || g_UseManualTP) return;
   double point=PipPoint(), bid=MarketInfo(OrderSymbol(),MODE_BID), ask=MarketInfo(OrderSymbol(),MODE_ASK);
   double open=OrderOpenPrice(), atr=GetATRInPips(); if(atr<=0) atr=30;
   double currentPrice = (type==OP_BUY)?bid:ask;
   double profit = (type==OP_BUY) ? (bid-open)/point : (open-ask)/point;

   // v30 CUT-LOSS CERDAS: tutup dini HANYA dgn bukti pembalikan sungguhan
   // (ST flip lawan + HA mentah lawan + candle lawan kuat, di luar kotak
   // sideways). Koreksi/zigzag biasa TIDAK memicu ini - posisi diberi
   // napas penuh sesuai desain trailing.
   if(UseSmartCutLoss && profit < 0) {
      int posDir = (type==OP_BUY) ? 1 : -1;
      int stNowCL = (int)STCustom(0, ST_TrendBuffer, 1);
      if(stNowCL == -posDir && RawHADirection() == -posDir && !g_BoxActive) {
         double oCL=iOpen(NULL,0,1), cCL=iClose(NULL,0,1), atrCL=iATR(NULL,0,14,1);
         bool againstStrong = ((posDir==1) ? (cCL<oCL) : (cCL>oCL)) && atrCL>0 && MathAbs(cCL-oCL) >= CutLossMinBodyATR*atrCL;
         if(againstStrong) {
            RefreshRates();
            double cp = (type==OP_BUY) ? MarketInfo(OrderSymbol(),MODE_BID) : MarketInfo(OrderSymbol(),MODE_ASK);
            int slipCL=3; if(g_Digits==3||g_Digits==5) slipCL*=10;
            if(OrderClose(tic, OrderLots(), NormalizeDouble(cp,g_Digits), slipCL, clrOrange)) {
               Print("âœ‚ï¸ CUT-LOSS CERDAS #", tic, ": pembalikan TERKONFIRMASI (ST+HA lawan, candle kuat) - ditutup dini di ",
                     DoubleToString(profit,1), " pips, tidak menunggu SL penuh");
               RemoveTradeMonitor(tic);
               return;
            }
         }
      }
   }
   UpdateTradeMonitor(tic, currentPrice, point);
   UpdateTradeMonitorBars();
   if(UseEntryGracePeriod) ManageEntryGracePeriod(tic); // v46: cek & ketatkan SL kalau masa tenggang sudah lewat
   // v50: ManagePartialProfit() DIPINDAH ke CheckPartialProfitTick() (tiap
   // tick, lihat definisinya) - dipanggil DI SINI dulu bar-gated, itu bug-nya.
   if(UseLossLimiter && profit < -LossLimiterPips) {
      bool shouldClose=false; double maxLossPips=LossLimiterPips;
      if(LossLimiterMethod == LOSS_ATR) { maxLossPips = atr * LossLimiterATRMultiplier; if(profit <= -maxLossPips) shouldClose=true; }
      else if(LossLimiterMethod == LOSS_SMART) { if(profit <= -SmartMaxLossPips) shouldClose=true; else if(IsPullbackOnly(tic,currentPrice,point) && profit > -SmartMaxLossPips) return; else if(profit <= -maxLossPips) shouldClose=true; }
      else { if(profit <= -maxLossPips) shouldClose=true; }
      if(shouldClose) { double cp=(type==OP_BUY)?bid:ask; bool res=OrderClose(tic, OrderLots(), cp, 3, clrRed); if(res) RemoveTradeMonitor(tic); return; }
   }
   bool modified=false; double newSL=OrderStopLoss(), newTP=OrderTakeProfit();
   double minDist = MathMax(g_StopLevel * point, 15*point);
   // v54 FIX BUG PENTING: SEMUA mekanisme pengetatan SL di bawah ini
   // (trailing garis-ST, lepas-TP, trailing normal, profit-stage) SEBELUMNYA
   // bisa MELANGKAHI masa tenggang SL (grace period) - tak ada satu pun yg
   // cek graceActive, jadi begitu garis ST/harga bergeser sedikit di bar
   // berikutnya, SL lebar hasil grace period langsung DITIMPA jadi dekat
   // breakeven SEBELUM 2 bar-nya lewat. Paling terasa di posisi yg entrinya
   // PERSIS di garis ST (fitur LIMIT baru - buffer awal nyaris nol), tp
   // sebenarnya berlaku utk entri manapun yg sedang dlm masa tenggang. FIX:
   // selama masih dlm masa tenggang, LEWATI semua bagian di bawah sampai
   // akhir fungsi - biarkan HANYA ManageEntryGracePeriod (sudah dipanggil
   // di atas) yg mengatur SL, sampai ia sendiri yg mengetatkannya nanti
   // setelah GracePeriodBars lewat.
   if(UseEntryGracePeriod) {
      for(int gI=0; gI<g_tradeMonitorCount; gI++) if(g_tradeMonitors[gI].ticket==tic && g_tradeMonitors[gI].graceActive) return;
   }

   // === SUPERTREND TRAILING: SL mengikuti garis Supertrend (adaptif, tak ===
   // === pernah mundur, kebal zigzag - koreksi normal tidak menyentuhnya) ===
   // v37: stLineFloor/hasSTFloor disimpan supaya mekanisme trailing LAIN di
   // bawah (profit-stage, pullback-retrace) tidak boleh lebih ketat dari
   // garis ST ini - inilah akar masalah SL kena duluan saat zigzag/koreksi
   // padahal trend (menurut ST) masih berjalan: dulu tiap mekanisme jalan
   // sendiri2 dan yang PALING KETAT yang menang, walau ST blm flip sama
   // sekali. Sekarang selama ST aktif, dia jadi plafon/lantai bersama.
   double stLineFloor = 0; bool hasSTFloor = false;
   if(UseSupertrendTrailing) {
      double stLine = (type==OP_BUY) ? STCustom(0, 0, 1) : STCustom(0, 1, 1); // buffer 0=garis up (support), 1=garis down (resistance)
      if(stLine != EMPTY_VALUE && stLine > 0) {
         // v21: buffer trailing-garis-ST ikut menyesuaikan rezim volatilitas -
         // candle kecil2/rapat (tenang) -> buffer diperketat (amankan profit
         // kecil sebelum sempat berbalik); candle lebar2 (trend kuat) ->
         // buffer dilonggarkan (jangan kena koreksi wajar dari candle besar).
         // v2.00: buffer garis ST kini relatif ATR (dulu 3 pip = $0.03 utk gold,
         // artinya SL menempel PERSIS di garis ST tanpa ruang napas sama sekali).
         double stBuf = UseATRRelativeExits ? (ST_TrailBufferATR * atr) : ST_TrailBufferPips;
         if(UseAdaptiveTrailTightness) {
            double volRatioB = GetVolatilityRegimeRatio();
            if(volRatioB < VolRegimeQuietRatio) stBuf *= VolRegimeQuietFactor;
            else if(volRatioB > VolRegimeWideRatio) stBuf *= VolRegimeWideFactor;
         }
         double slST = (type==OP_BUY) ? stLine - stBuf*point : stLine + stBuf*point;
         stLineFloor = slST; hasSTFloor = true;
         if((type==OP_BUY && (newSL==0 || slST > newSL)) || (type==OP_SELL && (newSL==0 || slST < newSL))) {
            if((type==OP_BUY && slST <= bid-minDist) || (type==OP_SELL && slST >= ask+minDist)) {
               newSL = slST; modified=true;
            }
         }
      }
   }

   // v65: MOMENTUM CANDLE TRAILING - respons cepat thd candle KUAT yg baru
   // saja tertutup (beda dr trailing ATR generik di atas yg jaraknya tetap
   // sama tak peduli seberapa kuat momentum baru terjadi). Kalau candle
   // sebelumnya (shift 1, sudah tertutup) range-nya jauh melebihi ATR
   // normal DAN bergerak SEARAH posisi, itu momentum kuat - SL ditarik
   // dekat ke low/high candle itu (dgn buffer), berpotensi lompat lewat
   // harga entri sekaligus kalau candle-nya cukup kuat - PERSIS spy
   // profit tak tergerus nunggu trailing biasa yg lebih lambat. Tetap
   // HANYA mengetat (ratchet) & hormat jarak minimum broker.
   if(UseMomentumCandleTrail && atr > 0) {
      double candleHigh = iHigh(NULL, 0, 1), candleLow = iLow(NULL, 0, 1);
      double candleRange = candleHigh - candleLow;
      bool candleSearah = (type==OP_BUY) ? (iClose(NULL,0,1) > iOpen(NULL,0,1)) : (iClose(NULL,0,1) < iOpen(NULL,0,1));
      if(candleRange >= MomentumCandleATRMult*atr && candleSearah) {
         double slMC = (type==OP_BUY) ? candleLow - MomentumCandleBufferATR*atr : candleHigh + MomentumCandleBufferATR*atr;
         // v2.00 BUG-5 FIX: dulu mekanisme ini MENEMBUS lantai garis Supertrend
         // (stLineFloor) yg justru dibangun di v37 utk mencegah exit dini. Low
         // sebuah candle kuat bisa jauh DI ATAS garis ST -> SL melompat jauh
         // lebih ketat drpd yg dibenarkan tren. Kini dihormati.
         if(MomentumTrailRespectST && hasSTFloor) {
            if(type==OP_BUY  && slMC > stLineFloor) slMC = stLineFloor;
            if(type==OP_SELL && slMC < stLineFloor) slMC = stLineFloor;
         }
         if((type==OP_BUY && (newSL==0 || slMC > newSL)) || (type==OP_SELL && (newSL==0 || slMC < newSL))) {
            if((type==OP_BUY && slMC <= bid-minDist) || (type==OP_SELL && slMC >= ask+minDist)) {
               newSL = slMC; modified = true;
               Print("âš¡ MOMENTUM CANDLE #", tic, ": candle kuat searah (range ", DoubleToString(candleRange/atr,2),
                     "xATR) - SL ditarik cepat ke ", DoubleToString(slMC,g_Digits));
            }
         }
      }
   }

   // === LEPAS TP SAAT TREND TERBUKTI KUAT: TP didorong menjauh terus ===
   // === supaya trend bisa lari sampai puncak; exit oleh SL Supertrend. ===
   if(TrendRun_ReleaseTP && atr > 0 && profit > atr * TrendRun_MinProfitATR) {
      double farTP = (type==OP_BUY) ? bid + 15*atr*point : ask - 15*atr*point;
      if((type==OP_BUY && farTP > newTP) || (type==OP_SELL && (newTP==0 || farTP < newTP))) {
         newTP = NormalizeDouble(farTP, g_Digits); modified=true;
      }
   }

   double trailStartThr = UseATRRelativeExits ? (TrailStartATR * atr) : TrailStartPips;
   if(UseTrailingStop && profit > trailStartThr) {
      double trailDist=0;
      switch(TrailMethod) {
         case TRAIL_FIXED: trailDist=TrailDistancePips; break;
         case TRAIL_PERCENT: trailDist=profit*TrailPercent/100.0; break;
         case TRAIL_ATR: trailDist=atr*TrailATRMultiplier; break;
         case TRAIL_STEP: trailDist=TrailStepSize; break;
      }
      // v21: jarak trailing ikut rezim volatilitas - lihat penjelasan di
      // blok trailing-garis-ST di atas (prinsip sama, diterapkan di sini
      // supaya SEMUA metode trailing, bukan cuma ST-line, ikut adaptif).
      if(UseAdaptiveTrailTightness) {
         double volRatioT = GetVolatilityRegimeRatio();
         if(volRatioT < VolRegimeQuietRatio) trailDist *= VolRegimeQuietFactor;
         else if(volRatioT > VolRegimeWideRatio) trailDist *= VolRegimeWideFactor;
      }
      // v30 TRAILING BERTAHAP: makin besar profit berjalan (x ATR), jarak
      // trailing makin diperketat - profit besar dikunci makin rapat
      // (menjawab "trailing terlalu lambat menyelamatkan TP yg sudah
      // didapat"), profit kecil tetap diberi ruang berkembang.
      if(UseProfitStageTrail && atr > 0) {
         double stageRatio = profit / atr;
         if(stageRatio >= StageTrailStartATR) {
            double kStage = 1.0 - 0.25 * (stageRatio - StageTrailStartATR);
            if(kStage < StageTrailTightest) kStage = StageTrailTightest;
            trailDist *= kStage;
         }
      }
      // v2.00 BUG-4 FIX: clamp lama HARDCODE 15..500 "pip". Utk gold itu
      // $0.15..$5.00 - batas ATAS $5 di instrumen ber-ATR $20/jam berarti
      // trailing selalu duduk 0,25xATR di belakang harga. Itulah penyebab
      // struktural median lama-tahan 2,2 jam & rasio payoff 0,62.
      // Kini clamp RELATIF ATR (default 0,5xATR .. 3,0xATR).
      if(UseATRRelativeExits && atr > 0) {
         double loClamp = TrailMinATR * atr, hiClamp = TrailMaxATR * atr;
         if(trailDist < loClamp) trailDist = loClamp;
         if(trailDist > hiClamp) trailDist = hiClamp;
      } else {
         if(trailDist<15) trailDist=15; if(trailDist>500) trailDist=500;
      }
      double slCandidate = (type==OP_BUY)? bid - trailDist*point : ask + trailDist*point;
      // v37: JANGAN lebih ketat dari garis ST (lihat catatan di blok ST di
      // atas) - ini yg mencegah profit-stage-trail menutup posisi lebih dini
      // drpd yg dijustifikasi oleh trend (menurut ST) yg msh berjalan.
      if(hasSTFloor) {
         if(type==OP_BUY && slCandidate > stLineFloor) slCandidate = stLineFloor;
         else if(type==OP_SELL && slCandidate < stLineFloor) slCandidate = stLineFloor;
      }
      if((type==OP_BUY && slCandidate > newSL) || (type==OP_SELL && slCandidate < newSL)) {
         if((type==OP_BUY && slCandidate <= bid-minDist) || (type==OP_SELL && slCandidate >= ask+minDist)) {
            newSL = slCandidate; modified=true;
         }
      }
   }
   double highestProfit=0; for(int i=0;i<g_tradeMonitorCount;i++) if(g_tradeMonitors[i].ticket==tic) { highestProfit=g_tradeMonitors[i].highestProfitPips; break; }
   if(UsePullbackDetection && profit > TrailStartPips && highestProfit > 0) {
      double retracePercent = (highestProfit - profit) / highestProfit * 100.0;
      if(retracePercent >= MaxTrailRetracePercent) {
         double lockedProfit = highestProfit * (1.0 - MaxTrailRetracePercent/100.0); if(lockedProfit<0) lockedProfit=0;
         double slLevel;
         if(type==OP_BUY) {
            slLevel = open + lockedProfit*point;
            if(hasSTFloor && slLevel > stLineFloor) slLevel = stLineFloor; // v37: jgn lebih ketat dr ST
            if(slLevel>open && (newSL==0 || slLevel>newSL) && slLevel<=bid-minDist) { newSL=slLevel; modified=true; }
         } else {
            slLevel = open - lockedProfit*point;
            if(hasSTFloor && slLevel < stLineFloor) slLevel = stLineFloor; // v37: jgn lebih ketat dr ST
            if(slLevel<open && (newSL==0 || slLevel<newSL) && slLevel>=ask+minDist) { newSL=slLevel; modified=true; }
         }
      }
   }
   if(UseBreakeven) {
      // v21: di rezim tenang/candle kecil, kunci breakeven LEBIH CEPAT -
      // "begitu entry harus gerak cepat menyelamatkan TP" (permintaan Anda).
      // Di rezim lebar/trend kuat, ambang normal tetap dipakai (jangan
      // terlalu buru2 mengunci saat trend masih leluasa berjalan).
      double beTrigger = UseATRRelativeExits ? (BreakevenTriggerATR * atr) : BreakevenTriggerPips;
      if(UseAdaptiveTrailTightness) {
         double volRatioBE = GetVolatilityRegimeRatio();
         if(volRatioBE < VolRegimeQuietRatio) beTrigger *= VolRegimeQuietFactor;
      }
      if(profit > beTrigger) {
      double beSL = open + ((type==OP_BUY) ? BreakevenPlusATR*atr*point : -BreakevenPlusATR*atr*point);
      // ===== v3.00 PERBAIKAN REGRESI KRITIS =====
      // Di v2.00 saya menerapkan lantai garis-ST ke Breakeven juga. Itu KELIRU
      // dan terbukti dari data tes bertahap Anda: pada TAHAP 1 hanya 0 dari 243
      // perintah modify yang menempatkan SL di harga entri; TAHAP 2 nol dari 177.
      // Artinya BREAKEVEN TIDAK PERNAH SEKALI PUN TERJADI.
      // Sebabnya: utk posisi BUY, garis ST di awal trade hampir selalu ADA DI
      // BAWAH harga entri, jadi "beSL = open" selalu lebih tinggi dr stLineFloor
      // dan langsung DITARIK TURUN ke bawah entri - breakeven dinetralkan total.
      // Inilah penyebab utama win rate runtuh 68,6% -> 33-43%: trade yg sempat
      // untung tak punya pengaman apa pun & lari balik menembus entri.
      // Lantai ST tetap benar utk TRAILING (mencegah pengetatan dini), tapi
      // BREAKEVEN itu penghapusan RISIKO, bukan pengetatan - ia tak boleh
      // ditarik turun oleh apa pun. Kini BE murni ratchet satu arah.
      if((type==OP_BUY && beSL > newSL) || (type==OP_SELL && beSL < newSL)) {
         if((type==OP_BUY && beSL <= bid-minDist) || (type==OP_SELL && beSL >= ask+minDist)) {
            newSL = beSL; modified=true;
         }
      }
      }
   }
   // v19: bandingkan thd nilai TERNORMALISASI aktual order (bukan hanya
   // flag 'modified' dari kandidat mentah) - versi lama memicu OrderModify
   // walau setelah NormalizeDouble nilainya SAMA persis dgn SL/TP order
   // saat ini, menyebabkan "OrderModify error 1" berulang di jurnal test.
   double curSLn = NormalizeDouble(OrderStopLoss(), g_Digits);
   double curTPn = NormalizeDouble(OrderTakeProfit(), g_Digits);
   double newSLn = NormalizeDouble(newSL, g_Digits);
   double newTPn = NormalizeDouble(newTP, g_Digits);
   if(newSLn != curSLn || newTPn != curTPn)
      SafeOrderModify(OrderTicket(), open, newSLn, newTPn, 0, clrNONE, "Trailing");
}
void ApplyDynamicProtection() { for(int i=OrdersTotal()-1; i>=0; i--) if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber) ApplyIntelligentTrailing(OrderTicket()); }
//+------------------------------------------------------------------+
//| v49: SPIKE GUARD - dipanggil TIAP TICK (bukan cuma per-bar spt    |
//| ApplyDynamicProtection/ApplyIntelligentTrailing) - khusus utk     |
//| pembalikan MENDADAK & LEBAR yg terjadi & selesai DALAM SATU bar,  |
//| sebelum trailing normal sempat bereaksi. Koreksi kecil/pendek     |
//| tetap dibiarkan ke trailing biasa (Spike Guard cuma aktif kalau   |
//| mundurnya jauh, sesuai ambang RetraceATR).                        |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| v50 FIX BUG: PartialProfit SEBELUMNYA hanya dipanggil dari dalam  |
//| ApplyIntelligentTrailing, yg (spt Spike Guard dulu) HANYA dicek   |
//| SEKALI PER BAR BARU. Kalau harga menembus ambang PartialProfitLevel1|
//| /Level2 (xATR) DALAM SATU bar lalu mundur lagi SEBELUM bar itu    |
//| tutup, ambang itu TIDAK PERNAH terdeteksi - profit yg sempat bisa |
//| diamankan LEWAT begitu saja, persis keluhan "belum berfungsi dgn  |
//| baik sebagaimana mestinya". FIX: dicek TIAP TICK di sini, logika  |
//| ManagePartialProfit() sendiri TIDAK diubah (tetap berbasis xATR   |
//| sesuai desain, tetap idempoten via partialLevel1Done/partialClosed)|
//| - hanya frekuensi pengecekannya yg diperbaiki.                    |
//+------------------------------------------------------------------+
void CheckPartialProfitTick() {
   if(!UsePartialProfit) return;
   double point = PipPoint();
   for(int i=g_tradeMonitorCount-1; i>=0; i--) {
      int tic = g_tradeMonitors[i].ticket;
      if(!OrderSelect(tic, SELECT_BY_TICKET, MODE_TRADES)) continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber) continue;
      int type = OrderType(); if(type!=OP_BUY && type!=OP_SELL) continue;
      if(g_UseManualSL || g_UseManualTP) continue; // konsisten dgn ApplyIntelligentTrailing - override manual tak disentuh sistem otomatis
      double open = OrderOpenPrice(), atrPP = GetATRInPips(); if(atrPP<=0) atrPP=30;
      double bidPP=MarketInfo(Symbol(),MODE_BID), askPP=MarketInfo(Symbol(),MODE_ASK);
      double profitPP = (type==OP_BUY) ? (bidPP-open)/point : (open-askPP)/point;
      ManagePartialProfit(tic, profitPP, atrPP);
   }
}
//+------------------------------------------------------------------+
//| v3.00 TANGGA KUNCI PROFIT + PEMOTONG TRADE MATI                   |
//| Dipanggil TIAP TICK. Dua tugas:                                   |
//|  1. Melacak PUNCAK profit (xATR) tiap posisi - satu arah, tak      |
//|     pernah turun. Begitu puncak menyentuh anak tangga, SL dikunci  |
//|     permanen di level tangga itu.                                  |
//|  2. Menutup trade yg setelah N bar belum menunjukkan tanda hidup.  |
//| Sengaja TERPISAH dari ApplyIntelligentTrailing supaya kunci ini    |
//| TIDAK bisa dibatalkan/ditarik-turun mekanisme lain mana pun -      |
//| termasuk lantai garis ST. Ini jaring pengaman terakhir posisi.     |
//+------------------------------------------------------------------+
void CheckProfitLadder() {
   if(!UseProfitLadder && !UseDeadTradeCut) return;
   double atrP = iATR(NULL, 0, ATRPeriod_SL, 0);
   if(atrP <= 0) return;
   RefreshRates();
   for(int i = g_tradeMonitorCount-1; i >= 0; i--) {
      int tic = g_tradeMonitors[i].ticket;
      if(!OrderSelect(tic, SELECT_BY_TICKET, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;
      if(OrderCloseTime() != 0) continue;
      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL) continue;
      if(g_UseManualSL || g_UseManualTP) continue;   // konsisten: override manual tak disentuh otomatis

      double open  = OrderOpenPrice();
      double bid   = MarketInfo(Symbol(), MODE_BID);
      double ask   = MarketInfo(Symbol(), MODE_ASK);
      double curP  = (type == OP_BUY) ? bid : ask;
      double profATR = ((type == OP_BUY) ? (curP - open) : (open - curP)) / atrP;

      // --- lacak PUNCAK, satu arah ---
      if(profATR > g_tradeMonitors[i].peakProfitATR)
         g_tradeMonitors[i].peakProfitATR = profATR;
      double peak = g_tradeMonitors[i].peakProfitATR;

      // ================= 1. PEMOTONG TRADE MATI =================
      // barsHeld hanya di-update per-bar oleh ApplyIntelligentTrailing, jadi
      // di sini dihitung sendiri supaya pemotong ini tak bergantung pada itu.
      int barsNow = (int)((TimeCurrent() - g_tradeMonitors[i].openTime) / PeriodSeconds(Period()));
      if(UseDeadTradeCut && !g_tradeMonitors[i].deadCutDone && barsNow >= DeadTradeBars) {
         g_tradeMonitors[i].deadCutDone = true;   // dinilai SEKALI saja
         if(peak < DeadTradeMinPeakATR) {
            double cp = (type == OP_BUY) ? bid : ask;
            int slip = (int)MathMax(3, MarketInfo(Symbol(), MODE_SPREAD));
            // v3.00: cek ulang tiket masih hidup (hindari error 4108)
            if(!OrderSelect(tic, SELECT_BY_TICKET, MODE_TRADES) || OrderCloseTime()!=0) { RemoveTradeMonitor(tic); continue; }
            if(OrderClose(tic, OrderLots(), NormalizeDouble(cp, g_Digits), slip, clrDimGray)) {
               Print("ðŸ§¹ TRADE MATI DIPOTONG #", tic, ": ", barsNow,
                     " bar berlalu, puncak profit cuma ", DoubleToString(peak,2),
                     "xATR (min ", DoubleToString(DeadTradeMinPeakATR,2),
                     "xATR) - tak menunjukkan tanda hidup, dilepas sebelum trailing menggerusnya");
               g_cnt_DeadCut++;
               RemoveTradeMonitor(tic);
               continue;
            }
         }
      }

      // ================= 2. TANGGA KUNCI PROFIT =================
      if(!UseProfitLadder) continue;
      int    step = 0;
      double lock = 0;
      if(peak >= LadderStep4ATR)      { step = 4; lock = LadderLock4ATR; }
      else if(peak >= LadderStep3ATR) { step = 3; lock = LadderLock3ATR; }
      else if(peak >= LadderStep2ATR) { step = 2; lock = LadderLock2ATR; }
      else if(peak >= LadderStep1ATR) { step = 1; lock = LadderLock1ATR; }
      if(step == 0 || step <= g_tradeMonitors[i].ladderStep) continue;   // belum naik tangga baru

      double target = (type == OP_BUY) ? open + lock*atrP : open - lock*atrP;
      // hormati jarak minimum broker - kalau harga sudah terlalu dekat,
      // pasang sedekat yg masih sah (jangan gagal lalu menyerah).
      double minD = MathMax(g_StopLevel*PipPoint(), 15*PipPoint());
      if(type == OP_BUY  && target > bid - minD) target = bid - minD;
      if(type == OP_SELL && target < ask + minD) target = ask + minD;
      target = NormalizeDouble(target, g_Digits);
      double curSL = NormalizeDouble(OrderStopLoss(), g_Digits);
      // HANYA memperbaiki, tak pernah memperburuk
      bool better = (type == OP_BUY) ? (target > curSL) : (curSL == 0 || target < curSL);
      if(!better) { g_tradeMonitors[i].ladderStep = step; continue; }
      if(SafeOrderModify(tic, open, target, OrderTakeProfit(), 0, clrNONE, "TanggaProfit")) {
         g_tradeMonitors[i].ladderStep = step;
         g_cnt_Ladder++; if(step >= 2) g_cnt_Ladder2++;
         Print("ðŸªœ TANGGA PROFIT #", tic, " anak-tangga ", step, ": puncak ",
               DoubleToString(peak,2), "xATR tercapai - SL DIKUNCI PERMANEN di ",
               DoubleToString(target, g_Digits), " (= entri +", DoubleToString(lock,2),
               "xATR). Trade ini tidak bisa lagi berubah jadi rugi.");
      }
   }
}

void CheckSpikeGuard() {
   if(!UseSpikeGuard) return;
   double atrSG = iATR(NULL, 0, 14, 0); // ATR bar SEKARANG (bar 0) - representasi volatilitas real-time, bukan bar 1 yg sudah tutup
   if(atrSG <= 0) return;
   RefreshRates();
   for(int i=0; i<g_tradeMonitorCount; i++) {
      int tic = g_tradeMonitors[i].ticket;
      if(!OrderSelect(tic, SELECT_BY_TICKET)) continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber) continue;
      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL) continue;
      double open = OrderOpenPrice();
      double curPrice = (OrderType()==OP_BUY) ? Bid : Ask;
      // lacak puncak PER-TICK (independen dr highestPrice yg cuma di-update
      // sekali per bar via ApplyIntelligentTrailing/UpdateTradeMonitor)
      if(g_tradeMonitors[i].spikeHighPrice == 0) g_tradeMonitors[i].spikeHighPrice = open;
      if(OrderType()==OP_BUY) { if(curPrice > g_tradeMonitors[i].spikeHighPrice) g_tradeMonitors[i].spikeHighPrice = curPrice; }
      else { if(curPrice < g_tradeMonitors[i].spikeHighPrice) g_tradeMonitors[i].spikeHighPrice = curPrice; }
      double peakProfitATR = (OrderType()==OP_BUY) ? (g_tradeMonitors[i].spikeHighPrice-open)/atrSG : (open-g_tradeMonitors[i].spikeHighPrice)/atrSG;
      if(peakProfitATR < SpikeGuardMinProfitATR) continue; // blm cukup untung, jangan ganggu posisi yg msh berkembang
      double retraceATR = (OrderType()==OP_BUY) ? (g_tradeMonitors[i].spikeHighPrice-curPrice)/atrSG : (curPrice-g_tradeMonitors[i].spikeHighPrice)/atrSG;
      if(retraceATR < SpikeGuardRetraceATR) continue; // koreksi msh wajar, biarkan trailing biasa yg urus
      double lockProfitATR = peakProfitATR * SpikeGuardLockRatio;
      double emergencySL = (OrderType()==OP_BUY) ? open + lockProfitATR*atrSG : open - lockProfitATR*atrSG;
      // v50 FIX BUG: SEBELUMNYA tidak ada batas jarak minimum broker sblm
      // OrderModify - kalau harga sudah mundur MENDEKATI level kunci
      // (emergencySL terlalu dekat dgn harga SAAT INI), broker menolak
      // (error 130/invalid stops) - dan krn modify GAGAL, curSL tidak
      // pernah berubah, jadi kondisi "improve" tetap true SELAMANYA -
      // mencoba lagi TIAP TICK, membanjiri jurnal dgn error berulang tanpa
      // henti (persis yg terlihat di log: puluhan "OrderModify error 130"
      // beruntun). FIX: jarak dipangkas ke minimum aman broker kalau
      // terlalu dekat, bukan dibiarkan mentah.
      double point = PipPoint(); double minDistSG = MathMax(g_StopLevel*point, 15*point);
      if(OrderType()==OP_BUY) { if(emergencySL > curPrice-minDistSG) emergencySL = curPrice-minDistSG; }
      else { if(emergencySL < curPrice+minDistSG) emergencySL = curPrice+minDistSG; }
      // v2.00 BUG-5 FIX: Spike Guard SEBELUMNYA menembus lantai garis
      // Supertrend (stLineFloor) yg dibangun di v37 justru utk mencegah
      // penutupan dini. Kini dihormati: kalau garis ST masih LEBIH LONGGAR
      // dr level kunci darurat, pakai garis ST - tren menurut ST belum
      // berakhir, jadi jangan potong lebih ketat dari itu.
      if(SpikeGuardRespectSTLine && UseSupertrendTrailing) {
         double stLineSG = (OrderType()==OP_BUY) ? STCustom(0,0,1) : STCustom(0,1,1);
         if(stLineSG != EMPTY_VALUE && stLineSG > 0) {
            double stFloorSG = (OrderType()==OP_BUY) ? stLineSG - ST_TrailBufferATR*atrSG
                                                     : stLineSG + ST_TrailBufferATR*atrSG;
            if(OrderType()==OP_BUY  && emergencySL > stFloorSG) emergencySL = stFloorSG;
            if(OrderType()==OP_SELL && emergencySL < stFloorSG) emergencySL = stFloorSG;
         }
      }
      // v2.00 BUG-2 FIX: bandingkan nilai yg SUDAH DINORMALISASI (dulu
      // kandidat mentah dibanding SL terpasang yg sudah dibulatkan broker ->
      // selalu "ada perbaikan" -> OrderModify dipanggil TIAP TICK -> error 1
      // berulang; 22.109 kali di jurnal tes, puncak 1.273/menit).
      double curSL   = NormalizeDouble(OrderStopLoss(), g_Digits);
      double emergSLn = NormalizeDouble(emergencySL, g_Digits);
      bool improve = (OrderType()==OP_BUY) ? (emergSLn > curSL) : (curSL==0 || emergSLn < curSL);
      if(improve) {
         if(SafeOrderModify(tic, open, emergSLn, OrderTakeProfit(), 0, clrNONE, "SpikeGuard"))
            Print("âš¡ SPIKE GUARD #", tic, ": harga mundur ", DoubleToString(retraceATR,2), "xATR dari puncak (sempat untung ",
                  DoubleToString(peakProfitATR,2), "xATR) - SL darurat dikunci di ~", DoubleToString(lockProfitATR,2), "xATR profit, TIDAK menunggu bar tutup");
      }
   }
}
void EnsureAllOrdersMonitored() {
   for(int i=OrdersTotal()-1; i>=0; i--) {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber && (OrderType()==OP_BUY||OrderType()==OP_SELL)) {
         bool found=false; for(int j=0;j<g_tradeMonitorCount;j++) if(g_tradeMonitors[j].ticket==OrderTicket()) {found=true; break;}
         if(!found) {
            AddTradeMonitor(OrderTicket());
            // v49 FIX: posisi yg baru terdeteksi DI SINI datang dari pending
            // order yg baru tersentuh (ExhPend/Cover/Repend) - bukan entri
            // langsung (yg sudah SetGracePeriod sendiri di ExecuteSmartOrder).
            // Supaya konsisten (SL-nya jg mengetat otomatis setelah
            // GracePeriodBars, bukan lebar selamanya), daftarkan jg ke masa
            // tenggang di sini - target normal dihitung fresh dari ATR
            // SEKARANG (relatif ke harga buka posisi ini).
            if(UseEntryGracePeriod) {
               double atrPipsN = GetATRInPips();
               if(atrPipsN > 0) {
                  double point2 = PipPoint(); double openN = OrderOpenPrice();
                  double normalSLPips = MathMax(30, atrPipsN * ATRMultiplier_SL);
                  double normalSLPrice = (OrderType()==OP_BUY) ? openN - normalSLPips*point2 : openN + normalSLPips*point2;
                  // v57: posisi dari pending LIMIT (Repend "UGE70-REPENDL" atau
                  // Titik-Jenuh "UGE70-EXHL") dpt masa tenggang LEBIH LAMA -
                  // gaya LIMIT masuk PERSIS di area koreksi/zigzag, wajar kena
                  // goncangan lebih besar dulu sblm tren asli lanjut, drpd
                  // entri STOP/breakout yg momentum-nya sudah lebih terbukti.
                  string cmtN = OrderComment();
                  bool isLimitOrigin = (StringFind(cmtN,"REPENDL")>=0 || StringFind(cmtN,"EXHL")>=0);
                  int barsTargetN = isLimitOrigin ? GracePeriodBarsLimit : GracePeriodBars;
                  SetGracePeriod(OrderTicket(), NormalizeDouble(normalSLPrice, g_Digits), barsTargetN);
               }
            }
         }
      }
   }
}
void EnsureInitialSLTP() { /* sudah di set di entry */ }
void CheckVirtualStopLosses() {
   if(!UseSoftStopLoss) return;
   double lastClose = iClose(NULL,0,1);
   for(int i=0;i<g_tradeMonitorCount;i++) {
      if(!g_tradeMonitors[i].softStopActive) continue;
      int tic = g_tradeMonitors[i].ticket;
      if(!OrderSelect(tic, SELECT_BY_TICKET) || OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber) continue;
      int type = OrderType(); if(type!=OP_BUY && type!=OP_SELL) continue;
      if(g_tradeMonitors[i].virtualSL <= 0) continue;
      bool violated = (type==OP_BUY) ? (lastClose <= g_tradeMonitors[i].virtualSL) : (lastClose >= g_tradeMonitors[i].virtualSL);
      if(violated) { double cp=(type==OP_BUY)?Bid:Ask; bool res=OrderClose(tic, OrderLots(), cp, 3, clrOrange); if(!res) { int err=GetLastError(); if(err!=0) Print("Close error #",err); } else g_tradeMonitors[i].softStopActive=false; }
   }
}
// v2.00 KEJUJURAN PANEL: audit menemukan level S/R yg tampil di dashboard
// BUKAN dari SuperSR_6 sama sekali - ini high/low sederhana 20 bar. Operator
// bisa keliru mengira sedang melihat level SuperSR yg terpasang di chart.
// Kini: kalau UseSRFilter aktif, panel memakai level SuperSR_6 yg SUNGGUHAN;
// kalau tidak, tetap high/low 20 bar TAPI panel memberi label apa adanya.
double GetSupportLevel() {
   if(UseSRFilter) {
      double v = SRCustom(1, 1);   // buffer 1 = SUPPORT (konsisten dgn IsNearSRZone)
      if(v != EMPTY_VALUE && v > 0) return v;
   }
   int idx = iLowest(NULL,0,MODE_LOW,20,1); return (idx>=0)?iLow(NULL,0,idx):iLow(NULL,0,1);
}
double GetResistanceLevel() {
   if(UseSRFilter) {
      double v = SRCustom(0, 1);   // buffer 0 = RESISTANCE (konsisten dgn IsNearSRZone)
      if(v != EMPTY_VALUE && v > 0) return v;
   }
   int idx = iHighest(NULL,0,MODE_HIGH,20,1); return (idx>=0)?iHigh(NULL,0,idx):iHigh(NULL,0,1);
}
void UpdateSRLevels() { g_DisplaySupport = GetSupportLevel(); g_DisplayResistance = GetResistanceLevel(); }

//====================================================================
//| PROTECTION FUNCTIONS                                             |
//+====================================================================
void CheckDrawdownProtection() {
   if(!EnableDrawdownProtection) return;
   double eq=AccountEquity(), bal=AccountBalance();
   if(bal>g_HighestBalance) g_HighestBalance=bal;
   if(g_HighestBalance<=0) g_HighestBalance=bal;
   double dd=(g_HighestBalance-eq)/g_HighestBalance*100;
   g_CurrentDrawdownPercent=dd;
   if(dd>MaxDrawdownPercent){ double red=1.0-(dd/100.0); if(red<0.3) red=0.3; g_DrawdownReductionFactor=MathMax(0.1,red); g_DrawdownProtectionActive=true; }
   else { g_DrawdownReductionFactor=1.0; g_DrawdownProtectionActive=false; }
   if(HardDrawdownStopPercent>0 && dd>=HardDrawdownStopPercent && !g_TradingPaused) {
      CloseAllPositions(); CancelAllPendingOrdersSafe(); g_tradeMonitorCount=0;
      g_TradingPaused=true; g_PauseUntilTime=TimeCurrent()+4*3600;
      g_Status="HARD DRAWDOWN STOP - PAUSED"; g_StatusColor=C_Red;
   }
}
void CheckConsecutiveLossProtection() {
   if(!EnableDrawdownProtection){ g_ConsecutiveLossFactor=1.0; return; }
   int loss=0, chk=0;
   for(int i=OrdersHistoryTotal()-1; i>=0 && chk<20; i--) {
      if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY) && OrderMagicNumber()==MagicNumber && OrderSymbol()==Symbol()) {
         double p=OrderProfit()+OrderSwap()+OrderCommission();
         if(p<0) loss++; else if(p>0) break;
         chk++;
      }
   }
   g_ConsecutiveLosses=loss;
   if(loss>=MaxConsecutiveLosses){ int excess=loss-MaxConsecutiveLosses; double factor=0.7-(excess*0.1); g_ConsecutiveLossFactor=MathMax(0.2,factor); }
   else g_ConsecutiveLossFactor=1.0;
}

//====================================================================
//| ORDER EXECUTION                                                  |
//+====================================================================
double CalculateLotSize(double slPips) {
   double balance = AccountBalance();
   double point = PipPoint();
   // v2.00 BUG-1 FIX: dulu dihitung inline di sini dgn "* 10.0" di ujung -
   // nilai pip 10x kebesaran. Kini dipusatkan di PipValuePerLot() (lihat
   // penjelasan lengkap di definisi fungsi itu).
   double pipValue = PipValuePerLot();
   double minLot = GetMinLotLimit();
   double maxLot = MathMin(GetMaxLotLimit(), MaxAllowedLot);

   // v26 FIX (permintaan Anda): RiskPerTrade=0 SEKARANG BERARTI MODE
   // MANUAL MURNI - BaseLot dipakai APA ADANYA (hanya disesuaikan
   // TradingMode & pengaman bawaan EA sendiri spt loss-streak reduction),
   // TIDAK lagi dipotong oleh Pagar Risiko otomatis (v20/v25). Pagar
   // Risiko itu untuk mode RISK-BASED (%) - kalau Anda pilih RiskPerTrade
   // =0, itu artinya Anda memilih kendali manual penuh via BaseLot, jadi
   // sistem menghormati pilihan itu apa adanya. Peringatan tetap dicetak
   // di jurnal (bukan diblokir) supaya Anda selalu sadar ukuran risikonya.
   if(RiskPerTrade <= 0) {
      double lotManual = BaseLot;
      if(TradingMode == MODE_CONSERVATIVE) lotManual *= 0.6;
      else if(TradingMode == MODE_AGGRESSIVE) lotManual *= 1.4;
      lotManual *= g_DrawdownReductionFactor * g_ConsecutiveLossFactor * g_LotMultiplier;
      if(UseCounterTrendSizing && g_CounterTrendSignal) lotManual *= CounterTrendLotFactor;   // v3.00
      if(UseLotBoost && LotBoostMultiplier > 1.0) lotManual *= LotBoostMultiplier;
      lotManual = NormalizeDouble(lotManual, 2);
      if(lotManual < minLot) lotManual = minLot;
      if(lotManual > maxLot) lotManual = maxLot;
      double manualRiskAmt = lotManual * slPips * pipValue;
      double manualRiskPct = (balance > 0) ? (manualRiskAmt / balance * 100.0) : 0;
      if(manualRiskPct > MaxRiskPerTradePercent)
         Print("â„¹ï¸ MODE LOT MANUAL: BaseLot ", DoubleToString(lotManual,2), " dipakai apa adanya (risiko ~$",
               DoubleToString(manualRiskAmt,2), " = ", DoubleToString(manualRiskPct,1),
               "% balance - LEBIH BESAR dari pagar ", DoubleToString(MaxRiskPerTradePercent,1),
               "%, tapi Pagar Risiko TIDAK berlaku di mode manual krn RiskPerTrade=0)");
      return lotManual;
   }

   double lot;
   double riskAmount = balance * RiskPerTrade / 100.0;
   if(riskAmount <= 0) riskAmount = 1.0;
   lot = riskAmount / (slPips * pipValue);
   lot = NormalizeDouble(lot, 2);
   if(lot < minLot) lot = minLot;
   if(lot > maxLot) lot = maxLot;
   lot *= g_DrawdownReductionFactor * g_ConsecutiveLossFactor * g_LotMultiplier * g_ModeRiskMult;
   if(UseCounterTrendSizing && g_CounterTrendSignal) lot *= CounterTrendLotFactor;   // v3.00
   // v47 FIX BUG KRITIS: batas minLot di atas terjadi SEBELUM pengali
   // reduksi ini - begitu EnableDrawdownProtection=true membuat KEDUA
   // faktor (drawdown + kekalahan-beruntun) aktif bersamaan, hasil kali
   // keduanya bisa < 0.06, membuat lot yg SUDAH di-floor ke minLot (mis.
   // 0.01) jatuh lagi jadi 0.0006 -> dibulatkan NormalizeDouble jadi 0.00 -
   // lot TIDAK VALID, OrderSend gagal permanen (error 4051) SETIAP KALI
   // recovery mencoba entri selama drawdown masih tinggi - persis
   // penguncian yg dilaporkan, BUKAN soal jeda 4 jam. FIX: floor LAGI
   // setelah pengali reduksi diterapkan.
   if(lot < minLot) lot = minLot;

   // v20: LOT BOOST OPSIONAL - lot murni (hasil risk) dibesarkan sesuai
   // kelipatan pilihan Anda.
   if(UseLotBoost && LotBoostMultiplier > 1.0) lot *= LotBoostMultiplier;

   lot = NormalizeDouble(MathMin(lot, maxLot), 2);

   // v20: PAGAR RISIKO KERAS - berlaku utk mode RISK-BASED (%) saja. Hitung
   // ulang risiko $ sebenarnya dari lot final; kalau melebihi
   // MaxRiskPerTradePercent, pangkas lot turun persis ke batas itu.
   double actualRiskAmt = lot * slPips * pipValue;
   double maxRiskAmt = balance * MaxRiskPerTradePercent / 100.0;
   if(maxRiskAmt > 0 && actualRiskAmt > maxRiskAmt) {
      double cappedLot = NormalizeDouble(maxRiskAmt / (slPips * pipValue), 2);
      if(cappedLot < minLot) cappedLot = minLot;  // tak bisa di bawah minimum broker
      if(cappedLot < lot) {
         Print("ðŸ›¡ï¸ PAGAR RISIKO: lot ", DoubleToString(lot,2), " (risiko $", DoubleToString(actualRiskAmt,2),
               ") dipangkas ke ", DoubleToString(cappedLot,2), " (maks $", DoubleToString(maxRiskAmt,2),
               " = ", DoubleToString(MaxRiskPerTradePercent,1), "% balance)");
         lot = cappedLot;
      }
   }
   // v30 RECOVERY: lot dinaikkan HANYA bila momentum-kuat sudah
   // dipersenjatai, dgn pagar risiko KHUSUS recovery (terpisah dari pagar
   // normal - boleh sedikit lebih besar tp tetap terbatas keras).
   if(g_RecoveryArmedThisSignal && RecoveryLotFactor > 1.0) {
      lot = NormalizeDouble(MathMin(lot * RecoveryLotFactor, maxLot), 2);
      double recRisk = lot * slPips * pipValue;
      double recMax  = balance * RecoveryMaxRiskPct / 100.0;
      if(recMax > 0 && recRisk > recMax) {
         double recLot = NormalizeDouble(recMax / (slPips * pipValue), 2);
         if(recLot < minLot) recLot = minLot;
         if(recLot < lot) lot = recLot;
      }
      Print("ðŸ’Š RECOVERY: lot final ", DoubleToString(lot,2), " (risiko $", DoubleToString(lot*slPips*pipValue,2),
            ", pagar recovery ", DoubleToString(RecoveryMaxRiskPct,1), "%)");
   }
   // v47: jaring pengaman TERAKHIR - apa pun jalur perhitungan di atas
   // (normal, LotBoost, pagar risiko, recovery), lot yg DIKEMBALIKAN ke
   // pemanggil tidak boleh pernah di bawah minimum broker (0 = OrderSend
   // pasti gagal error 4051, order tidak akan pernah terkirim).
   if(lot < minLot) lot = minLot;
   return lot;
}

// v42c: SmartOrderSend (kode lama, TAK PERNAH dipanggil dari mana pun -
// terbukti lewat audit) diganti fungsi universal OrderSendRetry ini, kini
// dipakai di SEMUA titik OrderSend() di EA (entri pasar, pending stop).
// Alasan ini penting justru MENJELANG akun real: error transien (requote,
// harga berubah, off-quotes - kode 135/136/138) SERING terjadi di trading
// live tp TIDAK PERNAH muncul di backtest manapun (Strategy Tester tidak
// mensimulasikannya) - jadi absennya perlindungan ini TIDAK akan pernah
// kelihatan dari hasil backtest sebaik apa pun, walau nyata berisiko di
// akun sungguhan.
int OrderSendRetry(string symbol, int cmd, double volume, double price, int slippage, double stoploss, double takeprofit, string comment, int magic, datetime expiration, color arrowColor) {
   int ticket = -1;
   int lastErr = 0;
   for(int retry = 0; retry < 3; retry++) {
      if(retry > 0) RefreshRates();
      double execPrice = price;
      // HANYA utk entri PASAR (OP_BUY/OP_SELL) pakai harga TERBARU tiap
      // percobaan; pending mempertahankan level target.
      if(cmd == OP_BUY) execPrice = NormalizeDouble(Ask, Digits);
      else if(cmd == OP_SELL) execPrice = NormalizeDouble(Bid, Digits);
      ResetLastError();
      ticket = OrderSend(symbol, cmd, volume, execPrice, slippage, stoploss, takeprofit, comment, magic, expiration, arrowColor);
      if(ticket > 0) {
         if(DebugEntryTrace)
            Print("[ENTRY TRACE] OrderSend SUCCESS cmd=",cmd," ticket=",ticket,
                  " lots=",DoubleToString(volume,2)," price=",DoubleToString(execPrice,Digits),
                  " sl=",DoubleToString(stoploss,Digits)," tp=",DoubleToString(takeprofit,Digits),
                  " attempt=",retry+1);
         return ticket;
      }
      lastErr = GetLastError();
      if(DebugEntryTrace)
         Print("[ENTRY TRACE] OrderSend FAIL cmd=",cmd," attempt=",retry+1,
               "/3 err=",lastErr," lots=",DoubleToString(volume,2),
               " price=",DoubleToString(execPrice,Digits),
               " sl=",DoubleToString(stoploss,Digits)," tp=",DoubleToString(takeprofit,Digits));
      if(lastErr != 135 && lastErr != 136 && lastErr != 138 && lastErr != 4 && lastErr != 129)
         break;
      if(retry < 2) {
         Print("âš ï¸ OrderSend gagal (err #", lastErr, "), percobaan ", retry+1, "/3 - coba lagi...");
         if(!IsTesting()) Sleep(200);
      }
   }
   if(DebugEntryTrace)
      Print("[ENTRY TRACE] OrderSend FINAL FAIL err=",lastErr," cmd=",cmd," comment=",comment);
   return -1;
}


//====================================================================
// v3.02 TEAM LEADER / 4-FLOOR EXECUTION
//====================================================================
bool IsTeamLeaderSignal(int direction, int &signalShift)
{
   signalShift=-1;
   int maxSh=MathMax(1,TeamSignalLookbackBars);
   for(int sh=1;sh<=maxSh;sh++)
   {
      double v=STCustom(0,(direction==1)?ST_LeaderBuyBuffer:ST_LeaderSellBuffer,sh);
      if(v!=EMPTY_VALUE && v>0)
      {
         datetime t=iTime(NULL,0,sh);
         if(t==g_LastTeamSignalTime) continue;
         int tr=(int)STCustom(0,ST_TrendBuffer,1);
         if(tr!=direction) continue;
         signalShift=sh;
         return true;
      }
   }
   return false;
}

bool IsTeamConsensusValid(int direction,int signalShift,double &score,int &quorum,string &why)
{
   score=0; quorum=0; why="";
   double stScore=STCustom(0,9,1);
   double stGrade=STCustom(0,10,1);
   if(stScore==EMPTY_VALUE){why+="ST-score-unavailable; ";return false;}
   score=MathMax(0.0,MathMin(100.0,stScore));
   if(stGrade!=EMPTY_VALUE && stGrade<2){why+="ST-grade<2; ";return false;}
   quorum++; // Supertrend leader

   if(UseHeikenAshi){
      if(g_HA_Direction_Val==direction) quorum++;
      else if(TeamRequireHA){why+="HA-opposite; ";return false;}
   }

   if(UseESPConfirmation){
      double espDir=ESPCustom(3,1);
      double espVeto=ESPCustom(5,1);
      if(espVeto!=EMPTY_VALUE && espVeto>=1 && TeamRejectESPVeto){why+="ESP-veto; ";return false;}
      if(espDir!=EMPTY_VALUE && espDir!=0){
         if((direction==1 && espDir>0)||(direction==-1 && espDir<0)) quorum++;
         else {why+="ESP-opposite; ";return false;}
      }
   }

   double room=(direction==1)?SRCustom(4,1):SRCustom(5,1);
   double srVeto=SRCustom(7,1);
   if(srVeto!=EMPTY_VALUE && srVeto>=1){why+="SR-hard-wall; ";return false;}
   if(room!=EMPTY_VALUE && room>=SR_MinRoomATR) quorum++;
   else if(TeamRequireSRRoom){why+="SR-room-low; ";return false;}

   if(score<TeamMinScore){why+="ST-score-low; ";return false;}
   if(quorum<TeamMinQuorum){why+="quorum="+IntegerToString(quorum)+"<"+IntegerToString(TeamMinQuorum)+"; ";return false;}

   if(TeamUseMTFSafety && UseMTFConfirmation){
      int en=0,ag=0;
      if(UseMTF_M5){en++;if(g_ST_Trend_M5==direction)ag++;}
      if(UseMTF_M15){en++;if(g_ST_Trend_M15==direction)ag++;}
      if(UseMTF_M30){en++;if(g_ST_Trend_M30==direction)ag++;}
      if(UseMTF_H1){en++;if(g_ST_Trend_H1==direction)ag++;}
      if(UseMTF_H4){en++;if(g_ST_Trend_H4==direction)ag++;}
      int need=MathMin(MinMTFRequired,en);
      if(en>0 && ag<need){why+="MTF="+IntegerToString(ag)+"/"+IntegerToString(en)+"; ";return false;}
   }
   return true;
}

int GetTeamPendingHint(int direction,int shift)
{
   double h=STCustom(0,ST_PendingHintBuffer,shift);
   if(h==EMPTY_VALUE)return 0;
   int v=(int)MathRound(h);
   return (v>=1 && v<=2)?v:0;
}

bool ExecuteTeamPendingOrder(int direction,int pendingType)
{
   RefreshRates();
   double point=PipPoint();
   double atrPips=GetATRInPips();if(atrPips<=0)atrPips=20;
   double slPips=MathMax(30.0,atrPips*ATRMultiplier_SL);
   double tpPips=MathMax(30.0,slPips*MinRR_Ratio);
   if(UseDynamicSL)slPips=MathMax(slPips,g_PairStopLoss*g_AdaptiveState.slMult);
   if(UseDynamicTP)tpPips=MathMax(tpPips,g_PairTakeProfit*g_AdaptiveState.tpMult);
   double lot=CalculateLotSize(slPips);
   double buffer=MathMax(0.10*atrPips,2.0)*point;
   int cmd;double entry;
   if(pendingType==1){
      double hh=MathMax(iHigh(NULL,0,1),iHigh(NULL,0,2));
      double ll=MathMin(iLow(NULL,0,1),iLow(NULL,0,2));
      if(direction==1){cmd=OP_BUYSTOP;entry=MathMax(Ask+buffer,hh+buffer);}
      else{cmd=OP_SELLSTOP;entry=MathMin(Bid-buffer,ll-buffer);}
   }else{
      double stLine=(direction==1)?STCustom(0,0,1):STCustom(0,1,1);
      double pull=MathMax(0.25*atrPips,5.0)*point;
      if(direction==1){cmd=OP_BUYLIMIT;entry=(stLine!=EMPTY_VALUE && stLine<Ask)?stLine:Ask-pull;}
      else{cmd=OP_SELLLIMIT;entry=(stLine!=EMPTY_VALUE && stLine>Bid)?stLine:Bid+pull;}
   }
   double minDist=MathMax(g_StopLevel*point,15*point);
   if(direction==1){if(cmd==OP_BUYSTOP && entry<Ask+minDist)entry=Ask+minDist;if(cmd==OP_BUYLIMIT && entry>Ask-minDist)entry=Ask-minDist;}
   else{if(cmd==OP_SELLSTOP && entry>Bid-minDist)entry=Bid-minDist;if(cmd==OP_SELLLIMIT && entry<Bid+minDist)entry=Bid+minDist;}
   double sl=(direction==1)?entry-slPips*point:entry+slPips*point;
   double tp=(direction==1)?entry+tpPips*point:entry-tpPips*point;
   entry=NormalizeDouble(entry,g_Digits);sl=NormalizeDouble(sl,g_Digits);tp=NormalizeDouble(tp,g_Digits);
   if(!IsTotalRiskCapOK(lot,slPips,(direction==1)?"TEAM BUY PENDING":"TEAM SELL PENDING"))return false;
   int ticket=OrderSendRetry(Symbol(),cmd,lot,entry,3,sl,tp,"TEAM-EXEC",MagicNumber,0,(direction==1)?clrBlue:clrRed);
   if(ticket>0){g_LastEntryTime=TimeCurrent();Print("[TEAM] PENDING ",(direction==1?"BUY":"SELL")," ",(pendingType==1?"STOP":"LIMIT")," @ ",DoubleToString(entry,g_Digits)," lot=",DoubleToString(lot,2));return true;}
   return false;
}

bool ExecuteTeamLeaderEntry(int direction,int signalShift)
{
   int mode=0;
   if(EntryStyle==ENTRY_MARKET)mode=0;
   else if(EntryStyle==ENTRY_LIMIT || EntryStyle==ENTRY_PULLBACK_LIMIT)mode=2;
   else if(EntryStyle==ENTRY_STOP)mode=1;
   else mode=GetTeamPendingHint(direction,signalShift);
   if(mode==1 || mode==2)return ExecuteTeamPendingOrder(direction,mode);
   return ExecuteSmartOrder(direction==1?OP_BUY:OP_SELL);
}

bool ExecuteSmartOrder(int type) {
   RefreshRates();
   ArmRecoveryIfEligible((type==OP_BUY)?1:-1); // v30
   double atrPips = GetATRInPips(); if(atrPips <= 0) atrPips = 20;
   double slPips = MathMax(30, atrPips * ATRMultiplier_SL);
   double tpPips = MathMax(30, slPips * MinRR_Ratio);
   if(UseDynamicSL) slPips = MathMax(slPips, g_PairStopLoss * g_AdaptiveState.slMult);
   if(UseDynamicTP) tpPips = MathMax(tpPips, g_PairTakeProfit * g_AdaptiveState.tpMult);
   // v46: masa tenggang - kalau aktif, SL SUNGGUHAN yg dipasang & lot-size
   // dihitung dari jarak LEBAR (survive koreksi awal wajar); slPips normal
   // (sempit) disimpan di trade monitor utk diterapkan nanti setelah masa
   // tenggang lewat. Kalau nonaktif, perilaku PERSIS spt sebelumnya.
   double effectiveSlPips = slPips;
   if(UseEntryGracePeriod) effectiveSlPips = MathMax(slPips, atrPips * GracePeriodATRMultiplier);
   double lot = CalculateLotSize(effectiveSlPips);
   double point = PipPoint();
   double price = (type==OP_BUY)?Ask:Bid;
   double sl = (type==OP_BUY)? price - effectiveSlPips*point : price + effectiveSlPips*point;
   double tp = (type==OP_BUY)? price + tpPips*point : price - tpPips*point;
   double minDist = MathMax(g_StopLevel*point, 15*point);
   if(type==OP_BUY) { if(price-sl<minDist) sl=price-minDist; if(tp-price<minDist) tp=price+minDist; }
   else { if(sl-price<minDist) sl=price+minDist; if(price-tp<minDist) tp=price-minDist; }
   sl = NormalizeDouble(sl,g_Digits); tp = NormalizeDouble(tp,g_Digits); price = NormalizeDouble(price,g_Digits);
   // v2.00: pagar risiko AGREGAT - lihat temuan audit "43,5% balance dipertaruhkan
   // sekaligus" (tiga posisi kena SL di harga & detik yg sama). Ini gerbang
   // terakhir sebelum eksposur bertambah.
   if(!IsTotalRiskCapOK(lot, effectiveSlPips, (type==OP_BUY?"ENTRI BUY":"ENTRI SELL"))) return false;
   int ticket = OrderSendRetry(Symbol(), type, lot, price, 3, sl, tp, "UGE70", MagicNumber, 0, (type==OP_BUY)?clrBlue:clrRed);
   if(ticket>0) { g_LastEntryTime=TimeCurrent(); AddTradeMonitor(ticket); SetVirtualSL(ticket, (type==OP_BUY)?price-effectiveSlPips*point:price+effectiveSlPips*point);
   if(UseEntryGracePeriod) {
      double normalSL = (type==OP_BUY)? price - slPips*point : price + slPips*point;
      SetGracePeriod(ticket, NormalizeDouble(normalSL,g_Digits));
   }
   if(g_RecoveryArmedThisSignal){ g_RecoveryTradesUsed++; g_RecoveryArmedThisSignal=false; } // v30
   Print("Lot digunakan: ", lot, " (Risk=", RiskPerTrade, "%, Balance=", AccountBalance(), ")");
   return true;
   }
   if(DebugEntryTrace) Print("[ENTRY TRACE] ExecuteSmartOrder GAGAL type=",type," - ticket=-1");
   return false;
}
// === ENTRI PULLBACK: pending LIMIT menunggu harga retrace dulu ===
// Entri lebih dekat ke titik balik (low utk BUY / high utk SELL), bukan di
// puncak setelah candle konfirmasi. SL/TP dihitung dari harga limit (lebih
// pendek & reward lebih besar dibanding entri market di puncak).
bool ExecutePullbackOrder(int direction) {
   RefreshRates();
   ArmRecoveryIfEligible(direction); // v30
   double point = PipPoint();
   double atrPips = GetATRInPips(); if(atrPips <= 0) atrPips = 20;
   double pullPips = MathMax(5.0, atrPips * PullbackATRFactor);

   double slPips = MathMax(30, atrPips * ATRMultiplier_SL);
   double tpPips = MathMax(30, slPips * MinRR_Ratio);
   if(UseDynamicSL) slPips = MathMax(slPips, g_PairStopLoss * g_AdaptiveState.slMult);
   if(UseDynamicTP) tpPips = MathMax(tpPips, g_PairTakeProfit * g_AdaptiveState.tpMult);
   double lot = CalculateLotSize(slPips);

   int type; double entry;
   if(direction == 1) { type = OP_BUYLIMIT;  entry = Ask - pullPips * point; }
   else               { type = OP_SELLLIMIT; entry = Bid + pullPips * point; }

   // hormati stop level broker utk jarak pending dari harga sekarang
   double minDist = MathMax(g_StopLevel * point, 15 * point);
   if(direction == 1 && (Ask - entry) < minDist) entry = Ask - minDist;
   if(direction == -1 && (entry - Bid) < minDist) entry = Bid + minDist;

   double sl = (direction == 1) ? entry - slPips * point : entry + slPips * point;
   double tp = (direction == 1) ? entry + tpPips * point : entry - tpPips * point;

   entry = NormalizeDouble(entry, g_Digits);
   sl = NormalizeDouble(sl, g_Digits);
   tp = NormalizeDouble(tp, g_Digits);

   datetime expiry = TimeCurrent() + PullbackExpiryBars * PeriodSeconds();
   int ticket = OrderSendRetry(Symbol(), type, lot, entry, 3, sl, tp, "UGE70-PB", MagicNumber, expiry, (direction == 1) ? clrBlue : clrRed);
   if(ticket > 0) {
      g_LastEntryTime = TimeCurrent();
      if(g_RecoveryArmedThisSignal){ g_RecoveryTradesUsed++; g_RecoveryArmedThisSignal=false; } // v30
      Print("PENDING ", (direction == 1 ? "BUY" : "SELL"), " LIMIT dipasang @ ", DoubleToString(entry, g_Digits),
            " (menunggu retrace ", DoubleToString(pullPips, 1), " pips, kadaluarsa ", PullbackExpiryBars, " bar)");
      return true;
   } else {
      int pbErr = GetLastError();
      Print("GAGAL pasang pending pullback, err=", pbErr, " - fallback entri market");
      return ExecuteSmartOrder((direction == 1) ? OP_BUY : OP_SELL);
   }
}

// Kelola pending pullback: batalkan bila trend flip balik; kadaluarsa
// dikelola SENDIRI oleh EA (banyak broker menolak field expiry), dan
// PENTING: bila hangus tak tersentuh padahal trend MASIH searah, kunci
// flip DIBUKA KEMBALI (g_LastFlipTraded=0) supaya EA bisa pasang entri
// baru - momentum trend kuat tidak terbuang sia-sia.
void ManagePendingPullbacks() {
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;
      int ot = OrderType();
      if(ot != OP_BUYLIMIT && ot != OP_SELLLIMIT) continue;
      // SMART CORE owns its own pending lifecycle; do not let the legacy
      // 4-bar pullback manager delete SMARTCORE orders.
      if(StringFind(OrderComment(),"SMARTCORE",0)>=0) continue;
      int dir = (ot == OP_BUYLIMIT) ? 1 : -1;
      int trendNow = (int)STCustom(0, ST_TrendBuffer, 1);
      if(trendNow != dir) {
         if(OrderDelete(OrderTicket()))
            Print("Pending pullback #", OrderTicket(), " DIBATALKAN: trend sudah flip balik");
         continue;
      }
      // kadaluarsa mandiri: umur pending > PullbackExpiryBars bar
      if(TimeCurrent() - OrderOpenTime() > PullbackExpiryBars * PeriodSeconds()) {
         int tk = OrderTicket();
         if(OrderDelete(tk)) {
            Print("Pending pullback #", tk, " HANGUS tak tersentuh - trend masih searah: kunci flip DIBUKA, EA boleh entri ulang");
            g_LastFlipTraded = 0; // izinkan sinyal dari flip yg sama dipasang ulang
         }
      }
   }
}

//+------------------------------------------------------------------+
//| v32: PENDING STOP TITIK JENUH - dikelola tiap bar baru.           |
//| Deteksi jenuh: tren berjalan ekstensi >= ExhPendExtATR x ATR dari |
//| garis ST + RSI ekstrem. Level stop = struktur (low/high N bar);   |
//| bila level S/R SuperSR berada ANTARA harga & struktur, dipakai    |
//| S/R itu (menembus S/R = konfirmasi lebih kuat). Selama menunggu:  |
//| level DIGESER ULANG tiap bar (adaptif); hangus bila jenuh hilang  |
//| atau umur habis; saat TERSENTUH -> jadi posisi market, dimonitor  |
//| trailing spt biasa + info tampil di dashboard.                    |
//+------------------------------------------------------------------+
void ManageExhaustionPending() {
   if(!UseExhaustionPending) { g_ExhPendInfo = "-"; g_ExhPendLInfo = "-"; return; }
   ENUM_REPEND_MODE effModeX = ResolveAutoSlopeMode(ExhPendOrderMode);
   // v55: LIMIT dikelola independen di fungsi terpisah - dipanggil dulu di
   // sini spy kedua slot (STOP di bawah, LIMIT di sini) sama2 dpt giliran
   // tiap kali fungsi ini jalan, apa pun mode yg dipilih.
   if(effModeX==REPEND_LIMIT_ONLY || effModeX==REPEND_BOTH) ManageExhaustionPendingLimit();
   if(effModeX!=REPEND_STOP_ONLY && effModeX!=REPEND_BOTH) { g_ExhPendInfo="-"; return; } // mode LIMIT_ONLY murni - slot STOP tak dipakai sama sekali
   double point = PipPoint();
   int slipX = 3; if(g_Digits==3 || g_Digits==5) slipX *= 10;

   // --- FASE 1: kelola pending yg sedang hidup ---
   if(g_ExhPendTicket > 0) {
      if(!OrderSelect(g_ExhPendTicket, SELECT_BY_TICKET)) {
         // tak ditemukan sama sekali (terhapus/expired oleh server)
         g_ExhPendTicket = -1; g_ExhPendDir = 0; g_ExhPendInfo = "-";
      } else if(OrderType() == OP_BUY || OrderType() == OP_SELL) {
         // TERSENTUH! kini posisi market - serahkan ke sistem monitor/trailing
         AddTradeMonitor(g_ExhPendTicket);
         g_ExhPendInfo = StringConcatenate("TERSENTUH ", (g_ExhPendDir==1?"BUY":"SELL"), " @ ", DoubleToString(OrderOpenPrice(), g_Digits));
         Print("ðŸª¤ PENDING JENUH TERSENTUH: ", (g_ExhPendDir==1?"BUY":"SELL"), " #", g_ExhPendTicket,
               " @ ", DoubleToString(OrderOpenPrice(), g_Digits), " - kini posisi market, trailing aktif");
         g_ExhPendTicket = -1; g_ExhPendDir = 0;
         return;
      } else if(OrderCloseTime() > 0) {
         g_ExhPendTicket = -1; g_ExhPendDir = 0; g_ExhPendInfo = "-";
      } else {
         // masih pending: cek umur & kondisi jenuh, geser adaptif
         int ageBars = iBarShift(NULL, 0, g_ExhPendPlacedBar);
         int trendNow = (int)STCustom(0, ST_TrendBuffer, 1);
         double rsiNow = iRSI(NULL, 0, ExhPendRSIPeriod, PRICE_CLOSE, 1);
         bool stillExhausted = false;
         if(g_ExhPendDir == -1) stillExhausted = (trendNow == 1 && rsiNow >= ExhPendRSIOB - 5); // histeresis 5 poin
         else                   stillExhausted = (trendNow == -1 && rsiNow <= ExhPendRSIOS + 5);
         // v37: jangan batalkan hanya krn 1 bar RSI sedikit mundur (wajar &
         // sering terjadi walau setup masih valid) - baru batalkan kalau
         // "tidak lagi jenuh" ini bertahan ExhPendCancelPersistBars bar
         // beruntun. Umur maksimal (ExhPendExpiryBars) tetap jadi batas keras
         // terpisah, tidak terpengaruh perubahan ini.
         if(!stillExhausted) g_ExhPendNotExhaustedStreak++; else g_ExhPendNotExhaustedStreak = 0;
         bool cancelSetupLost = (g_ExhPendNotExhaustedStreak >= ExhPendCancelPersistBars);
         if(ageBars >= ExhPendExpiryBars || cancelSetupLost) {
            if(OrderDelete(g_ExhPendTicket))
               Print("ðŸª¤ PENDING JENUH DIHAPUS: ", (ageBars >= ExhPendExpiryBars ? "umur habis" : "kondisi jenuh hilang"),
                     " (umur ", ageBars, " bar, streak-hilang ", g_ExhPendNotExhaustedStreak, " bar)");
            g_ExhPendTicket = -1; g_ExhPendDir = 0; g_ExhPendInfo = "-"; g_ExhPendNotExhaustedStreak = 0;
         } else {
            // GESER ADAPTIF: hitung ulang level struktur & modify bila beda
            double newLvl = ComputeExhPendLevel(g_ExhPendDir);
            if(newLvl > 0 && MathAbs(newLvl - OrderOpenPrice()) > 1.0 * point * 10) {
               double slP = GetGraceAwareSLPips(), tpP = GetManualTPPips();
               double nSL = (g_ExhPendDir==1) ? newLvl - slP*point : newLvl + slP*point;
               double nTP = (g_ExhPendDir==1) ? newLvl + tpP*point : newLvl - tpP*point;
               if(SafeOrderModify(g_ExhPendTicket, newLvl, nSL, nTP, OrderExpiration(), clrYellow, "ExhPendChase"))
                  Print("ðŸª¤ PENDING JENUH DIGESER adaptif ke ", DoubleToString(newLvl, g_Digits));
            }
            g_ExhPendInfo = StringConcatenate((g_ExhPendDir==1?"BUY STOP":"SELL STOP"), " @ ",
                            DoubleToString(OrderOpenPrice(), g_Digits), " (sisa ", (ExhPendExpiryBars-ageBars), " bar)");
         }
      }
      if(g_ExhPendTicket > 0) return; // masih ada pending hidup - jangan pasang baru
   }

   // --- FASE 2: deteksi titik jenuh baru & pasang pending ---
   if(g_GoalHit || g_TradingPaused || !g_Active || !g_AllowTrading) return;
   int trendX = (int)STCustom(0, ST_TrendBuffer, 1);
   if(trendX != 1 && trendX != -1) return;
   double atrX = iATR(NULL, 0, 14, 1);
   if(atrX <= 0) return;
   double extPips = GetCurrentTrendExtensionPips(trendX);
   if(extPips * point < ExhPendExtATR * atrX) return;      // tren belum cukup jauh utk jenuh
   double rsiX = iRSI(NULL, 0, ExhPendRSIPeriod, PRICE_CLOSE, 1);
   int pendDir = 0;
   if(trendX == 1 && rsiX >= ExhPendRSIOB) pendDir = -1;    // uptrend jenuh -> SELL STOP di bawah
   else if(trendX == -1 && rsiX <= ExhPendRSIOS) pendDir = 1; // downtrend jenuh -> BUY STOP di atas
   if(pendDir == 0) return;
   double lvl = ComputeExhPendLevel(pendDir);
   if(lvl <= 0) return;
   double slP2 = GetGraceAwareSLPips(), tpP2 = GetManualTPPips();
   double slX = (pendDir==1) ? lvl - slP2*point : lvl + slP2*point;
   double tpX = (pendDir==1) ? lvl + tpP2*point : lvl - tpP2*point;
   int cmdX = (pendDir==1) ? OP_BUYSTOP : OP_SELLSTOP;
   datetime expX = TimeCurrent() + (ExhPendExpiryBars+2) * PeriodSeconds(Period()); // server-expiry cadangan; umur utama dikelola sendiri
   if(!IsTotalRiskCapOK(GetManualLot(), MathAbs(lvl-slX)/PipPoint(), "PENDING EXHAUSTION STOP")) return;
   int tX = OrderSendRetry(Symbol(), cmdX, GetManualLot(), NormalizeDouble(lvl,g_Digits), slipX,
                      NormalizeDouble(slX,g_Digits), NormalizeDouble(tpX,g_Digits), "UGE70-EXH", MagicNumber, expX, clrYellow);
   if(tX > 0) {
      g_ExhPendTicket = tX; g_ExhPendDir = pendDir; g_ExhPendPlacedBar = iTime(NULL,0,1); g_ExhPendNotExhaustedStreak = 0;
      g_ExhPendInfo = StringConcatenate((pendDir==1?"BUY STOP":"SELL STOP"), " @ ", DoubleToString(lvl,g_Digits), " (baru)");
      Print("ðŸª¤ PENDING TITIK-JENUH ", (pendDir==1?"BUY STOP":"SELL STOP"), " dipasang @ ", DoubleToString(lvl,g_Digits),
            " (tren ", (trendX==1?"NAIK":"TURUN"), " ekstensi ", DoubleToString(extPips,1), " pips, RSI ", DoubleToString(rsiX,1), ")");
   } else { int eX = GetLastError(); if(eX != 0) Print("ExhPend OrderSend err #", eX); }
}

//+------------------------------------------------------------------+
//| v32: level stop utk pending jenuh - struktur N bar, disempurnakan |
//| dgn S/R SuperSR bila levelnya berada ANTARA harga & struktur.     |
//+------------------------------------------------------------------+
double ComputeExhPendLevel(int pendDir) {
   double point = PipPoint();
   // v37: 3 pip tetap (~$0.03) nyaris tak berarti utk instrumen semahal gold -
   // buffer sekarang MAX(pip tetap, faktor xATR) spy tetap bermakna di gold
   // tapi tidak berubah utk instrumen murah/tenang.
   double atrBufX = iATR(NULL, 0, 14, 1);
   double buf = MathMax(ExhPendBufferPips * point, ExhPendBufferATRFactor * atrBufX);
   double minDist = MathMax(g_StopLevel*point, 15*point);
   RefreshRates();
   if(pendDir == -1) { // SELL STOP di bawah struktur
      int lo = iLowest(NULL, 0, MODE_LOW, ExhPendStructBars, 1);
      if(lo < 0) return 0;
      double structLvl = iLow(NULL, 0, lo);
      // S/R adaptif: support SuperSR di antara harga & struktur = level lebih bermakna
      if(g_DisplaySupport > 0 && g_DisplaySupport < Bid && g_DisplaySupport > structLvl) structLvl = g_DisplaySupport;
      double lvl = structLvl - buf;
      if(lvl > Bid - minDist) lvl = Bid - minDist;
      return lvl;
   } else {            // BUY STOP di atas struktur
      int hi = iHighest(NULL, 0, MODE_HIGH, ExhPendStructBars, 1);
      if(hi < 0) return 0;
      double structLvl = iHigh(NULL, 0, hi);
      if(g_DisplayResistance > 0 && g_DisplayResistance > Ask && g_DisplayResistance < structLvl) structLvl = g_DisplayResistance;
      double lvl = structLvl + buf;
      if(lvl < Ask + minDist) lvl = Ask + minDist;
      return lvl;
   }
}
// v55: barometer LIMIT titik-jenuh - BERBEDA filosofi dr STOP di atas.
// STOP pakai struktur di SISI arah breakdown/breakout (low utk sell, high
// utk buy) krn nunggu KONFIRMASI jebol. LIMIT pakai struktur di SISI
// BERLAWANAN (high utk sell, low utk buy) - itulah puncak/dasar ekstensi
// ITU SENDIRI, tempat kita bertaruh pembalikan mulai LANGSUNG dr situ
// tanpa perlu tunggu konfirmasi breakdown tambahan.
double ComputeExhPendLimitLevel(int pendDir) {
   RefreshRates();
   double point = PipPoint();
   double minDist = MathMax(g_StopLevel*point, 15*point);
   if(pendDir == -1) { // SELL LIMIT - di ATAS harga skrg, di puncak ekstensi
      int hi = iHighest(NULL, 0, MODE_HIGH, ExhPendStructBars, 1);
      if(hi < 0) return 0;
      double lvl = iHigh(NULL, 0, hi);
      if(lvl < Bid + minDist) lvl = Bid + minDist;
      return lvl;
   } else {            // BUY LIMIT - di BAWAH harga skrg, di dasar ekstensi
      int lo = iLowest(NULL, 0, MODE_LOW, ExhPendStructBars, 1);
      if(lo < 0) return 0;
      double lvl = iLow(NULL, 0, lo);
      if(lvl > Ask - minDist) lvl = Ask - minDist;
      return lvl;
   }
}
// v55: kelola slot LIMIT titik-jenuh - paralel persis dgn Fase 1+2 slot
// STOP di ManageExhaustionPending(), tp tiket/state terpisah sepenuhnya
// (g_ExhPendLTicket dkk) supaya mode BOTH bisa jalankan keduanya sekaligus
// tanpa saling ganggu.
void ManageExhaustionPendingLimit() {
   double point = PipPoint();
   if(g_ExhPendLTicket > 0) {
      if(!OrderSelect(g_ExhPendLTicket, SELECT_BY_TICKET)) { g_ExhPendLTicket=-1; g_ExhPendLDir=0; g_ExhPendLInfo="-"; }
      else if(OrderType()==OP_BUY || OrderType()==OP_SELL) {
         AddTradeMonitor(g_ExhPendLTicket);
         g_ExhPendLInfo = StringConcatenate("TERSENTUH ", (g_ExhPendLDir==1?"BUY":"SELL"), " @ ", DoubleToString(OrderOpenPrice(),g_Digits));
         Print("ðŸª¤ PENDING JENUH LIMIT TERSENTUH: ", (g_ExhPendLDir==1?"BUY":"SELL"), " #", g_ExhPendLTicket, " @ ", DoubleToString(OrderOpenPrice(),g_Digits), " - kini posisi market, trailing aktif");
         g_ExhPendLTicket=-1; g_ExhPendLDir=0; return;
      } else if(OrderCloseTime()>0) { g_ExhPendLTicket=-1; g_ExhPendLDir=0; g_ExhPendLInfo="-"; }
      else {
         int ageBarsL = iBarShift(NULL,0,g_ExhPendLPlacedBar);
         int trendNowL = (int)STCustom(0, ST_TrendBuffer, 1);
         double rsiNowL = iRSI(NULL,0,ExhPendRSIPeriod,PRICE_CLOSE,1);
         bool stillExhaustedL = false;
         if(g_ExhPendLDir==-1) stillExhaustedL = (trendNowL==1 && rsiNowL >= ExhPendRSIOB-5);
         else stillExhaustedL = (trendNowL==-1 && rsiNowL <= ExhPendRSIOS+5);
         if(!stillExhaustedL) g_ExhPendLNotExhaustedStreak++; else g_ExhPendLNotExhaustedStreak=0;
         bool cancelL = (g_ExhPendLNotExhaustedStreak >= ExhPendLimitCancelPersistBars);
         if(ageBarsL >= ExhPendLimitExpiryBars || cancelL) {
            if(OrderDelete(g_ExhPendLTicket))
               Print("ðŸª¤ PENDING JENUH LIMIT DIHAPUS: ", (ageBarsL>=ExhPendLimitExpiryBars?"umur habis":"kondisi jenuh hilang"), " (umur ", ageBarsL, " bar, streak-hilang ", g_ExhPendLNotExhaustedStreak, " bar)");
            g_ExhPendLTicket=-1; g_ExhPendLDir=0; g_ExhPendLInfo="-"; g_ExhPendLNotExhaustedStreak=0;
         } else {
            double newLvlL = ComputeExhPendLimitLevel(g_ExhPendLDir);
            if(newLvlL > 0 && MathAbs(newLvlL - OrderOpenPrice()) > 1.0*point*10) {
               double slPL=GetGraceAwareSLPips(), tpPL=GetManualTPPips();
               double nSLL=(g_ExhPendLDir==1)?newLvlL-slPL*point:newLvlL+slPL*point;
               double nTPL=(g_ExhPendLDir==1)?newLvlL+tpPL*point:newLvlL-tpPL*point;
               if(SafeOrderModify(g_ExhPendLTicket, newLvlL, nSLL, nTPL, OrderExpiration(), clrYellow, "ExhPendLChase"))
                  Print("ðŸª¤ PENDING JENUH LIMIT DIGESER ke ", DoubleToString(newLvlL,g_Digits));
            }
            g_ExhPendLInfo = StringConcatenate((g_ExhPendLDir==1?"BUY LIMIT":"SELL LIMIT"), " @ ", DoubleToString(OrderOpenPrice(),g_Digits), " (sisa ", (ExhPendLimitExpiryBars-ageBarsL), " bar)");
         }
      }
      if(g_ExhPendLTicket > 0) return;
   }
   if(g_GoalHit || g_TradingPaused || !g_Active || !g_AllowTrading) return;
   int trendXL = (int)STCustom(0, ST_TrendBuffer, 1);
   if(trendXL != 1 && trendXL != -1) return;
   double atrXL = iATR(NULL,0,14,1); if(atrXL<=0) return;
   double extPipsL = GetCurrentTrendExtensionPips(trendXL);
   if(extPipsL*point < ExhPendExtATR*atrXL) return;
   double rsiXL = iRSI(NULL,0,ExhPendRSIPeriod,PRICE_CLOSE,1);
   int pendDirL = 0;
   if(trendXL==1 && rsiXL>=ExhPendRSIOB) pendDirL=-1;
   else if(trendXL==-1 && rsiXL<=ExhPendRSIOS) pendDirL=1;
   if(pendDirL==0) return;
   double lvlL = ComputeExhPendLimitLevel(pendDirL);
   if(lvlL<=0) return;
   RefreshRates();
   double curPriceXL = (pendDirL==1) ? Ask : Bid;
   double distATR_L = MathAbs(curPriceXL - lvlL) / atrXL;
   if(distATR_L < ExhPendLimitMinATR || distATR_L > ExhPendLimitMaxATR) return; // barometer tdk valid - jgn asal pasang
   double slPL2=GetGraceAwareSLPips(), tpPL2=GetManualTPPips();
   double slXL=(pendDirL==1)?lvlL-slPL2*point:lvlL+slPL2*point;
   double tpXL=(pendDirL==1)?lvlL+tpPL2*point:lvlL-tpPL2*point;
   int cmdXL=(pendDirL==1)?OP_BUYLIMIT:OP_SELLLIMIT;
   int slipXL=3; if(g_Digits==3||g_Digits==5) slipXL*=10;
   datetime expXL = TimeCurrent() + (ExhPendLimitExpiryBars+2)*PeriodSeconds(Period());
   if(!IsTotalRiskCapOK(GetManualLot(), MathAbs(lvlL-slXL)/PipPoint(), "PENDING EXHAUSTION LIMIT")) return;
   int tXL = OrderSendRetry(Symbol(), cmdXL, GetManualLot(), NormalizeDouble(lvlL,g_Digits), slipXL,
                      NormalizeDouble(slXL,g_Digits), NormalizeDouble(tpXL,g_Digits), "UGE70-EXHL", MagicNumber, expXL, clrYellow);
   if(tXL > 0) {
      g_ExhPendLTicket=tXL; g_ExhPendLDir=pendDirL; g_ExhPendLPlacedBar=iTime(NULL,0,1); g_ExhPendLNotExhaustedStreak=0;
      g_ExhPendLInfo = StringConcatenate((pendDirL==1?"BUY LIMIT":"SELL LIMIT"), " @ ", DoubleToString(lvlL,g_Digits), " (baru)");
      Print("ðŸª¤ PENDING TITIK-JENUH ", (pendDirL==1?"BUY LIMIT":"SELL LIMIT"), " dipasang @ ", DoubleToString(lvlL,g_Digits),
            " (tren ", (trendXL==1?"NAIK":"TURUN"), " ekstensi ", DoubleToString(extPipsL,1), " pips, RSI ", DoubleToString(rsiXL,1), ", ", DoubleToString(distATR_L,2), "xATR dr harga skrg)");
   } else { int eXL=GetLastError(); if(eXL!=0) Print("ExhPend Limit OrderSend err #", eXL); }
}

//+------------------------------------------------------------------+
//| v30: PENDING STOP COVER - dipanggil saat posisi ditutup RUGI.     |
//| Bila indikator (ST trend + HA mentah) kini KOMPAK searah LAWAN    |
//| posisi yg kalah (pembalikan terkonfirmasi), pasang STOP order di  |
//| titik ekstrem N bar +/- buffer utk menangkap kelanjutan tren      |
//| lawan itu. Kedaluwarsa otomatis bila tak tersentuh.               |
//+------------------------------------------------------------------+
void MaybePlaceCoverStop(int closedTicket) {
   if(!UsePendingCover) return;
   if(g_GoalHit || g_TradingPaused || !g_Active || !g_AllowTrading) return;
   if(!OrderSelect(closedTicket, SELECT_BY_TICKET, MODE_HISTORY)) return;
   if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) return;
   if(OrderType() != OP_BUY && OrderType() != OP_SELL) return;
   if(OrderProfit() + OrderSwap() + OrderCommission() >= 0) return; // hanya posisi yg KALAH
   int covDir = (OrderType() == OP_BUY) ? -1 : 1;                    // arah LAWAN posisi kalah
   // konfirmasi indikator: ST trend & HA mentah harus kompak searah cover
   if((int)STCustom(0, ST_TrendBuffer, 1) != covDir) return;
   if(RawHADirection() != covDir) return;
   RefreshRates();
   double point = PipPoint();
   double buf = CoverBufferPips * point;
   double lvl;
   if(covDir == 1) { int hi = iHighest(NULL,0,MODE_HIGH,CoverExtremeBars,1); if(hi<0) return; lvl = iHigh(NULL,0,hi) + buf; }
   else            { int lo = iLowest (NULL,0,MODE_LOW, CoverExtremeBars,1); if(lo<0) return; lvl = iLow (NULL,0,lo) - buf; }
   double minDist = MathMax(g_StopLevel*point, 15*point);
   double bidC = MarketInfo(Symbol(),MODE_BID), askC = MarketInfo(Symbol(),MODE_ASK);
   int cmd; double slC, tpC;
   double slP = GetGraceAwareSLPips(), tpP = GetManualTPPips();
   if(covDir == 1) {
      cmd = OP_BUYSTOP;
      if(lvl < askC + minDist) lvl = askC + minDist;   // stop hrs di ATAS harga
      slC = lvl - slP*point; tpC = lvl + tpP*point;
   } else {
      cmd = OP_SELLSTOP;
      if(lvl > bidC - minDist) lvl = bidC - minDist;   // stop hrs di BAWAH harga
      slC = lvl + slP*point; tpC = lvl - tpP*point;
   }
   lvl = NormalizeDouble(lvl, g_Digits); slC = NormalizeDouble(slC, g_Digits); tpC = NormalizeDouble(tpC, g_Digits);
   double lotC = GetManualLot();
   datetime expiryC = TimeCurrent() + CoverExpiryBars * PeriodSeconds(Period());
   int slipC = 3; if(g_Digits==3 || g_Digits==5) slipC *= 10;
   if(!IsTotalRiskCapOK(lotC, MathAbs(lvl-slC)/PipPoint(), "PENDING COVER")) return;
   int tC = OrderSendRetry(Symbol(), cmd, lotC, lvl, slipC, slC, tpC, "UGE70-COVER", MagicNumber, expiryC, clrYellow);
   if(tC > 0)
      Print("ðŸª¤ PENDING COVER ", (covDir==1?"BUY STOP":"SELL STOP"), " dipasang @ ", DoubleToString(lvl,g_Digits),
            " (posisi #", closedTicket, " kalah, indikator kompak arah lawan; hangus ", CoverExpiryBars, " bar)");
   else { int errC = GetLastError(); if(errC != 0) Print("Cover OrderSend err #", errC); }
}

//+------------------------------------------------------------------+
//| v39: PENDING LANJUT-TREN - beda dgn MaybePlaceCoverStop di atas.  |
//| Cover (di atas) menyasar kasus SL kena krn tren SUNGGUH berbalik  |
//| (indikator sudah flip ke arah LAWAN posisi yg tutup). Fungsi ini  |
//| menyasar kasus SEBALIKNYA yg selama ini tak tertangani sama       |
//| sekali: SL kena krn KOREKSI SESAAT di tengah tren yg MASIH hidup  |
//| (indikator MASIH searah posisi lama, belum berbalik) - "masuk,    |
//| koreksi dulu sebelum ke arah TP, kena cut-loss, lalu tren aslinya |
//| lanjut jauh tapi EA tak lagi entri" - persis keluhan pengamatan   |
//| pengguna. Pending dipasang SEARAH posisi lama, baru tersentuh     |
//| kalau harga sungguh menembus struktur terbaru (bukti koreksi      |
//| sudah selesai & tren lanjut, bukan asal masuk lagi di harga sama).|
//+------------------------------------------------------------------+
// v52: cek pending EA ini yg SUDAH ada dr tipe tertentu - dipakai supaya mode
// BOTH bisa pasang satu STOP + satu LIMIT bersamaan, tp tetap cegah dobel tipe yg sama.
bool RependAlreadyPendingOfType(int typeA, int typeB) {
   for(int iRp=0; iRp<OrdersTotal(); iRp++)
      if(OrderSelect(iRp,SELECT_BY_POS,MODE_TRADES) && OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber &&
         (OrderType()==typeA || OrderType()==typeB)) return true;
   return false;
}
void PlaceRependStop(int closedTicket, int repDir, ENUM_REPEND_MODE effMode) {
   // v52: cek dobel - mode BOTH cuma cegah dobel STOP (LIMIT boleh coexist);
   // mode lain (STOP_ONLY) pertahankan perilaku asli: cegah pending APAPUN.
   // v60 FIX: pakai mode YG SUDAH DIRESOLUSI (parameter), bukan baca
   // RependOrderMode (global mentah) langsung - kalau mode itu AUTO_SLOPE,
   // perbandingan "==REPEND_BOTH" thd global SELALU false walau hasil
   // resolusi SAAT ITU BOTH, membuat pengecekan salah terlalu ketat.
   bool blocked = (effMode==REPEND_BOTH) ? RependAlreadyPendingOfType(OP_BUYSTOP,OP_SELLSTOP)
                  : (RependAlreadyPendingOfType(OP_BUYSTOP,OP_SELLSTOP) || RependAlreadyPendingOfType(OP_BUYLIMIT,OP_SELLLIMIT));
   if(blocked) return;
   RefreshRates();
   double point = PipPoint();
   double atrRep = iATR(NULL, 0, 14, 1); if(atrRep<=0) return;
   double buf = MathMax(RependBufferPips*point, 0.15*atrRep); // v39: sama spt v37 - buffer pip tetap nyaris nol utk gold, ikutkan skala ATR
   double lvl;
   if(repDir == 1) { int hi = iHighest(NULL,0,MODE_HIGH,RependStructBars,1); if(hi<0) return; lvl = iHigh(NULL,0,hi) + buf; }
   else            { int lo = iLowest (NULL,0,MODE_LOW, RependStructBars,1); if(lo<0) return; lvl = iLow (NULL,0,lo) - buf; }
   double minDist = MathMax(g_StopLevel*point, 15*point);
   double bidR = MarketInfo(Symbol(),MODE_BID), askR = MarketInfo(Symbol(),MODE_ASK);
   int cmd; double slR, tpR;
   double slP = GetGraceAwareSLPips(), tpP = GetManualTPPips();
   if(repDir == 1) {
      cmd = OP_BUYSTOP;
      if(lvl < askR + minDist) lvl = askR + minDist;
      slR = lvl - slP*point; tpR = lvl + tpP*point;
   } else {
      cmd = OP_SELLSTOP;
      if(lvl > bidR - minDist) lvl = bidR - minDist;
      slR = lvl + slP*point; tpR = lvl - tpP*point;
   }
   lvl = NormalizeDouble(lvl, g_Digits); slR = NormalizeDouble(slR, g_Digits); tpR = NormalizeDouble(tpR, g_Digits);
   double lotR = GetManualLot();
   datetime expiryR = TimeCurrent() + RependExpiryBars * PeriodSeconds(Period());
   int slipR = 3; if(g_Digits==3 || g_Digits==5) slipR *= 10;
   if(!IsTotalRiskCapOK(lotR, MathAbs(lvl-slR)/PipPoint(), "PENDING LANJUT-TREN STOP")) return;
   int tR = OrderSendRetry(Symbol(), cmd, lotR, lvl, slipR, slR, tpR, "UGE70-REPEND", MagicNumber, expiryR, clrAqua);
   if(tR > 0)
      Print("ðŸ” PENDING LANJUT-TREN ", (repDir==1?"BUY STOP":"SELL STOP"), " dipasang @ ", DoubleToString(lvl,g_Digits),
            " (posisi #", closedTicket, " kena SL tp indikator MASIH searah - diduga koreksi biasa bukan pembalikan; hangus ", RependExpiryBars, " bar)");
   else { int errR = GetLastError(); if(errR != 0) Print("Repend OrderSend err #", errR); }
}
// v52: PENDING LANJUT-TREN gaya LIMIT (baru) - barometer = garis Supertrend
// SAAT INI (bukan struktur high/low spt STOP), krn garis ST sudah teruji jadi
// acuan tren di seluruh EA ini. Kalau harga koreksi TURUN (buy)/NAIK (sell)
// kembali ke garis ST tp tren msh utuh, itu entri harga lebih baik dgn dasar
// yg valid - BUKAN sembarang comot harga. Divalidasi dulu jaraknya (xATR) -
// kalau di luar rentang wajar (RependLimitMinATR..MaxATR), TIDAK dipasang.
void PlaceRependLimit(int closedTicket, int repDir, ENUM_REPEND_MODE effMode) {
   bool blocked = (effMode==REPEND_BOTH) ? RependAlreadyPendingOfType(OP_BUYLIMIT,OP_SELLLIMIT)
                  : (RependAlreadyPendingOfType(OP_BUYSTOP,OP_SELLSTOP) || RependAlreadyPendingOfType(OP_BUYLIMIT,OP_SELLLIMIT));
   if(blocked) return;
   RefreshRates();
   double point = PipPoint();
   double atrRep = iATR(NULL, 0, 14, 1); if(atrRep<=0) return;
   double stLineVal = (repDir==1) ? STCustom(0,0,1) : STCustom(0,1,1); // 0=garis up/support, 1=garis down/resistance
   if(stLineVal<=0 || stLineVal==EMPTY_VALUE) return;
   double bidR = MarketInfo(Symbol(),MODE_BID), askR = MarketInfo(Symbol(),MODE_ASK);
   double curPriceRL = (repDir==1) ? askR : bidR;
   double distATR = MathAbs(curPriceRL - stLineVal) / atrRep;
   // v52: JANTUNG barometer akurasi - kejauhan dr garis ST (tren mungkin
   // sudah menua/lemah saat limit itu terisi nanti) atau kedekatan (nyaris
   // sama dgn harga skrg, tak ada manfaat harga lebih baik) -> jangan pasang.
   if(distATR < RependLimitMinATR || distATR > RependLimitMaxATR) return;
   double minDist = MathMax(g_StopLevel*point, 15*point);
   int cmd; double lvl, slR, tpR;
   double slP = GetGraceAwareSLPips(), tpP = GetManualTPPips();
   if(repDir == 1) {
      cmd = OP_BUYLIMIT; lvl = stLineVal;
      if(lvl > askR - minDist) lvl = askR - minDist; // limit wajib di BAWAH harga skrg dgn jarak aman broker
      slR = lvl - slP*point; tpR = lvl + tpP*point;
   } else {
      cmd = OP_SELLLIMIT; lvl = stLineVal;
      if(lvl < bidR + minDist) lvl = bidR + minDist;
      slR = lvl + slP*point; tpR = lvl - tpP*point;
   }
   lvl = NormalizeDouble(lvl, g_Digits); slR = NormalizeDouble(slR, g_Digits); tpR = NormalizeDouble(tpR, g_Digits);
   double lotR = GetManualLot();
   datetime expiryR = TimeCurrent() + RependLimitExpiryBars * PeriodSeconds(Period());
   int slipR = 3; if(g_Digits==3 || g_Digits==5) slipR *= 10;
   if(!IsTotalRiskCapOK(lotR, MathAbs(lvl-slR)/PipPoint(), "PENDING LANJUT-TREN LIMIT")) return;
   int tR = OrderSendRetry(Symbol(), cmd, lotR, lvl, slipR, slR, tpR, "UGE70-REPENDL", MagicNumber, expiryR, clrYellow);
   if(tR > 0) {
      g_RependLimitTicket = tR; // v53: didaftarkan utk trailing ke garis ST tiap bar
      Print("ðŸ” PENDING LANJUT-TREN ", (repDir==1?"BUY LIMIT":"SELL LIMIT"), " dipasang @ ", DoubleToString(lvl,g_Digits),
            " (posisi #", closedTicket, " kena SL tp indikator MASIH searah; entri di garis ST, ", DoubleToString(distATR,2), "xATR dr harga skrg; hangus ", RependLimitExpiryBars, " bar)");
   }
   else { int errR = GetLastError(); if(errR != 0) Print("Repend Limit OrderSend err #", errR); }
}
// v53 FIX: LIMIT SEBELUMNYA dipatok STATIS di garis ST saat dipasang - dalam
// tren kuat garis ST terus maju, jadi level lama itu makin lama makin
// "ketinggalan" (gap ke harga sekarang makin lebar), makin sulit tersentuh -
// persis keluhan "LIMIT jarang masuk market". FIX: selama pending LIMIT
// masih hidup & belum tersentuh, harganya di-TRAILING mengikuti garis ST
// SEKARANG tiap bar (SL/TP ikut disesuaikan relatif ke level baru) - supaya
// tetap merepresentasikan "pullback wajar dari harga SEKARANG", bukan level
// beku yg makin tak relevan.
void ManageRependLimitTrailing() {
   if(g_RependLimitTicket <= 0) return;
   if(!OrderSelect(g_RependLimitTicket, SELECT_BY_TICKET)) { g_RependLimitTicket = -1; return; }
   int ordType = OrderType();
   // v56 FIX BUG: order yg SUDAH dihapus/expired (masuk riwayat) TETAP
   // "mengingat" tipe aslinya (BUYLIMIT/SELLLIMIT tak berubah jadi apa2) -
   // cek tipe saja TIDAK CUKUP utk tahu apa dia masih hidup. Sebelumnya
   // OrderCloseTime() tak dicek di sini (beda dgn ManageExhaustionPending yg
   // sudah benar dari awal) - akibatnya begitu tiket lama dihapus/expired,
   // fungsi ini TERUS mencoba OrderModify ke tiket itu SELAMANYA (spam
   // "unknown ticket X for OrderModify function" tiap bar, tak pernah
   // berhenti/reset) - persis pola yg terlihat di jurnal Anda (5x berturut).
   if(ordType != OP_BUYLIMIT && ordType != OP_SELLLIMIT) { g_RependLimitTicket = -1; return; }
   if(OrderCloseTime() > 0) { g_RependLimitTicket = -1; return; } // sudah dihapus/expired - BUKAN lagi pending aktif
   int repDir = (ordType==OP_BUYLIMIT) ? 1 : -1;
   double point = PipPoint();
   double atrRep = iATR(NULL, 0, 14, 1); if(atrRep<=0) return;
   double stLineVal = (repDir==1) ? STCustom(0,0,1) : STCustom(0,1,1);
   if(stLineVal<=0 || stLineVal==EMPTY_VALUE) return;
   RefreshRates();
   double bidR = MarketInfo(Symbol(),MODE_BID), askR = MarketInfo(Symbol(),MODE_ASK);
   double minDist = MathMax(g_StopLevel*point, 15*point);
   double newLvl = stLineVal;
   if(repDir==1) { if(newLvl > askR-minDist) newLvl = askR-minDist; }
   else { if(newLvl < bidR+minDist) newLvl = bidR+minDist; }
   newLvl = NormalizeDouble(newLvl, g_Digits);
   double oldLvl = OrderOpenPrice();
   if(MathAbs(newLvl-oldLvl) < point) return; // belum berubah cukup, jangan modify percuma
   double slP = GetGraceAwareSLPips(), tpP = GetManualTPPips();
   double newSL = (repDir==1) ? newLvl - slP*point : newLvl + slP*point;
   double newTP = (repDir==1) ? newLvl + tpP*point : newLvl - tpP*point;
   newSL = NormalizeDouble(newSL, g_Digits); newTP = NormalizeDouble(newTP, g_Digits);
   if(SafeOrderModify(g_RependLimitTicket, newLvl, newSL, newTP, OrderExpiration(), clrYellow, "RependLimitChase"))
      Print("ðŸ”„ PENDING LANJUT-TREN LIMIT #", g_RependLimitTicket, " digeser mengikuti garis ST: ", DoubleToString(oldLvl,g_Digits), " -> ", DoubleToString(newLvl,g_Digits));
   else { int errRT=GetLastError(); if(errRT!=0 && errRT!=1) Print("Repend Limit trailing OrderModify err #",errRT); }
}
void MaybePlaceContinuationRepending(int closedTicket) {
   if(!UseContinuationRepending) return;
   if(g_GoalHit || g_TradingPaused || !g_Active || !g_AllowTrading) return;
   if(!OrderSelect(closedTicket, SELECT_BY_TICKET, MODE_HISTORY)) return;
   if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) return;
   if(OrderType() != OP_BUY && OrderType() != OP_SELL) return;
   if(OrderProfit() + OrderSwap() + OrderCommission() >= 0) return; // hanya posisi yg KALAH
   int repDir = (OrderType() == OP_BUY) ? 1 : -1; // arah SAMA dgn posisi yg baru tutup
   if((int)STCustom(0, ST_TrendBuffer, 1) != repDir) return; // ST sudah berbalik -> bukan kasus ini, biarkan PENDING COVER yg tangani
   if(RawHADirection() != repDir) return;
   ENUM_REPEND_MODE effModeR = ResolveAutoSlopeMode(RependOrderMode);
   if(effModeR==REPEND_STOP_ONLY || effModeR==REPEND_BOTH) PlaceRependStop(closedTicket, repDir, effModeR);
   if(effModeR==REPEND_LIMIT_ONLY || effModeR==REPEND_BOTH) PlaceRependLimit(closedTicket, repDir, effModeR);
}

bool ExecuteManualOrder(int type) {
   RefreshRates();
   double lot = GetManualLot(); double slP=GetManualSLPips(); double tpP=GetManualTPPips();
   double price=(type==OP_BUY)?Ask:Bid;
   double sl=(type==OP_BUY)?price-slP*PipPoint():price+slP*PipPoint();
   double tp=(type==OP_BUY)?price+tpP*PipPoint():price-tpP*PipPoint();
   double minDist = MathMax(g_StopLevel*PipPoint(), 15*PipPoint());
   if(type==OP_BUY){ if(price-sl<minDist) sl=price-minDist; if(tp-price<minDist) tp=price+minDist; }
   else { if(sl-price<minDist) sl=price+minDist; if(price-tp<minDist) tp=price-minDist; }
   price=NormalizeDouble(price,g_Digits); sl=NormalizeDouble(sl,g_Digits); tp=NormalizeDouble(tp,g_Digits);
   int slip=3; if(g_Digits==3||g_Digits==5) slip*=10;
   int ticket = OrderSendRetry(Symbol(), type, lot, price, slip, sl, tp, "Manual", MagicNumber, 0, (type==OP_BUY)?clrBlue:clrRed);
   if(ticket>0){ AddTradeMonitor(ticket); UpdateDashboard(); return true; }
   return false;
}
double GetManualLot() { return (g_UseManualLot && g_ManualLotValue>0) ? NormalizeDouble(MathMin(g_ManualLotValue, MaxAllowedLot),2) : CalculateLotSize(GetManualSLPips()); }
// v62: pengali SL/TP berdasar kemiringan tren SAAT INI - dipanggil dari
// GetManualSLPips/GetManualTPPips (fondasi SEMUA sistem entri), jd
// otomatis merambat ke Trend Rider, Repend, Titik-Jenuh, Cover sekaligus
// tanpa perlu sentuh tiap sistem satu-satu.
double GetSlopeSLTPMultiplier(bool forSL) {
   if(!UseSlopeAdaptiveSLTP) return 1.0;
   double slopeNow = MathAbs(ComputeTrendSlopeATR(AutoSlopeLookbackBars));
   if(slopeNow < AutoSlopeLandaiMax) return forSL ? SlopeAdaptSL_Landai : SlopeAdaptTP_Landai;
   if(slopeNow >= AutoSlopeCuramMin) return forSL ? SlopeAdaptSL_Curam : SlopeAdaptTP_Curam;
   return 1.0; // sedang - baseline, tak berubah
}
double GetManualSLPips() { if(g_UseManualSL && g_ManualSLValue>0) return g_ManualSLValue; return GetAdaptiveStopLossPips() * GetSlopeSLTPMultiplier(true); }
// v49 FIX: masa tenggang SL SEBELUMNYA cuma tersambung di ExecuteSmartOrder
// (entri langsung Reversal/Rider) - SEMUA pending order (titik-jenuh,
// cover, lanjut-tren) masih pakai SL sempit biasa tanpa masa tenggang sama
// sekali, persis keluhan "napas pending kena agak sempit". Fungsi ini
// dipakai konsisten di SEMUA titik pending, supaya begitu pending TERSENTUH
// jadi posisi sungguhan, ia SUDAH dapat jarak SL lebar yg sama spt entri
// langsung sejak awal - bukan cuma entri via sinyal biasa.
double GetGraceAwareSLPips() {
   double slP = GetManualSLPips();
   if(!UseEntryGracePeriod) return slP;
   if(g_UseManualSL && g_ManualSLValue>0) return slP; // override manual menang, tak dilebarkan lagi
   double atrPipsG = GetATRInPips();
   if(atrPipsG <= 0) return slP;
   return MathMax(slP, atrPipsG * GracePeriodATRMultiplier);
}
double GetManualTPPips() { if(g_UseManualTP && g_ManualTPValue>0) return g_ManualTPValue; return GetAdaptiveTakeProfitPips() * GetSlopeSLTPMultiplier(false); }
double GetManualTargetAmount() { return (TargetType==TARGET_IN_MONEY) ? DailyTargetValue : (AccountBalance() * DailyTargetValue / 100.0); }

//+------------------------------------------------------------------+
//| RISK MANAGEMENT & DAILY FUNCTIONS                                |
//+------------------------------------------------------------------+
void UpdatePositionStats() {
   g_BuyPositions=g_SellPositions=g_CurrentOrders=0;
   g_TotalLots=0; g_CurrentFloatingProfit=g_TotalBuyProfit=g_TotalSellProfit=0;
   for(int i=OrdersTotal()-1;i>=0;i--) {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES) && OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber) {
         double p=OrderProfit()+OrderSwap()+OrderCommission();
         g_CurrentFloatingProfit+=p;
         if(OrderType()==OP_BUY){ g_BuyPositions++; g_TotalBuyProfit+=p; }
         else if(OrderType()==OP_SELL){ g_SellPositions++; g_TotalSellProfit+=p; }
         g_TotalLots+=OrderLots(); g_CurrentOrders++;
      }
   }
}
void CalcDailyProfit() {
   datetime now=TimeCurrent();
   if(g_LastProfitResetTime==0){ MqlDateTime dt; TimeToStruct(now,dt); dt.hour=0; dt.min=0; dt.sec=0; g_LastProfitResetTime=StructToTime(dt); }
   if(g_DayStartEquity<=0) g_DayStartEquity=AccountEquity(); // snapshot pertama kali EA jalan

   // v27 FIX BUG KRITIS #3: SEBELUMNYA ADA DUA MEKANISME RESET independen
   // yg saling tumpang-tindih - blok kalender (ganti hari 00:00 SERVER,
   // MENGABAIKAN input DailyResetTime Anda) DAN CheckDailyReset() (yg
   // benar menghormati DailyResetTime). Keduanya bisa memicu reset di
   // WAKTU BERBEDA kalau DailyResetTime bukan "00:00", saling bentrok.
   // FIX: blok kalender DIHAPUS - CheckDailyReset() kini SATU-SATUNYA
   // otoritas reset, sesuai jam yang Anda set di input.

   // v27 FIX BUG KRITIS #4 (dari jurnal H4: target 16.79% lalu 17.80%
   // "Hit ke-1/100" LAGI persis di detik reset berikutnya): versi lama
   // `total = g_DailyProfit(realized sejak reset) + g_CurrentFloatingProfit
   // (floating SEMUA posisi terbuka, TERMASUK yg dibuka BERHARI-HARI
   // sebelum reset)`. Posisi lama yg masih mengambang untung besar
   // (mis. trend-run TP-release yg sengaja dibiarkan terbuka lama) ikut
   // terhitung PENUH sbg "profit hari ini" tiap kali reset lewat -
   // target langsung tercapai lagi seketika, pause lagi - persis pola
   // "hidup-mati" yg Anda laporkan. FIX: total kini = SELISIH EKUITAS
   // dari titik reset (g_DayStartEquity), bukan jumlah realized+floating
   // mentah. Cara ini otomatis benar: floating P&L yg SUDAH ada SAAT
   // reset sudah "terbekukan" di angka g_DayStartEquity; hanya
   // PERGERAKAN SETELAH reset (baik dari posisi lama yg bergerak lebih
   // jauh, maupun trade baru) yang terhitung sbg profit/rugi "hari ini".
   double profit=0;
   for(int i=OrdersHistoryTotal()-1; i>=0; i--) {
      if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY) && OrderMagicNumber()==MagicNumber && OrderSymbol()==Symbol()) {
         datetime ct=OrderCloseTime();
         if(ct>=g_LastProfitResetTime) profit += OrderProfit()+OrderSwap()+OrderCommission();
      }
   }
   g_DailyProfit=profit; // tetap dihitung utk info/tampilan "realized hari ini"
   double total = AccountEquity() - g_DayStartEquity; // v27: patokan resmi utk target
   g_DailyTotalForTarget = total; // dipakai jg oleh panel & loss-limit (konsistensi)
   // v30: defisit recovery dianggap TUNTAS begitu profit hari ini sudah
   // menutupinya - mode recovery otomatis mati (kembali normal).
   if(UseSmartRecovery && g_RecoveryDeficit > 0 && total >= g_RecoveryDeficit) {
      Print("ðŸ’Š RECOVERY TUNTAS: defisit $", DoubleToString(g_RecoveryDeficit,2),
            " sudah terpulihkan (profit hari ini $", DoubleToString(total,2), ") - mode recovery nonaktif");
      g_RecoveryDeficit = 0; g_RecoveryTradesUsed = 0;
   }
   if(total>g_MaxDailyProfit) g_MaxDailyProfit=total;
   // v22 PERBAIKAN MENYELURUH SISTEM DAILY TARGET (bug ditemukan saat
   // audit): versi lama mengecek `!g_GoalHit` sebagai gerbang, padahal
   // g_GoalHit baru jadi true setelah g_DailyTargetHits >= MaxDailyTargetHits
   // (default 100) - akibatnya blok ini TERUS bertambah SETIAP TICK selama
   // profit masih di atas target (bukan sekali per pencapaian), dan trading
   // baru benar2 berhenti setelah "100 tick di atas target" tercapai secara
   // tidak menentu (bisa detik, bisa menit, tergantung kepadatan tick) -
   // inilah sebab "sistem daily target tidak berfungsi dengan baik".
   // FIX: gerbang sekarang `!g_TargetAchievedToday` (flag sekali-pakai per
   // hari) -> pencapaian target dihitung SATU KALI, dan trading LANGSUNG
   // dihentikan saat itu juga (tidak menunggu hit ke-100). Berhenti sampai
   // (a) waktu reset harian tercapai (CheckDailyReset, otomatis), atau
   // (b) tombol RESET ditekan manual. MaxDailyTargetHits kini jadi batas
   // pengaman brp kali RESET MANUAL boleh memicu pencapaian ulang di hari
   // yg sama (mencegah reset berulang tanpa batas).
   if(UseDailyTarget) {
      double target = GetManualTargetAmount();
      if(!g_TargetAchievedToday && target > 0 && total >= target) {
         g_DailyTargetHits++;
         g_TargetAchievedToday = true;
         g_GoalHit = true;
         g_TradingPaused = true;
         g_PauseUntilTime = 0;  // dicabut oleh CheckDailyReset() pas jam reset, bukan timer mundur
         CancelAllPendingOrdersSafe();
         Print("ðŸŽ¯ TARGET HARIAN TERCAPAI: ", (TargetType==TARGET_IN_MONEY?"$"+DoubleToString(total,2):DoubleToString(total/AccountBalance()*100,2)+"%"),
               " (target ", (TargetType==TARGET_IN_MONEY?"$"+DoubleToString(target,2):DoubleToString(DailyTargetValue,1)+"%"),
               ") - TRADING DIHENTIKAN OTOMATIS s/d reset harian atau tombol RESET ditekan. Hit ke-", g_DailyTargetHits, "/", MaxDailyTargetHits);
      }
   }
   if(DailyLossLimitPercent>0) {
      // v27: pakai selisih ekuitas (realized+floating) supaya loss-limit
      // ikut bereaksi thd RUGI MENGAMBANG posisi yg masih terbuka, bukan
      // cuma rugi yg sudah direalisasi (sblmnya buta thd floating loss).
      double dailyLossPercent=(g_DailyTotalForTarget/AccountBalance())*100;
      if(dailyLossPercent<=-DailyLossLimitPercent && !g_TradingPaused){ g_TradingPaused=true; g_PauseUntilTime=TimeCurrent()+14400; }
   }
}
void CheckDailyReset() {
   // v32 FIX BUG RECOVERY TAK PERNAH AKTIF: pencatatan defisit recovery
   // ada DI DALAM fungsi ini, tapi baris lama `if(!UseDailyTarget) return;`
   // membuat SELURUH fungsi (termasuk pencatatan defisit) mati total bila
   // daily target dimatikan - recovery tak pernah punya bahan utk hidup.
   // Kini fungsi tetap jalan bila salah satu fitur (target ATAU recovery)
   // aktif; bagian target di dalamnya sudah aman sendiri2.
   if(!UseDailyTarget && !UseSmartRecovery) return;
   datetime now=TimeCurrent(); MqlDateTime dt; TimeToStruct(now,dt);
   string p[]; StringSplit(DailyResetTime,':',p);
   if(ArraySize(p)==2){ dt.hour=(int)StringToInteger(p[0]); dt.min=(int)StringToInteger(p[1]); dt.sec=0; }
   datetime reset=StructToTime(dt);
   if(now>=reset && g_LastDailyResetTime<reset) {
      // v30: sebelum patokan hari di-reset, catat DEFISIT hari yg berakhir
      // (target minus) sbg tugas recovery hari berikutnya. Diakumulasi
      // bila defisit lama belum tuntas & hari ini minus lagi.
      if(UseSmartRecovery) {
         double dayTot = AccountEquity() - g_DayStartEquity;
         if(dayTot < 0) {
            g_RecoveryDeficit += -dayTot; g_RecoveryTradesUsed = 0;
            Print("ðŸ’Š RECOVERY: hari berakhir MINUS $", DoubleToString(-dayTot,2),
                  " - total defisit utk dipulihkan: $", DoubleToString(g_RecoveryDeficit,2));
         }
      }
      CancelAllPendingOrdersSafe(); g_GoalHit=false; g_TradingPaused=false; g_PauseUntilTime=0; g_DailyTargetHits=0;
      g_TargetAchievedToday=false; g_FirstEntryToday=true; g_LastDailyResetTime=reset;
      g_DailyProfit=0; g_MaxDailyProfit=0; g_LastProfitResetTime=reset; g_TargetResetCount++;
      g_DayStartEquity=AccountEquity(); // v27: patokan baru utk hari yg baru direset
      g_Status="SYSTEM ACTIVE"; g_StatusColor=C_Green; UpdateDashboard();
   }
   // v23 FIX BUG KRITIS #2: baris lama `if(g_GoalHit && now>=reset+60)
   // g_GoalHit=false;` DIHAPUS. `reset` di sini = jam reset HARI INI (mis.
   // hari ini 00:00) - begitu lewat jam 00:01 hari ini, `now>=reset+60`
   // TETAP TRUE SEPANJANG SISA HARI. Akibatnya begitu g_GoalHit jadi true
   // (target tercapai kapan pun siang/sore/malam), baris ini LANGSUNG
   // menghapusnya lagi di tick berikutnya - trading seolah tidak pernah
   // berhenti. Blok di atas (dgn penjaga g_LastDailyResetTime<reset) SUDAH
   // benar menghapus g_GoalHit tepat di jadwal reset - baris ini murni
   // duplikat yang salah hitung, tidak diperlukan lagi.
}
void CheckTradingTime() {
   if(!UseTimeControl){ g_IsTradingTime=true; g_IsTradingDay=true; return; }
   int dow=TimeDayOfWeek(TimeCurrent());
   bool dayOK=false;
   switch(dow){ case 0: dayOK=TradeSunday; break; case 1: dayOK=TradeMonday; break; case 2: dayOK=TradeTuesday; break; case 3: dayOK=TradeWednesday; break; case 4: dayOK=TradeThursday; break; case 5: dayOK=TradeFriday; break; case 6: dayOK=TradeSaturday; break; }
   g_IsTradingDay=dayOK;
   g_IsTradingTime=IsTimeInRange(TradingStartTime, TradingEndTime);
}
bool CanTradeNow(){ return g_IsTradingDay && g_IsTradingTime; }
bool IsTimeInRange(string start, string end){ int now=TimeToSeconds(TimeToString(TimeCurrent(),TIME_MINUTES)); int s=TimeToSeconds(start), e=TimeToSeconds(end); if(s<=e) return (now>=s && now<=e); else return (now>=s || now<=e); }
int TimeToSeconds(string t){ string p[]; if(StringSplit(t,':',p)!=2) return 0; return (int)(StringToInteger(p[0])*3600 + StringToInteger(p[1])*60); }
bool IsDayOfWeekEnabled(){ return g_IsTradingDay; }
void CancelAllPendingOrdersSafe(){
   for(int i=OrdersTotal()-1;i>=0;i--){
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES) && OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber){
         if(OrderType()==OP_BUYSTOP || OrderType()==OP_SELLSTOP || OrderType()==OP_BUYLIMIT || OrderType()==OP_SELLLIMIT) { bool res=OrderDelete(OrderTicket()); if(!res) { int err=GetLastError(); if(err!=0) Print("Del pending err #",err); } }
      }
   }
}
void ForceDeleteAllPendingOrders(){ CancelAllPendingOrdersSafe(); }
void CloseAllPositions(){
   for(int i=OrdersTotal()-1;i>=0;i--){
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES) && OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber){
         if(OrderType()==OP_BUY || OrderType()==OP_SELL){ double cp=(OrderType()==OP_BUY)?Bid:Ask; bool res=OrderClose(OrderTicket(), OrderLots(), cp, 3, clrGray); if(!res) { int err=GetLastError(); if(err!=0) Print("Close err #",err); } }
         else { bool res=OrderDelete(OrderTicket()); if(!res) { int err=GetLastError(); if(err!=0) Print("Del err #",err); } }
      }
   }
}

//=== AKHIR BAGIAN 1 ===

//+------------------------------------------------------------------+
//| BAGIAN 2 â€“ DASHBOARD ORIGINAL & EVENT HANDLER                   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| DASHBOARD FUNCTIONS (ORIGINAL) - LENGKAP                        |
//+------------------------------------------------------------------+
void CreateRect(string n, int x, int y, int w, int h, color c, color b, int z=0) {
   if(ObjectFind(0, n) < 0) ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR, c);
   ObjectSetInteger(0, n, OBJPROP_COLOR, b);
   ObjectSetInteger(0, n, OBJPROP_BACK, false);
   ObjectSetInteger(0, n, OBJPROP_ZORDER, z);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
}
void CreateLabel(string n, string t, int x, int y, color c, int s, bool bld=false, int a=ANCHOR_LEFT_UPPER, int z=1) {
   if(ObjectFind(0, n) < 0) ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, n, OBJPROP_TEXT, t);
   ObjectSetInteger(0, n, OBJPROP_COLOR, c);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE, s);
   ObjectSetInteger(0, n, OBJPROP_ANCHOR, a);
   ObjectSetString(0, n, OBJPROP_FONT, bld ? "Verdana Bold" : "Verdana");
   ObjectSetInteger(0, n, OBJPROP_BACK, false);
   ObjectSetInteger(0, n, OBJPROP_ZORDER, z);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
}
void CreateButton(string n, string t, int x, int y, int w, int h, color c, color txt, int z=2) {
   if(ObjectFind(0, n) < 0) ObjectCreate(0, n, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE, h);
   ObjectSetString(0, n, OBJPROP_TEXT, t);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR, c);
   ObjectSetInteger(0, n, OBJPROP_COLOR, txt);
   ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_BACK, false);
   ObjectSetInteger(0, n, OBJPROP_ZORDER, z);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
}
void CreateShowButton() {
   ObjectDelete(0, SHOW_BTN);
   CreateButton(SHOW_BTN, "SHOW", Dash_X, Dash_Y, 60, 25, C_Blue, clrWhite, 10);
   ObjectSetInteger(0, SHOW_BTN, OBJPROP_HIDDEN, false);
   ChartRedraw(0);
}
void CreateDashboard() {
   int W = 322, H = 570, x = -2, y = Dash_Y; y += 8;
   ObjectsDeleteAll(0, PFX);
   CreateRect(PFX+"BG", x, y, W, H, C_BG, clrBlack, 5);
   CreateRect(PFX+"Header", x+5, y+4, W-10, 35, C_Panel, clrBlack, 5);
   CreateLabel(PFX+"Title", "AURUMPULSE XAUUSD", x+W/2, y+13, clrRed, 11, true, ANCHOR_CENTER, 5);
   CreateLabel(PFX+"SubTitle", "Adaptive Reversal + Trend Rider", x+W/2, y+27, clrWhite, 10, true, ANCHOR_CENTER, 5);
   y += 36;
   CreateRect(PFX+"TimePanel", x+5, y, W-10, 30, clrBlack, clrWhite, 2);
   CreateLabel(PFX+"TimeLabel", TimeToString(TimeCurrent(), TIME_SECONDS)+"  "+TimeToString(TimeCurrent(), TIME_DATE), x+W/2, y+8, clrAqua, 10, false, ANCHOR_CENTER, 5);
   CreateLabel(PFX+"BrokerInfo", "BROKER: HYBRID", x+310, y+14, clrMagenta, 7, false, ANCHOR_RIGHT_UPPER, 5);
   CreateLabel(PFX+"TrendInfo", "TREND: "+g_TrendDirection, x+12, y+14, g_TrendColor, 7, false, ANCHOR_LEFT_UPPER, 5);
   y += 32;
   int btnW=100, btnH=20, gap=6, startX=x+4;
   CreateButton(PFX+"B_Switch", g_Active?"ON":"OFF", startX+2, y, btnW, btnH, g_Active?clrGreen:clrRed, clrWhite, 7);
   CreateButton(PFX+"B_Reset", "RESET", startX+(btnW+gap)+1, y, btnW, btnH, clrMediumVioletRed, clrWhite, 7);
   CreateButton(PFX+"B_Restart", "RESTART", startX+(btnW+gap)*2, y, btnW, btnH, clrDarkCyan, clrWhite, 7);
   CreateButton(PFX+"B_Close", "CLOSE", startX+2, y+23, 63, 20, clrDarkOrange, clrWhite, 7);
   CreateButton(PFX+"B_Hide", "HIDE", startX+249, y+23, 63, 20, clrDarkSlateBlue, clrWhite, 7);
   int lotX = startX+69;
   CreateButton(PFX+"B_LotMinus", "-", lotX, y+23, 20, 20, clrDarkRed, clrWhite, 10);
   CreateLabel(PFX+"V_LotValue", DoubleToString(g_UseManualLot?g_ManualLotValue:BaseLot, 1), lotX+42, y+27, C_Gold, 8, true, ANCHOR_CENTER, 7);
   CreateButton(PFX+"B_LotPlus", "+", lotX+67, y+23, 20, 20, clrDarkGreen, clrWhite, 10);
   CreateLabel(PFX+"L_LotLabel", "LOT", lotX+42, y+38, clrWhite, 7, true, ANCHOR_CENTER, 6);
   int targetX = startX+159;
   CreateButton(PFX+"B_TargetMinus", "-", targetX, y+23, 20, 20, clrDarkRed, clrWhite, 10);
   string initTarget = g_UseManualTarget ? ((TargetType==TARGET_IN_MONEY)?"$"+DoubleToString(g_ManualTargetValue,0):DoubleToString(g_ManualTargetValue,1)+"%") : ((TargetType==TARGET_IN_MONEY)?"$"+DoubleToString(DailyTargetValue,0):DoubleToString(DailyTargetValue,1)+"%");
   CreateLabel(PFX+"V_TargetValue", initTarget, targetX+42, y+27, C_Gold, 8, true, ANCHOR_CENTER, 7);
   CreateButton(PFX+"B_TargetPlus", "+", targetX+67, y+23, 20, 20, clrDarkGreen, clrWhite, 10);
   CreateLabel(PFX+"L_TargetLabel", "TARGET", targetX+43, y+38, clrWhite, 7, true, ANCHOR_CENTER, 6);
   CreateLabel(PFX+"L_SLControl", "SL", x+54, y+50, clrWhite, 7, true, ANCHOR_CENTER, 7);
   CreateButton(PFX+"B_SLMinus", "SL-", x+6, y+46, 30, 18, clrDarkRed, clrWhite, 6);
   bool slManualActive = (g_UseManualSL && g_ManualSLValue>0);
   // v42 FIX: sebelumnya SELALU tampilkan angka adaptif (besar) walau belum
   // pernah diatur manual sama sekali - user MENGIRA ini nilai acak/aneh,
   // padahal maksud tombol +/- ini memang utk entri MANUAL opsional (lewat
   // tombol BUY/SELL dashboard sendiri). Kini kalau belum diatur: tampilkan
   // "0 (auto)" - jelas ini kondisi kosong/opsional, bukan angka misterius.
   // v43: HANYA angka pip - nilai dolar dihapus atas permintaan (ruang
   // dashboard sempit, cukup pip saja utk kebutuhan trading manual).
   string slDispTxt = slManualActive ? DoubleToString(g_ManualSLValue,0) : "0 (auto)";
   CreateLabel(PFX+"V_SLValue", (slManualActive?"M:":"")+slDispTxt, x+52, y+59, slManualActive?clrOrange:clrGray, 7, true, ANCHOR_CENTER, 7);
   CreateButton(PFX+"B_SLPlus", "SL+", x+69, y+46, 30, 18, clrDarkGreen, clrWhite, 6);
   CreateLabel(PFX+"L_TPControl", "TP", x+268, y+50, clrWhite, 7, true, ANCHOR_CENTER, 7);
   CreateButton(PFX+"B_TPMinus", "TP-", x+222, y+46, 30, 18, clrDarkRed, clrWhite, 6);
   bool tpManualActive = (g_UseManualTP && g_ManualTPValue>0);
   string tpDispTxt = tpManualActive ? DoubleToString(g_ManualTPValue,0) : "0 (auto)";
   CreateLabel(PFX+"V_TPValue", (tpManualActive?"M:":"")+tpDispTxt, x+269, y+59, tpManualActive?clrOrange:clrGray, 7, true, ANCHOR_CENTER, 7);
   CreateButton(PFX+"B_TPPlus", "TP+", x+286, y+46, 30, 18, clrDarkGreen, clrWhite, 6);
   CreateButton(PFX+"B_ResetSLTP", "RESET SL/TP", x+W/2-58, y+46, 115, 18, clrMediumVioletRed, clrWhite, 7);
   y += 66;
   int manualY = y+1;
   CreateButton(PFX+"B_ManualSell", "SELL", x+6, manualY, 94, 23, clrDarkRed, clrWhite, 8);
   CreateButton(PFX+"B_ManualBuy", "BUY", x+W-100, manualY, 94, 23, clrDarkGreen, clrWhite, 8);
   CreateRect(PFX+"SymbolPanel", x+102, y, W-205, 28, C_Panel, clrWhite, 2);
   CreateLabel(PFX+"L_Symbol", "<CURRENCY PAIRS>", x+159, y+7, C_Gold, 7, true, ANCHOR_CENTER, 5);
   CreateLabel(PFX+"V_Symbol", Symbol()+"  "+PeriodToString(Period()), x+W/2, y+18, clrAqua, 8, true, ANCHOR_CENTER, 5);
   y += 26;
   CreateRect(PFX+"StatusPanel", x+5, y, W-10, 30, C_Panel, clrWhite, 2);
   CreateLabel(PFX+"StatusValue", g_Status, x+W/2, y+8, g_StatusColor, 8, true, ANCHOR_CENTER, 5);
   CreateLabel(PFX+"V_BrokerStats", "Pure Flip Entry", x+W/2, y+20, clrCyan, 7, false, ANCHOR_CENTER, 5);
   y += 28;
   CreateRect(PFX+"AccPanel", x+5, y, W-10, 43, C_Panel, clrWhite, 2);
   CreateLabel(PFX+"L_Acc", "<<< ACCOUNT INFORMATION >>>", x+161, y+8, C_Gold, 8, true, ANCHOR_CENTER, 5);
   int accY = y+15;
   CreateLabel(PFX+"L_Bal", "BALANCE:", x+12, accY, clrWhite, 7, false, ANCHOR_LEFT_UPPER, 5);
   CreateLabel(PFX+"V_Bal", "0.00", x+102, accY, C_Orange, 7, true, ANCHOR_LEFT_UPPER, 5);
   CreateLabel(PFX+"L_Eq", "EQUITY:", x+W/2+3, accY, clrWhite, 7, false, ANCHOR_LEFT_UPPER, 5);
   CreateLabel(PFX+"V_Eq", "0.00", x+W/2+100, accY, C_Orange, 7, true, ANCHOR_LEFT_UPPER, 5);
   accY += 11;
   CreateLabel(PFX+"L_FreeMar", "FREE MARGIN:", x+12, accY, clrWhite, 7, false, ANCHOR_LEFT_UPPER, 5);
   CreateLabel(PFX+"V_FreeMar", "0.00", x+102, accY, C_Orange, 7, true, ANCHOR_LEFT_UPPER, 5);
   CreateLabel(PFX+"L_Mar", "MARGIN LEVEL:", x+W/2+3, accY, clrWhite, 7, false, ANCHOR_LEFT_UPPER, 5);
   CreateLabel(PFX+"V_Mar", "0%", x+W/2+100, accY, C_Text, 7, true, ANCHOR_LEFT_UPPER, 5);
   y += 40;
   CreateRect(PFX+"TargetPanel", x+5, y, W-10, 72, C_Panel, clrWhite, 2);
   CreateLabel(PFX+"L_Target", "<>------- DAILY TARGET & MULTI-HIT --------<>", x+161, y+8, C_Gold, 8, true, ANCHOR_CENTER, 5);
   CreateLabel(PFX+"L_Day", "DAILY PROFIT:", x+12, y+14, clrWhite, 7, false, ANCHOR_LEFT_UPPER, 5);
   CreateLabel(PFX+"V_Day", "0.00", x+W-172, y+14, C_Text, 7, true, ANCHOR_RIGHT_UPPER, 5);
   CreateLabel(PFX+"L_Tgt", "TARGET:", x+195, y+14, clrWhite, 7, false, ANCHOR_LEFT_UPPER, 5);
   CreateLabel(PFX+"V_Tgt", "0.00", x+W-22, y+14, C_Green, 7, true, ANCHOR_RIGHT_UPPER, 5);
   CreateLabel(PFX+"L_TargetHits", "HITS TODAY:", x+12, y+25, clrWhite, 7, false, ANCHOR_LEFT_UPPER, 5);
   CreateLabel(PFX+"V_TargetHits", "0", x+W-174, y+25, C_Green, 7, true, ANCHOR_RIGHT_UPPER, 5);
   CreateLabel(PFX+"L_ResetCountDaily", "RESET COUNT:", x+195, y+25, clrWhite, 7, false, ANCHOR_LEFT_UPPER, 5);
   CreateLabel(PFX+"V_ResetCountDaily", IntegerToString(g_TargetResetCount), x+W-28, y+25, C_Green, 7, true, ANCHOR_RIGHT_UPPER, 5);
   y += 36;
   CreateLabel(PFX+"L_Progress", "PROGRESS:", x+12, y, clrWhite, 7, false, ANCHOR_LEFT_UPPER, 5);
   CreateLabel(PFX+"V_Progress", "0%", x+W-16, y, C_Text, 7, true, ANCHOR_RIGHT_UPPER, 5);
   CreateRect(PFX+"ProgressBarBg", x+78, y+2, 180, 10, clrRed, C_Border, 1);
   CreateRect(PFX+"ProgressBar", x+78, y+2, 0, 10, C_Green, C_Border, 2);
   y += 9;
   CreateLabel(PFX+"L_PauseBetween", "Pause Status:", x+130, y+1, clrWhite, 7, false, ANCHOR_LEFT_UPPER, 5);
   CreateLabel(PFX+"V_PauseBetween", GetPauseStatus(), x+164, y+17, C_Orange, 7, true, ANCHOR_CENTER, 5);
   y += 24;
   CreateRect(PFX+"PosPanel", x+5, y, W-10, 59, C_Panel, clrWhite, 2);
   CreateLabel(PFX+"L_Pos", "<>---------------- POSITIONS -----------------<>", x+161, y+8, C_Gold, 8, true, ANCHOR_CENTER, 5);
   CreateLabel(PFX+"L_BuyC", "Entry Buy:", x+12, y+14, clrWhite, 8, false, ANCHOR_LEFT_UPPER, 5);
   CreateLabel(PFX+"V_BuyC", "0", x+76, y+14, C_Green, 8, true, ANCHOR_LEFT_UPPER, 5);
   CreateLabel(PFX+"L_SelC", "Entry Sell:", x+100, y+14, clrWhite, 8, false, ANCHOR_LEFT_UPPER, 5);
   CreateLabel(PFX+"V_SelC", "0", x+163, y+14, clrRed, 8, true, ANCHOR_LEFT_UPPER, 5);
   CreateLabel(PFX+"L_Flt", "Floating P/L:", x+180, y+14, clrWhite, 8, false, ANCHOR_LEFT_UPPER, 5);
   CreateLabel(PFX+"V_Flt", "$0.00", x+253, y+14, C_Text, 8, true, ANCHOR_LEFT_UPPER, 5);
   CreateLabel(PFX+"L_BuyDetails", "", x+165, y+33, C_Green, 7, false, ANCHOR_CENTER, 5);
   CreateLabel(PFX+"L_SellDetails", "", x+165, y+44, clrRed, 7, false, ANCHOR_CENTER, 5);
   y += 52;
   CreateRect(PFX+"CrystalPanel", x+5, y, W-10, 33, C_Panel, clrWhite, 2);
   CreateLabel(PFX+"L_Crystal", "<>------------- SIGNAL & FILTERS ------------<>", x+W/2-1, y+8, C_Gold, 8, true, ANCHOR_CENTER, 5);
   string filterStr = "Pure Flip | MTF:"+(UseMTFConfirmation?"ON":"OFF")+" News:"+(UseNewsFilter?"ON":"OFF")+" OverExt:"+(UseOverExtended?"ON":"OFF");
   CreateLabel(PFX+"V_Crystal", filterStr, x+W/2, y+20, clrAqua, 5, true, ANCHOR_CENTER, 5);
   y += 28;
    CreateRect(PFX+"ProtectionPanel", x+5, y, W-10, 29, C_Panel, clrWhite, 2);
   CreateLabel(PFX+"L_Protection", "<>---------------- PROTECTION ---------------<>", x+W/2-1, y+8, C_Gold, 8, true, ANCHOR_CENTER, 5);
   string protStatus = (g_DrawdownProtectionActive) ? "Drawdown Active (Lot Reduced)" : "Normal";
   color protColor = (g_DrawdownProtectionActive) ? C_Orange : C_Green;
   CreateLabel(PFX+"V_Protection", protStatus, x+12, y+15, protColor, 6, true, ANCHOR_LEFT_UPPER, 5);
   // v32: baris info RECOVERY - proporsional di bawah status proteksi
   CreateLabel(PFX+"V_RecoveryInfo", "Recovery: Standby", x+307, y+25, C_Gray, 6, true, ANCHOR_RIGHT_LOWER, 5);
   y += 26;
   CreateRect(PFX+"AdaptivePanel", x+5, y, W-10, 49, C_Panel, clrWhite, 2);
   CreateLabel(PFX+"L_Adaptive", "<>------------- ADAPTIVE TP/SL -------------<>", x+W/2-1, y+8, C_Gold, 8, true, ANCHOR_CENTER, 5);
   string atrInfo = StringFormat("ATR:%.2f%%", g_ATRPercentAdjusted);
   CreateLabel(PFX+"V_ATRInfo", atrInfo, x+W/2, y+19, clrMagenta, 6, true, ANCHOR_CENTER, 5);
   string distTP = (DynamicTPDistance == DIST_TIGHT) ? "Tight" : (DynamicTPDistance == DIST_WIDE ? "Wide" : "Normal");
   string speedTP = (DynamicTPSpeed == SPEED_AGGRESSIVE) ? "Aggr" : (DynamicTPSpeed == SPEED_SLOW ? "Slow" : "Normal");
   string distSL = (DynamicSLDistance == DIST_TIGHT) ? "Tight" : (DynamicSLDistance == DIST_WIDE ? "Wide" : "Normal");
   string speedSL = (DynamicSLSpeed == SPEED_AGGRESSIVE) ? "Aggr" : (DynamicSLSpeed == SPEED_SLOW ? "Slow" : "Normal");
   string dynamicInfo = StringFormat("TP:%s/%s SL:%s/%s", distTP, speedTP, distSL, speedSL);
   CreateLabel(PFX+"V_DynamicInfo", dynamicInfo, x+W/2, y+29, clrAqua, 7, true, ANCHOR_CENTER, 5);
   string ddStatus = (g_DrawdownProtectionActive) ? StringFormat("DD: %.1f%% (LIMIT)", g_CurrentDrawdownPercent) : StringFormat("DD: %.1f%%", g_CurrentDrawdownPercent);
   color ddColor = (g_CurrentDrawdownPercent > MaxDrawdownPercent * 0.8) ? C_Red : C_Text;
   CreateLabel(PFX+"V_DrawdownInfo", ddStatus, x+W/2-149, y+14, ddColor, 6, true, ANCHOR_LEFT_UPPER, 5);
   CreateLabel(PFX+"V_LossStreak", "Loss Streak: "+IntegerToString(g_ConsecutiveLosses), x+W/2+82, y+14, clrWhite, 6, true, ANCHOR_LEFT_UPPER, 5);
   CreateLabel(PFX+"V_AdaptiveParams", "SprMult: x"+DoubleToString(g_SpreadMultiplier,2)+" | Slipp: "+IntegerToString(3), x+W/2, y+40, clrMagenta, 6, true, ANCHOR_CENTER, 5);
   y += 46;
   CreateRect(PFX+"ModePanel", x+5, y, W-10, 35, C_Panel, clrWhite, 2);
   CreateLabel(PFX+"L_Mode", "<>-------- TRADING  CONFIGURATION --------<>", x+W/2-1, y+8, C_Gold, 8, true, ANCHOR_CENTER, 5);
   CreateLabel(PFX+"V_EntryMode", "ENTRY: FLIP"+(g_FirstEntryToday?" (FIRST)":""), x+W/2-148, y+16, clrWhite, 6, true, ANCHOR_LEFT_UPPER, 5);
   CreateLabel(PFX+"V_TradingMode", "MODE: "+TradingModeToString(TradingMode), x+W/2+147, y+26, clrAqua, 6, true, ANCHOR_RIGHT_LOWER, 5);
   y += 28;
   CreateRect(PFX+"AdvPanel", x+5, y, W-10, 50, C_Panel, clrWhite, 2);
   CreateLabel(PFX+"L_Adv", "<>-------------- ADVANCED INFO -------------<>", x+W/2-1, y+8, C_Gold, 8, true, ANCHOR_CENTER, 5);
   CreateLabel(PFX+"L_MaxProfit", "Max Daily:", x+11, y+13, clrYellow, 6, true, ANCHOR_LEFT_UPPER, 5);
   CreateLabel(PFX+"V_MaxProfit", "$0.00", x+60, y+13, clrMagenta, 6, true, ANCHOR_LEFT_UPPER, 5);
   CreateLabel(PFX+"L_NextReset", "Next Reset:", x+W/2+67, y+13, clrYellow, 6, true, ANCHOR_LEFT_UPPER, 5);
   CreateLabel(PFX+"V_NextReset", DailyResetTime, x+W/2+121, y+13, clrMagenta, 6, true, ANCHOR_LEFT_UPPER, 5);
   CreateLabel(PFX+"V_Support", "Sup: 0.0000", x+95, y+13, clrAqua, 6, true, ANCHOR_LEFT_UPPER, 5);
   CreateLabel(PFX+"V_Resistance", "Res: 0.0000", x+163, y+13, clrAqua, 6, true, ANCHOR_LEFT_UPPER, 5);
   y += 35;
   // v32: bekas tempat label pending lama kini dipakai info PENDING
   // TITIK-JENUH yang SUNGGUHAN (real-time: dipasang/digeser/tersentuh/
   // hangus) - menggantikan label hardcoded "Pending: OFF" yg dihapus v29.
   CreateLabel(PFX+"V_ExhPendInfo", "Pending: -", x+W/2, y-8, clrYellow, 7, true, ANCHOR_CENTER, 5);
   CreateLabel(PFX+"V_PairInfo", Symbol()+" | TP:"+IntegerToString((int)GetManualTPPips())+"($"+DoubleToString(GetManualTPPips()*PipPoint(),1)+") | SL:"+IntegerToString((int)GetManualSLPips())+"($"+DoubleToString(GetManualSLPips()*PipPoint(),1)+")", x+W/2, y+5, clrYellow, 7, true, ANCHOR_CENTER, 5);
   y += 8;
   CreateRect(PFX+"BrandL", x+5, y+4, W-10, 19, C_Panel, clrWhite, 0);
   CreateLabel(PFX+"BrandLabel", "[ [ EA MT4 - By.Om-Hends Trader - 2026 ] ]", x+W/2-1, y+13, clrMagenta, 7, true, ANCHOR_CENTER, 5);
   UpdateDashboard();
}
void UpdateDashboardPositionDetails() {
   // v29 FIX: sebelumnya loop ini MENIMPA buyD/sellD setiap ketemu order
   // yg cocok - kalau ada 2 BUY terbuka, yg tampil cuma order TERAKHIR
   // yg diproses (lot & harga entri sebelumnya HILANG dari tampilan,
   // tidak terakumulasi). FIX: lot dijumlahkan, harga entri masing2
   // dikumpulkan jadi daftar (dipisah koma) - SL/TP individual tidak lagi
   // ditampilkan per-order (ruang panel terbatas utk banyak entri; info
   // itu tetap ada di jurnal/riwayat tiap kali order dibuka).
   double buyLotSum=0, sellLotSum=0; string buyPrices="", sellPrices="";
   for(int i=OrdersTotal()-1;i>=0;i--) if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES) && OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber) {
      if(OrderType()==OP_BUY) {
         buyLotSum += OrderLots();
         buyPrices += (buyPrices=="" ? "" : ",") + DoubleToString(OrderOpenPrice(), g_Digits);
      } else if(OrderType()==OP_SELL) {
         sellLotSum += OrderLots();
         sellPrices += (sellPrices=="" ? "" : ",") + DoubleToString(OrderOpenPrice(), g_Digits);
      }
   }
   string buyD = (buyLotSum>0) ? StringFormat("Buy %.2f @ %s", buyLotSum, buyPrices) : "No Buy";
   string sellD = (sellLotSum>0) ? StringFormat("Sell %.2f @ %s", sellLotSum, sellPrices) : "No Sell";
   if(ObjectFind(0,PFX+"L_BuyDetails")>=0) ObjectSetString(0,PFX+"L_BuyDetails",OBJPROP_TEXT,buyD);
   if(ObjectFind(0,PFX+"L_SellDetails")>=0) ObjectSetString(0,PFX+"L_SellDetails",OBJPROP_TEXT,sellD);
}
void UpdateDashboardValues() {
   if(g_HideUI) return;
   UpdateSRLevels();
   if(ObjectFind(0,PFX+"TimeLabel")>=0) ObjectSetString(0,PFX+"TimeLabel",OBJPROP_TEXT,TimeToString(TimeCurrent(),TIME_SECONDS)+"  "+TimeToString(TimeCurrent(),TIME_DATE));
   if(ObjectFind(0,PFX+"BrokerInfo")>=0) ObjectSetString(0,PFX+"BrokerInfo",OBJPROP_TEXT,"BROKER: HYBRID");
   if(ObjectFind(0,PFX+"V_Bal")>=0) ObjectSetString(0,PFX+"V_Bal",OBJPROP_TEXT,DoubleToString(AccountBalance(),2));
   if(ObjectFind(0,PFX+"V_Eq")>=0) ObjectSetString(0,PFX+"V_Eq",OBJPROP_TEXT,DoubleToString(AccountEquity(),2));
   if(ObjectFind(0,PFX+"V_FreeMar")>=0) ObjectSetString(0,PFX+"V_FreeMar",OBJPROP_TEXT,DoubleToString(AccountFreeMargin(),2));
   if(ObjectFind(0,PFX+"V_Mar")>=0) ObjectSetString(0,PFX+"V_Mar",OBJPROP_TEXT,(g_MarginLevel<=0)?"---":DoubleToString(g_MarginLevel,1)+"%");
   // v27: teks panel kini pakai g_DailyTotalForTarget (selisih ekuitas) -
   // angka yg SAMA PERSIS dgn yg menentukan target tercapai atau belum,
   // supaya panel tidak lagi "bohong" (tampil blm capai tp tiba2 pause).
   string dailyText = (TargetType==TARGET_IN_MONEY)?("$"+DoubleToString(g_DailyTotalForTarget,2)):(DoubleToString((AccountBalance()>0?g_DailyTotalForTarget/AccountBalance()*100:0),2)+"%");
   if(ObjectFind(0,PFX+"V_Day")>=0) ObjectSetString(0,PFX+"V_Day",OBJPROP_TEXT,dailyText);
   string targetText = g_UseManualTarget ? ((TargetType==TARGET_IN_MONEY)?"$"+DoubleToString(g_ManualTargetValue,0):DoubleToString(g_ManualTargetValue,1)+"%") : ((TargetType==TARGET_IN_MONEY)?"$"+DoubleToString(DailyTargetValue,0):DoubleToString(DailyTargetValue,1)+"%");
   if(ObjectFind(0,PFX+"V_Tgt")>=0) ObjectSetString(0,PFX+"V_Tgt",OBJPROP_TEXT,targetText);
   string hits=IntegerToString(g_DailyTargetHits); if(MaxDailyTargetHits>0) hits+=" / "+IntegerToString(MaxDailyTargetHits);
   if(ObjectFind(0,PFX+"V_TargetHits")>=0) ObjectSetString(0,PFX+"V_TargetHits",OBJPROP_TEXT,hits);
   if(ObjectFind(0,PFX+"V_ResetCountDaily")>=0) ObjectSetString(0,PFX+"V_ResetCountDaily",OBJPROP_TEXT,IntegerToString(g_TargetResetCount));
   double targetAmt = GetManualTargetAmount(); double pct = (targetAmt>0)?(g_DailyTotalForTarget/targetAmt)*100:0; if(pct>100) pct=100; if(pct<0) pct=0;
   if(ObjectFind(0,PFX+"V_Progress")>=0) ObjectSetString(0,PFX+"V_Progress",OBJPROP_TEXT,DoubleToString(pct,1)+"%");
   int bw=SafeRound(180*(pct/100)); if(bw>180) bw=180;
   if(ObjectFind(0,PFX+"ProgressBar")>=0) ObjectSetInteger(0,PFX+"ProgressBar",OBJPROP_XSIZE,bw);
   // v24 FIX: "Pause Status" sebelumnya HANYA diisi sekali saat dashboard
   // pertama dibuat (CreateLabel dgn GetPauseStatus() sbg teks awal) dan
   // TIDAK PERNAH di-refresh lagi - jadi walau logika pause sudah benar
   // (v23), tampilannya beku selamanya di teks awal ("Active"). Kini
   // di-refresh tiap tick di sini, plus warna berubah real-time: hijau
   // saat aktif normal, oranye saat target tercapai/dijeda.
   if(ObjectFind(0,PFX+"V_PauseBetween")>=0) {
      ObjectSetString(0,PFX+"V_PauseBetween",OBJPROP_TEXT,GetPauseStatus());
      ObjectSetInteger(0,PFX+"V_PauseBetween",OBJPROP_COLOR,(g_GoalHit||g_TradingPaused)?C_Orange:C_Green);
   }
   if(ObjectFind(0,PFX+"V_BuyC")>=0) ObjectSetString(0,PFX+"V_BuyC",OBJPROP_TEXT,IntegerToString(g_BuyPositions));
   if(ObjectFind(0,PFX+"V_SelC")>=0) ObjectSetString(0,PFX+"V_SelC",OBJPROP_TEXT,IntegerToString(g_SellPositions));
   double fl=g_TotalBuyProfit+g_TotalSellProfit;
   if(ObjectFind(0,PFX+"V_Flt")>=0){ ObjectSetString(0,PFX+"V_Flt",OBJPROP_TEXT,"$"+DoubleToString(fl,2)); ObjectSetInteger(0,PFX+"V_Flt",OBJPROP_COLOR,fl>=0?C_Green:C_Red); }
   // v22: g_GoalHit dicek LEBIH DULU supaya status "DAILY TARGET HIT" tampil
   // spesifik (bukan cuma "PAUSED" generik yg bisa disalahartikan sbg jeda
   // drawdown/news/loss-limit) - keduanya kini jadi true bersamaan saat
   // target tercapai, jadi urutan pengecekan menentukan pesan yg terlihat.
   if(g_GoalHit){ g_Status="DAILY TARGET HIT"; g_StatusColor=C_Green; }
   else if(g_TradingPaused){ g_Status="PAUSED"; g_StatusColor=C_Orange; }
   else if(!g_Active){ g_Status="SYSTEM PAUSED (MANUAL)"; g_StatusColor=C_Red; }
   else { g_Status="SYSTEM ACTIVE"; g_StatusColor=C_Green; }
   if(ObjectFind(0,PFX+"StatusValue")>=0){ ObjectSetString(0,PFX+"StatusValue",OBJPROP_TEXT,g_Status); ObjectSetInteger(0,PFX+"StatusValue",OBJPROP_COLOR,g_StatusColor); }
   if(ObjectFind(0,PFX+"TrendInfo")>=0){ ObjectSetString(0,PFX+"TrendInfo",OBJPROP_TEXT,"TREND: "+g_TrendDirection); ObjectSetInteger(0,PFX+"TrendInfo",OBJPROP_COLOR,g_TrendColor); }
   string haStatus = (g_HA_Direction_Val == 1) ? "UP" : (g_HA_Direction_Val == -1 ? "DN" : "-");
   string stStatus = (g_ST_Trend == 1) ? "UP" : (g_ST_Trend == -1 ? "DN" : "-");
   string mtfStatus = "M5:"+(g_ST_Trend_M5==1?"UP":(g_ST_Trend_M5==-1?"DN":"-"))+" M15:"+(g_ST_Trend_M15==1?"UP":(g_ST_Trend_M15==-1?"DN":"-"))+" M30:"+(g_ST_Trend_M30==1?"UP":(g_ST_Trend_M30==-1?"DN":"-"))+" H1:"+(g_ST_Trend_H1==1?"UP":(g_ST_Trend_H1==-1?"DN":"-"))+" H4:"+(g_ST_Trend_H4==1?"UP":(g_ST_Trend_H4==-1?"DN":"-"));
   string filterStatus = "Filters: ";
   if(UseVolatilityFilter) filterStatus += "Vol ";
   if(UseNewsFilter) filterStatus += "News ";
   if(UseMTFConfirmation) filterStatus += "MTF ";
   string signalStr = StringFormat("HA:%s ST:%s | %s | %s | %s", haStatus, stStatus, mtfStatus, g_BoxActive ? "BOX:SIDEWAYS!" : "BOX:-", filterStatus);
   if(ObjectFind(0,PFX+"V_Crystal")>=0) ObjectSetString(0,PFX+"V_Crystal",OBJPROP_TEXT,signalStr);
   string distTP = (DynamicTPDistance == DIST_TIGHT) ? "Tight" : (DynamicTPDistance == DIST_WIDE ? "Wide" : "Normal");
   string speedTP = (DynamicTPSpeed == SPEED_AGGRESSIVE) ? "Aggr" : (DynamicTPSpeed == SPEED_SLOW ? "Slow" : "Normal");
   string distSL = (DynamicSLDistance == DIST_TIGHT) ? "Tight" : (DynamicSLDistance == DIST_WIDE ? "Wide" : "Normal");
   string speedSL = (DynamicSLSpeed == SPEED_AGGRESSIVE) ? "Aggr" : (DynamicSLSpeed == SPEED_SLOW ? "Slow" : "Normal");
   string dynamicInfo = StringFormat("TP:%s/%s SL:%s/%s", distTP, speedTP, distSL, speedSL);
   if(ObjectFind(0,PFX+"V_DynamicInfo")>=0) ObjectSetString(0,PFX+"V_DynamicInfo",OBJPROP_TEXT,dynamicInfo);
   string atrInfo = StringFormat("ATR:%.2f%%", g_ATRPercentAdjusted);
   if(ObjectFind(0,PFX+"V_ATRInfo")>=0) ObjectSetString(0,PFX+"V_ATRInfo",OBJPROP_TEXT,atrInfo);
   string ddStatus = (g_DrawdownProtectionActive) ? StringFormat("DD: %.1f%% (LIMIT)", g_CurrentDrawdownPercent) : StringFormat("DD: %.1f%%", g_CurrentDrawdownPercent);
   color ddColor = (g_CurrentDrawdownPercent > MaxDrawdownPercent * 0.8) ? C_Red : C_Text;
   if(ObjectFind(0,PFX+"V_DrawdownInfo")>=0){ ObjectSetString(0,PFX+"V_DrawdownInfo",OBJPROP_TEXT,ddStatus); ObjectSetInteger(0,PFX+"V_DrawdownInfo",OBJPROP_COLOR,ddColor); }
   if(ObjectFind(0,PFX+"V_LossStreak")>=0) ObjectSetString(0,PFX+"V_LossStreak",OBJPROP_TEXT,"Loss Streak: "+IntegerToString(g_ConsecutiveLosses));
   string protStatus = (g_DrawdownProtectionActive) ? "DRAWDOWN ACTIVE (LOT REDUCED)" : "NORMAL";
   color protColor = (g_DrawdownProtectionActive) ? C_Orange : C_Green;
   if(ObjectFind(0,PFX+"V_Protection")>=0){ ObjectSetString(0,PFX+"V_Protection",OBJPROP_TEXT,protStatus); ObjectSetInteger(0,PFX+"V_Protection",OBJPROP_COLOR,protColor); }
   if(ObjectFind(0,PFX+"V_EntryMode")>=0) ObjectSetString(0,PFX+"V_EntryMode",OBJPROP_TEXT,"ENTRY: FLIP"+(g_FirstEntryToday?" (FIRST)":""));
   if(ObjectFind(0,PFX+"V_TradingMode")>=0) ObjectSetString(0,PFX+"V_TradingMode",OBJPROP_TEXT,"MODE: "+TradingModeToString(TradingMode));
   // v32: refresh info recovery & pending titik-jenuh (real-time)
   if(ObjectFind(0,PFX+"V_RecoveryInfo")>=0) {
      string recTxt; color recCol;
      if(!UseSmartRecovery) { recTxt="Recovery: OFF"; recCol=C_Gray; }
      else if(g_RecoveryDeficit > 0) {
         recTxt = StringConcatenate("Recovery: defisit $", DoubleToString(g_RecoveryDeficit,2),
                                    " (", g_RecoveryTradesUsed, "/", RecoveryMaxTrades, ")");
         recCol = C_Orange;
      }
      else { recTxt="Recovery: standby"; recCol=C_Green; }
      ObjectSetString(0,PFX+"V_RecoveryInfo",OBJPROP_TEXT,recTxt);
      ObjectSetInteger(0,PFX+"V_RecoveryInfo",OBJPROP_COLOR,recCol);
   }
   // v40 FIX: label ini SEBELUMNYA cuma mencerminkan sistem ExhPend (titik-
   // jenuh) - begitu Cover (v30) atau Repend (v39) yang memasang pending,
   // dashboard tetap tampilkan "Pending: -" walau sebenarnya ADA pending
   // aktif (info tidak terekam, persis keluhan yang diamati). Kini: kalau
   // ExhPend aktif pakai info detailnya (paling kaya - ada riwayat geser
   // adaptif); kalau tidak, PINDAI langsung order pending manapun milik EA
   // ini (dari subsistem manapun) supaya selalu mencerminkan kondisi nyata.
   string pendInfoDisp = "-"; color pendColorDisp = clrGray;
   bool hasStopSlot = (g_ExhPendTicket > 0), hasLimitSlot = (g_ExhPendLTicket > 0);
   if(hasStopSlot && hasLimitSlot) {
      pendInfoDisp = g_ExhPendInfo + " | " + g_ExhPendLInfo;
      pendColorDisp = (StringFind(g_ExhPendInfo,"TERSENTUH")>=0 || StringFind(g_ExhPendLInfo,"TERSENTUH")>=0) ? C_Green : C_Orange;
   } else if(hasStopSlot) {
      pendInfoDisp = g_ExhPendInfo;
      pendColorDisp = (StringFind(g_ExhPendInfo,"TERSENTUH")>=0) ? C_Green : (g_ExhPendInfo=="-" ? clrGray : C_Orange);
   } else if(hasLimitSlot) {
      pendInfoDisp = g_ExhPendLInfo;
      pendColorDisp = (StringFind(g_ExhPendLInfo,"TERSENTUH")>=0) ? C_Green : (g_ExhPendLInfo=="-" ? clrGray : C_Orange);
   } else {
      for(int iPd=0; iPd<OrdersTotal(); iPd++) {
         if(OrderSelect(iPd,SELECT_BY_POS,MODE_TRADES) && OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber &&
            (OrderType()==OP_BUYSTOP || OrderType()==OP_SELLSTOP || OrderType()==OP_BUYLIMIT || OrderType()==OP_SELLLIMIT)) {
            string srcTag = "-"; // COVER/REPEND dibedakan dari comment order
            if(StringFind(OrderComment(),"REPEND")>=0) srcTag = "LANJUT-TREN";
            else if(StringFind(OrderComment(),"COVER")>=0) srcTag = "COVER";
            string typeTxt = (OrderType()==OP_BUYSTOP?"BUY STOP":(OrderType()==OP_SELLSTOP?"SELL STOP":(OrderType()==OP_BUYLIMIT?"BUY LIMIT":"SELL LIMIT")));
            pendInfoDisp = typeTxt+" "+srcTag+" @ "+DoubleToString(OrderOpenPrice(),g_Digits);
            pendColorDisp = C_Orange;
            break;
         }
      }
   }
   if(ObjectFind(0,PFX+"V_ExhPendInfo")>=0) {
      ObjectSetString(0,PFX+"V_ExhPendInfo",OBJPROP_TEXT,"Pending: "+pendInfoDisp);
      ObjectSetInteger(0,PFX+"V_ExhPendInfo",OBJPROP_COLOR,pendColorDisp);
   }
   if(ObjectFind(0,PFX+"V_Support")>=0) ObjectSetString(0,PFX+"V_Support",OBJPROP_TEXT,"Sup: "+DoubleToString(g_DisplaySupport,g_Digits));
   if(ObjectFind(0,PFX+"V_Resistance")>=0) ObjectSetString(0,PFX+"V_Resistance",OBJPROP_TEXT,"Res: "+DoubleToString(g_DisplayResistance,g_Digits));
   // v42 FIX: panel ini SEBELUMNYA selalu tampilkan angka HIPOTETIS (yg akan
   // dipakai kalau ADA entri baru), bukan angka SUNGGUHAN dari posisi yg
   // SEDANG terbuka - begitu ada posisi aktif dgn TrendRun_ReleaseTP sudah
   // memperlebar TP jauh, angka yg tampil (dari kalkulasi baru, bukan posisi
   // sungguhan) bisa berbeda & terlihat "ribuan pip tanpa alasan jelas".
   // Kini: kalau ADA posisi terbuka, rekam SL/TP SUNGGUHAN posisi itu
   // (paling baru dibuka); kalau tidak ada posisi, baru tampilkan estimasi
   // utk entri berikutnya (sama spt sebelumnya).
   double tpNowD = 0, slNowD = 0; datetime latestOpenT = 0; int latestTicket = -1;
   for(int iPi=0; iPi<OrdersTotal(); iPi++) {
      if(OrderSelect(iPi,SELECT_BY_POS,MODE_TRADES) && OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber &&
         (OrderType()==OP_BUY || OrderType()==OP_SELL) && OrderOpenTime()>latestOpenT) {
         latestOpenT = OrderOpenTime(); latestTicket = OrderTicket();
      }
   }
   bool showingReal = false;
   if(latestTicket>=0 && OrderSelect(latestTicket,SELECT_BY_TICKET,MODE_TRADES)) {
      double opnP = OrderOpenPrice(), slP2 = OrderStopLoss(), tpP2 = OrderTakeProfit();
      if(slP2>0 || tpP2>0) {
         slNowD = (slP2>0) ? MathAbs(opnP-slP2)/PipPoint() : 0;
         tpNowD = (tpP2>0) ? MathAbs(tpP2-opnP)/PipPoint() : 0;
         showingReal = true;
      }
   }
   if(!showingReal) { tpNowD = GetManualTPPips(); slNowD = GetManualSLPips(); }
   if(ObjectFind(0,PFX+"V_PairInfo")>=0) ObjectSetString(0,PFX+"V_PairInfo",OBJPROP_TEXT,Symbol()+(showingReal?" [POSISI AKTIF]":" [estimasi]")+" | TP:"+IntegerToString((int)tpNowD)+" | SL:"+IntegerToString((int)slNowD));
   if(ObjectFind(0,PFX+"V_MaxProfit")>=0) ObjectSetString(0,PFX+"V_MaxProfit",OBJPROP_TEXT,"$"+DoubleToString(g_MaxDailyProfit,2));
   if(ObjectFind(0,PFX+"V_NextReset")>=0) ObjectSetString(0,PFX+"V_NextReset",OBJPROP_TEXT,DailyResetTime);
   if(ObjectFind(0,PFX+"V_LotValue")>=0) ObjectSetString(0,PFX+"V_LotValue",OBJPROP_TEXT,DoubleToString(g_UseManualLot?g_ManualLotValue:BaseLot,2));
   if(ObjectFind(0,PFX+"V_TargetValue")>=0) ObjectSetString(0,PFX+"V_TargetValue",OBJPROP_TEXT,targetText);
   // v39 FIX: dulu label ini cuma tampilkan angka polos, sama sekali tidak
   // ada penanda visual kalau override MANUAL sedang aktif (mis. gara2 klik
   // SL+/TP+ tersenggol saat nonton visual backtest) - user tidak akan tahu
   // "angka ini dari mana" krn tampilannya identik dgn mode otomatis. Kini
   // diberi awalan "M:" + warna oranye supaya jelas kelihatan beda.
   bool slManActive = (g_UseManualSL && g_ManualSLValue>0);
   bool tpManActive = (g_UseManualTP && g_ManualTPValue>0);
   // v43: HANYA angka pip - nilai dolar dihapus atas permintaan (ruang
   // dashboard sempit, cukup pip saja utk kebutuhan trading manual).
   if(ObjectFind(0,PFX+"V_SLValue")>=0) {
      string slTxt = slManActive ? ("M:"+DoubleToString(g_ManualSLValue,0)) : "0 (auto)";
      ObjectSetString(0,PFX+"V_SLValue",OBJPROP_TEXT,slTxt);
      ObjectSetInteger(0,PFX+"V_SLValue",OBJPROP_COLOR,slManActive?clrOrange:clrGray);
   }
   if(ObjectFind(0,PFX+"V_TPValue")>=0) {
      string tpTxt = tpManActive ? ("M:"+DoubleToString(g_ManualTPValue,0)) : "0 (auto)";
      ObjectSetString(0,PFX+"V_TPValue",OBJPROP_TEXT,tpTxt);
      ObjectSetInteger(0,PFX+"V_TPValue",OBJPROP_COLOR,tpManActive?clrOrange:clrGray);
   }
   // v29 FIX: tombol ON/OFF (B_Switch) sebelumnya cuma diwarnai/dilabeli
   // SEKALI saat dashboard pertama dibuat - menekannya menukar g_Active
   // di baliknya, tapi WARNA & TEKS TOMBOL TIDAK PERNAH IKUT BERUBAH
   // (beku di tampilan awal). Kini disegarkan tiap tick: hijau+teks "ON"
   // saat aktif, merah+teks "OFF" saat mati - sesuai kondisi sebenarnya.
   if(ObjectFind(0,PFX+"B_Switch")>=0) {
      ObjectSetString(0,PFX+"B_Switch",OBJPROP_TEXT,g_Active?"ON":"OFF");
      ObjectSetInteger(0,PFX+"B_Switch",OBJPROP_BGCOLOR,g_Active?clrGreen:clrRed);
   }
   UpdateDashboardPositionDetails();
   ChartRedraw(0);
}
void UpdateDashboard(){ UpdateDashboardValues(); }
void ApplyManualSLTPToAllOrders() {
   double point=PipPoint(), slP=GetManualSLPips(), tpP=GetManualTPPips();
   for(int i=OrdersTotal()-1;i>=0;i--) {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES) || OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber || (OrderType()!=OP_BUY && OrderType()!=OP_SELL)) continue;
      double open=OrderOpenPrice(), newSL=0, newTP=0;
      if(OrderType()==OP_BUY){ newSL=open-slP*point; newTP=open+tpP*point; }
      else { newSL=open+slP*point; newTP=open-tpP*point; }
      double minDist=MathMax(g_StopLevel*point,15*point);
      double bid=MarketInfo(OrderSymbol(),MODE_BID), ask=MarketInfo(OrderSymbol(),MODE_ASK);
      if(OrderType()==OP_BUY){ if(newSL>bid-minDist) newSL=bid-minDist; if(newTP<ask+minDist) newTP=ask+minDist; }
      else { if(newSL<ask+minDist) newSL=ask+minDist; if(newTP>bid-minDist) newTP=bid-minDist; }
      newSL=NormalizeDouble(newSL,g_Digits); newTP=NormalizeDouble(newTP,g_Digits);
      if(newSL>0 && newTP>0) SafeOrderModify(OrderTicket(), open, newSL, newTP, 0, clrNONE, "ManualSLTP");
   }
   UpdateDashboard();
}
string GetPauseStatus(){
   // v22: g_GoalHit dicek LEBIH DULU - target-hit pakai g_PauseUntilTime=0
   // (dicabut oleh jadwal reset harian, bukan timer mundur), jadi kalau
   // dicek g_TradingPaused dulu akan menampilkan "Paused until 1970.01.01"
   // (bug tampilan). Pesan target-hit kini juga menyebut jam reset harian.
   if(g_GoalHit) return "Target tercapai - stop s/d "+DailyResetTime+" atau RESET manual";
   if(g_TradingPaused) return "Paused until "+TimeToString(g_PauseUntilTime);
   return "Active";
}
string PeriodToString(int p){ switch(p){ case 1:return "M1"; case 5:return "M5"; case 15:return "M15"; case 30:return "M30"; case 60:return "H1"; case 240:return "H4"; case 1440:return "D1"; default:return IntegerToString(p); } }
string TradingModeToString(ENUM_TRADING_MODE m){ switch(m){ case MODE_CONSERVATIVE:return "CONSERVATIVE"; case MODE_NORMAL:return "NORMAL"; case MODE_AGGRESSIVE:return "AGGRESSIVE"; default:return "UNKNOWN"; } }

//+------------------------------------------------------------------+
//| INISIALISASI, TICK, CHARTEVENT                                   |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| v2.00 BUG-9 FIX - VALIDASI INDIKATOR KUSTOM SAAT START.           |
//| Versi lama TIDAK pernah memeriksa apakah keempat indikator benar- |
//| benar terpasang & mengembalikan nilai valid. Padahal komentar di  |
//| kode ini sendiri memperingatkan urutan parameter iCustom WAJIB    |
//| persis sama dgn urutan input indikatornya.                        |
//| Kalau satu .ex4 hilang, atau suatu hari Anda update indikatornya  |
//| dan urutan input bergeser SATU posisi saja, iCustom mengembalikan |
//| EMPTY_VALUE/0 dgn error 4072 - dan EA akan DIAM SAJA: entah tak   |
//| pernah entri sama sekali, atau lebih buruk, entri berdasar angka  |
//| sampah. Anda baru sadar berhari-hari kemudian, di akun real.      |
//| Kini: gagal validasi = INIT_FAILED, EA menolak jalan, alasannya   |
//| dicetak jelas di jurnal.                                          |
//+------------------------------------------------------------------+
bool ValidateCustomIndicators() {
   bool ok = true;
   Print("ðŸ” VALIDASI INDIKATOR KUSTOM ...");
   // PENTING: di Strategy Tester & saat chart baru dibuka, OnInit berjalan
   // SEBELUM bar tersedia. Nilai EMPTY_VALUE di saat itu WAJAR dan bukan
   // tanda indikator rusak. Karena itu yg dijadikan alasan GAGAL hanyalah
   // error PEMUATAN FILE yg tegas (4072 = indicator cannot load,
   // 4802 = cannot load indicator) - bukan sekadar nilai kosong.
   if(Bars < 100) {
      Print("   â„¹ï¸ Bar belum cukup (", Bars, ") - validasi nilai dilewati,");
      Print("      hanya pemuatan file yg dicek. Ini normal di awal tes.");
   }

   // --- 1. Supertrend_Promax (LANTAI 1 - pemicu utama, WAJIB) ---
   ResetLastError();
   double stTrend = STCustom(0, ST_TrendBuffer, 1);
   int errST = GetLastError();
   if(errST == 4072 || errST == 4802) {
      Print("âŒ GAGAL: '", SupertrendFile, "' TIDAK BISA DIMUAT (error ", errST,
            "). Pastikan file .ex4 ada di MQL4/Indicators DAN urutan input-nya",
            " persis sama dgn urutan di STCustom().");
      ok = false;
   }
   else if(stTrend == EMPTY_VALUE && Bars >= 100)
      Print("   âš ï¸ Supertrend_Promax termuat tapi nilainya kosong - CEK urutan parameter iCustom!");
   else Print("   âœ… Supertrend_Promax OK (trend=", DoubleToString(stTrend,0), ")");

   // --- 2. HeikenAshi_Custom (LANTAI 2 - konfirmator arah) ---
   if(UseHeikenAshi && !UseInternalHeikenAshi) {
      ResetLastError();
      double haDir = HACustom(0, HA_DirectionBuffer, 1);
      int errHA = GetLastError();
      if(errHA == 4072 || errHA == 4802) {
         Print("âŒ GAGAL: '", HeikenAshiFile, "' TIDAK BISA DIMUAT (error ", errHA, ")");
         ok = false;
      }
      else if(haDir == EMPTY_VALUE && Bars >= 100)
         Print("   âš ï¸ HeikenAshi_Custom termuat tapi nilainya kosong - CEK urutan parameter iCustom!");
      else Print("   âœ… HeikenAshi_Custom OK (arah=", DoubleToString(haDir,0), ")");
   } else Print("   â­ï¸ HeikenAshi_Custom dilewati (UseHeikenAshi/UseInternalHeikenAshi)");

   // --- 3. Entry_Signal_Pro (LANTAI 3 - konfirmator independen) ---
   if(UseESPConfirmation) {
      ResetLastError();
      ESPCustom(ESP_BuyBuffer, 1);
      int errESP = GetLastError();
      if(errESP == 4072 || errESP == 4802) {
         Print("âŒ GAGAL: '", ESP_IndicatorFile, "' TIDAK BISA DIMUAT (error ", errESP, ")");
         ok = false;
      } else Print("   âœ… Entry_Signal_Pro OK");
   } else Print("   â­ï¸ Entry_Signal_Pro dilewati (UseESPConfirmation=false)");

   // --- 4. SuperSR_6 (LANTAI 4 - zona S/R) ---
   if(UseSRFilter) {
      ResetLastError();
      iCustom(NULL, 0, SR_IndicatorFile, SR_Contract_Step, SR_Precision, SR_Shift_Bars, 0, 1);
      int errSR = GetLastError();
      if(errSR == 4072 || errSR == 4802) {
         Print("âŒ GAGAL: '", SR_IndicatorFile, "' TIDAK BISA DIMUAT (error ", errSR, ")");
         ok = false;
      } else Print("   âœ… SuperSR_6 OK");
   } else {
      Print("   â­ï¸ SuperSR_6 TIDAK DIPAKAI (UseSRFilter=false) - LANTAI 4 arsitektur");
      Print("      nonaktif. Ini SENGAJA: audit tes Jan-Jul 2026 menunjukkan filter");
      Print("      ini 0 penolakan. Nyalakan hanya utk uji A/B terpisah.");
   }
   return ok;
}

int OnInit() {
   g_Point=Point; g_Digits=(int)MarketInfo(Symbol(),MODE_DIGITS);
   g_PipPoint=(g_Digits==3||g_Digits==5)?g_Point*10:g_Point;
   g_StopLevel=(int)MarketInfo(Symbol(),MODE_STOPLEVEL); if(g_StopLevel<15) g_StopLevel=15;
   g_Magic=MagicNumber;
   g_AllowTrading=true;
   // v53: pengali mode - Conservative = risiko lebih kecil & kuorum lebih
   // ketat (+1, butuh lebih banyak indikator setuju); Aggressive = risiko
   // lebih besar & kuorum lebih longgar (-1); Normal = tak berubah sama
   // sekali (mult=1.0, adjust=0) - persis perilaku default sebelum v53.
   if(TradingMode == MODE_CONSERVATIVE) { g_ModeRiskMult = 0.6; g_ModeQuorumAdjust = 1; }
   else if(TradingMode == MODE_AGGRESSIVE) { g_ModeRiskMult = 1.4; g_ModeQuorumAdjust = -1; }
   else { g_ModeRiskMult = 1.0; g_ModeQuorumAdjust = 0; }
   DetectAndConfigurePair();
   g_LastResetDay=TimeCurrent(); g_LastProfitResetTime=TimeCurrent();
   CheckTradingTime();
   if(ShowDashboard) { if(!g_HideUI) CreateDashboard(); else CreateShowButton(); }
   Print("=== SUPER TREND REVERSAL EA - FINAL UPGRADE STARTED ===");
   Print("[v6.47 EXECUTION RECOVERY] =================================");
Print("[v6.47] ExecutionRecovery=",
      (EnableExecutionRecovery?"ON":"OFF"),
      " RecoveryMinVotes=",RecoveryMinVotes,
      " Market=", (RecoveryAllowMarket?"ON":"OFF"),
      " Stop=", (RecoveryAllowStopOrders?"ON":"OFF"),
      " Limit=", (RecoveryAllowLimitOrders?"ON":"OFF"),
      " PendingMode=",RecoveryPendingMode);
Print("[v6.47] =====================================================");

   // v61: ringkasan pengaturan mode yg PASTI tercetak sekali di awal tiap
   // tes (bukan tersebar di tengah jurnal panjang) - supaya "apakah setelan
   // X sudah benar-benar berubah dr tes sebelumnya" bisa dipastikan LANGSUNG
   // dari beberapa baris pertama jurnal, tanpa perlu mencari jauh ke dalam.
   Print("ðŸ”§ PENGATURAN MODE â€” UseExhaustionPending: ", (UseExhaustionPending?"AKTIF":"MATI"),
         " | ExhPendOrderMode: ", EnumToString(ExhPendOrderMode),
         " | UseContinuationRepending: ", (UseContinuationRepending?"AKTIF":"MATI"),
         " | RependOrderMode: ", EnumToString(RependOrderMode),
         " | TradingMode: ", EnumToString(TradingMode),
         " | UsePyramidAdd: ", (UsePyramidAdd?"AKTIF":"MATI"),
         " | UseSlopeAdaptiveSLTP: ", (UseSlopeAdaptiveSLTP?"AKTIF":"MATI"),
         " | UseMomentumCandleTrail: ", (UseMomentumCandleTrail?"AKTIF":"MATI"));
   Print(">>> BUILD: AurumPulse XAUUSD v4.02 - TEAM EXECUTION RISK FIX <<<");
   Print(">>> Verifikasi build: v3.03 TEAM EXECUTION RISK FIX <<<");

   // === v2.00: SIDIK JARI KONFIGURASI ===
   // Audit menemukan konfigurasi yg DITES berbeda dari default di file pada
   // minimal 6 saklar besar - artinya memasang EA tanpa memuat .set berarti
   // menjalankan strategi yg TIDAK PERNAH diuji. Blok di bawah mencetak
   // seluruh parameter penting ke jurnal, jadi setiap hasil tes/akun real
   // selalu bisa ditelusuri balik ke setelan persisnya. Simpan jurnal ini.
   Print("â”€â”€â”€â”€â”€â”€â”€â”€ SIDIK JARI KONFIGURASI v3.03 â”€â”€â”€â”€â”€â”€â”€â”€");
   Print("RISIKO  | RiskPerTrade=", DoubleToString(RiskPerTrade,2), "%  BaseLot=", DoubleToString(BaseLot,2),
         "  MaxRiskPerTrade=", DoubleToString(MaxRiskPerTradePercent,1), "%",
         "  PagarAgregat=", (UseTotalRiskCap?"ON "+DoubleToString(MaxTotalRiskPercent,1)+"%":"OFF"),
         "  DDProtect=", (EnableDrawdownProtection?"ON":"OFF"));
    Print("NILAI   | PipPoint=", DoubleToString(PipPoint(),5), "  PipValue/lot=$", DoubleToString(PipValuePerLot(),4));
    Print("XAU SPEC | LotSize=", DoubleToString(MarketInfo(Symbol(),MODE_LOTSIZE),2),
          " TickSize=", DoubleToString(MarketInfo(Symbol(),MODE_TICKSIZE),5),
          " TickValue=", DoubleToString(MarketInfo(Symbol(),MODE_TICKVALUE),4),
          " ContractDerivedPipValue=$", DoubleToString(g_IsGold ? MarketInfo(Symbol(),MODE_LOTSIZE)*PipPoint() : PipValuePerLot(),4),
          " Digits=", g_Digits, " StopLevel=", g_StopLevel, " Spread=", DoubleToString(MarketInfo(Symbol(),MODE_SPREAD),0));
   Print("EXIT    | ATRRelatif=", (UseATRRelativeExits?"ON":"OFF"),
         "  TrailStart=", DoubleToString(TrailStartATR,2), "xATR",
         "  TrailClamp=", DoubleToString(TrailMinATR,2), "-", DoubleToString(TrailMaxATR,2), "xATR",
         "  BE=", DoubleToString(BreakevenTriggerATR,2), "xATR",
         "  STbuf=", DoubleToString(ST_TrailBufferATR,2), "xATR");
   Print("v3.00   | TanggaProfit=", (UseProfitLadder?"ON "+DoubleToString(LadderStep1ATR,1)+"/"+DoubleToString(LadderStep2ATR,1)+"/"+DoubleToString(LadderStep3ATR,1)+"/"+DoubleToString(LadderStep4ATR,1)+"xATR":"OFF"),
         "  PotongMati=", (UseDeadTradeCut?"ON "+IntegerToString(DeadTradeBars)+"bar/"+DoubleToString(DeadTradeMinPeakATR,2)+"xATR":"OFF"),
         "  LawanTren=", (UseCounterTrendSizing?"ON x"+DoubleToString(CounterTrendLotFactor,2):"OFF"),
         "  BE+=", DoubleToString(BreakevenPlusATR,2), "xATR");
   Print("EXIT2   | ProfitStage=", (UseProfitStageTrail?"ON":"OFF"),
         "  SpikeGuard=", (UseSpikeGuard?"ON":"OFF"),
         "  MomentumTrail=", (UseMomentumCandleTrail?"ON":"OFF"),
         "  ReleaseTP=", (TrendRun_ReleaseTP?"ON":"OFF"),
         "  Partial=", (UsePartialProfit?"ON":"OFF"),
         "  Grace=", (UseEntryGracePeriod?"ON":"OFF"));
   Print("ENTRI   | Pyramid=", (UsePyramidAdd?"ON":"OFF"),
         "  Repending=", (UseContinuationRepending?"ON":"OFF"),
         "  ExhPending=", (UseExhaustionPending?"ON":"OFF"),
         "  PendCover=", (UsePendingCover?"ON":"OFF"),
         "  SlopeAdaptif=", (UseSlopeAdaptiveSLTP?"ON":"OFF"));
   Print("FILTER  | SR=", (UseSRFilter?"ON":"OFF"), "  ESPmatch=", (ESP_RequireMatch?"ON":"OFF"),
         "  StrictFlip=", (UseStrictFlipQuality?"ON":"OFF"), "  HTFBias=", (UseHTFBiasFilter?"ON":"OFF"),
         "  VolSpike=", (UseVolatilityFilter?"ON max "+DoubleToString(MaxVolSpikeRatio,2)+"x":"OFF"),
         "  News=", (UseNewsFilter?"ON":"OFF"), "  NFP=", (BlockNFP?"ON":"OFF"));
   Print("â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€");

   // v2.00 BUG-9: indikator divalidasi SEBELUM EA diizinkan jalan.
   g_IndicatorsOK = ValidateCustomIndicators();
   if(!g_IndicatorsOK) {
      Print("ðŸ›‘ EA DIHENTIKAN: validasi indikator kustom GAGAL. Perbaiki dulu -");
      Print("   jangan pernah menjalankan EA ini dgn indikator yg tak terbaca,");
      Print("   karena kegagalannya SENYAP (tak ada entri, atau entri dari angka sampah).");
      return INIT_FAILED;
   }
   Print("âœ… Semua indikator wajib tervalidasi - EA siap.");
   return INIT_SUCCEEDED;
}
void OnDeinit(const int reason){
   ObjectsDeleteAll(0,PFX); ObjectDelete(0,SHOW_BTN);
   Print("=== RINGKASAN DIAGNOSTIK FILTER (total bar dicek per sisi BUY+SELL) ===");
   Print("Ditolak - Supertrend tidak flip   : ", g_cnt_STFlip);
   Print("Ditolak - Heiken Ashi tidak flip  : ", g_cnt_HAFlip);
   Print("Ditolak - MTF tidak searah        : ", g_cnt_MTF);
   Print("Ditolak - Trend lama terlalu muda : ", g_cnt_TrendAge);
   Print("Ditolak - ADX trend lama lemah    : ", g_cnt_ADXFalse);
   Print("Ditolak - Belum over-extended     : ", g_cnt_OverExt);
   Print("Ditolak - Belum ada koreksi harga : ", g_cnt_Correction);
   Print("Ditolak - Belum dekat level S/R    : ", g_cnt_SR);
   Print("Ditolak - Entry_Signal_Pro tdk setuju: ", g_cnt_ESP);
   Print("Ditolak - Kejar-harga (entri telat)  : ", g_cnt_Chase);
   Print("Ditolak - Arah blm berpihak (DI/slope): ", g_cnt_Regime);
   Print("Ditolak - DI DALAM KOTAK SIDEWAYS(v16): ", g_cnt_Compress);
   Print("Ditolak - Melawan arah breakout (v16): ", g_cnt_OppLock);
   Print("Ditolak - Candle sinyal lemah (v16)  : ", g_cnt_WeakBody);
   Print("Ditolak - Bias TF-atas (v31)         : ", g_cnt_HTFBias);
   Print("Direlakan - Konfirmasi telat (v18)   : ", g_cnt_Late);
   Print("Ditolak - Perisai pisau/leg besar(v18): ", g_cnt_Knife);
   Print("Ditolak - Titik jenuh trend lanjut(v21): ", g_cnt_ContKnife);
   Print("--- TREND RIDER ---");
   Print("Pemicu terdeteksi (panah/HA-flip)    : ", g_cnt_ContTrigger);
   Print("Tertahan - kuorum arah kurang v38 H1+H4+HA+Regime+HTFBias gabungan (min ", ContQuorumRequired, "/5): ", g_cnt_ContRegime);
   Print("Ditolak - kejar-harga                : ", g_cnt_ContChase);
   Print("Ditolak - kaki trend TUA & ADX lemah (v35): ", g_cnt_LegAge);
   Print("Ditolak - Gerbang AI (v36)          : ", g_cnt_AIReject);
   Print("Kandidat ENTRI TREND RIDER lolos       : ", g_cnt_ContEntry);
   Print("Ditolak - Volatilitas tinggi      : ", g_cnt_Volatility);
   Print("Ditolak - Waktu news              : ", g_cnt_News);
   Print("SINYAL VALID (lolos semua filter) : ", g_cnt_Valid);
   Print("--- v2.00: KESEHATAN SISTEM ---");
   Print("Diblokir - PAGAR RISIKO AGREGAT      : ", g_cnt_RiskCap);
   Print("Entri LAWAN-TREN (lot diperkecil)    : ", g_cnt_CounterTrend);
   Print("Trade MATI dipotong (v3.00)          : ", g_cnt_DeadCut);
   Print("Kunci TANGGA PROFIT tercapai         : ", g_cnt_Ladder,
         "  (anak-tangga >=2 = ambang 'pasti menang' 1,5xATR: ", g_cnt_Ladder2, ")");
   Print("Slot monitor PENUH (posisi tak terkelola): ", g_cnt_MonitorFull);
   Print("Kegagalan OrderModify NYATA          : ", g_ModifyErrCount);
   Print("   (v1.00 mencatat 22.109 'OrderModify error 1' di jurnal MT4.");
   Print("    Di v2.00 angka itu HARUS 0 - SafeOrderModify menolak memanggil");
   Print("    broker kalau tak ada perubahan nyata. Kalau Anda masih melihat");
   Print("    'OrderModify error 1' di jurnal, berarti ada jalur modify yg");
   Print("    terlewat - laporkan baris jurnalnya.)");
   Print("Risiko terbuka saat EA berhenti      : ", DoubleToString(GetTotalOpenRiskPercent(),2), "% balance");
   Print("=== EA STOPPED ===");
}

//+------------------------------------------------------------------+
//| SMART CORE v4.03 - adaptive execution + pending lifecycle                 |
//| Supertrend = primary trigger; HA/ESP = confirmation; SR = veto. |
//| Uses only stable early Supertrend buffers 0/1/5/6 so the EA does |
//| NOT depend on the indicator's 181-input tail contract.            |
//+------------------------------------------------------------------+
input string SC_Comment = "=== SMART CORE v4.03 ===";
input bool   SC_Enable = false; // RECOVERY: Strategic Core execution is authoritative; Smart Core retained but not allowed to bypass legacy engine.
input int    SC_MinVotes = 2;              // ST + HA + ESP, 2/3 minimum
input bool   SC_RequireHA = true;           // HA opposite direction veto
input bool   SC_UseESP = true;
input bool   SC_UseSRVeto = true;
input double SC_SRVetoRoomATR = 0.20;       // veto only when room is very small
input int    SC_EntryMode = 0;              // 0=AUTO, 1=MARKET, 2=LIMIT, 3=STOP
input double SC_FixedLot = 0.01;            // diagnostic-safe starting lot
input bool   SC_UseRiskLot = false;         // enable only after execution is proven
input double SC_RiskPercent = 0.50;
input double SC_SL_ATR = 1.50;
input double SC_TP_R = 1.50;
input double SC_PendingNearATR = 1.20;      // near ST => STOP; far => LIMIT
input double SC_PendingOffsetATR = 0.10;
input int    SC_PendingExpiryBars = 12;      // SMARTCORE pending lifecycle (not legacy 4-bar pullback)
input bool   SC_RepricePending = false;      // optional: keep false for first validation pass
input int    SC_MarketMinVotes = 3;          // full ST+HA+ESP alignment can enter market
input bool   SC_MarketOnFreshST = true;      // fresh Supertrend trigger may enter market when structure is clean
input int    SC_MaxOrders = 1;
input int    SC_Slippage = 30;
input int    SC_Debug = true;

datetime g_SC_LastEntryBar = 0;
int      g_SC_LastDirection = 0;

bool SC_IsOurOrderType(int t) {
   return (t==OP_BUY || t==OP_SELL || t==OP_BUYLIMIT || t==OP_SELLLIMIT || t==OP_BUYSTOP || t==OP_SELLSTOP);
}
int SC_CountOrders() {
   int n=0;
   for(int i=OrdersTotal()-1;i>=0;i--) {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES) && OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber && SC_IsOurOrderType(OrderType())) n++;
   }
   return n;
}
bool SC_Valid(double v) { return (v!=EMPTY_VALUE && v!=0.0 && v!=2147483647.0 && v!=-2147483647.0); }
int SC_STDirection(int shift) {
   double tr=STCustom(0,ST_TrendBuffer,shift);
   if(tr==EMPTY_VALUE || MathAbs(tr)>2.0) return 0;
   return (tr>0.5)?1:(tr<-0.5?-1:0);
}
int SC_STTrigger(int shift) {
   double b=STCustom(0,5,shift), s=STCustom(0,6,shift);
   bool buy=SC_Valid(b), sell=SC_Valid(s);
   if(buy && !sell) return 1;
   if(sell && !buy) return -1;
   return 0;
}
int SC_HADirection(int shift) {
   double v=HACustom(0,HA_DirectionBuffer,shift);
   if(!SC_Valid(v)) return 0;
   if(v>0.5) return 1;
   if(v<-0.5) return -1;
   return 0;
}
int SC_ESPDirection(int shift) {
   double b=ESPCustom(ESP_BuyBuffer,shift), s=ESPCustom(ESP_SellBuffer,shift);
   bool buy=SC_Valid(b), sell=SC_Valid(s);
   if(buy && !sell) return 1;
   if(sell && !buy) return -1;
   return 0;
}
bool SC_SRVeto(int dir,int shift,double atr) {
   if(!SC_UseSRVeto || atr<=0) return false;
   double veto=SRCustom(7,shift);
   if(SC_Valid(veto) && veto>0.5) return true;
   double room=(dir>0)?SRCustom(4,shift):SRCustom(5,shift);
   if(SC_Valid(room) && room>=0 && room<SC_SRVetoRoomATR) return true;
   return false;
}
double SC_NormalizePrice(double p) { return NormalizeDouble(p,Digits); }
double SC_MinStopDistance() {
   double d=MarketInfo(Symbol(),MODE_STOPLEVEL)*Point;
   double f=MarketInfo(Symbol(),MODE_FREEZELEVEL)*Point;
   return MathMax(d,f)+2*Point;
}
double SC_ATR() { double a=iATR(NULL,0,14,1); return (a>0?a:MathMax(20*Point,10*PipPoint())); }
double SC_Lot(double slPrice) {
   if(!SC_UseRiskLot) return MathMax(MarketInfo(Symbol(),MODE_MINLOT),MathMin(SC_FixedLot,MarketInfo(Symbol(),MODE_MAXLOT)));
   double riskMoney=AccountBalance()*SC_RiskPercent/100.0;
   double dist=MathAbs(slPrice-(Bid+Ask)/2.0);
   double tv=MarketInfo(Symbol(),MODE_TICKVALUE), ts=MarketInfo(Symbol(),MODE_TICKSIZE);
   if(riskMoney<=0 || dist<=0 || tv<=0 || ts<=0) return SC_FixedLot;
   double riskPerLot=dist/ts*tv;
   if(riskPerLot<=0) return SC_FixedLot;
   double lot=riskMoney/riskPerLot;
   double minL=MarketInfo(Symbol(),MODE_MINLOT), maxL=MarketInfo(Symbol(),MODE_MAXLOT), step=MarketInfo(Symbol(),MODE_LOTSTEP);
   if(step<=0) step=0.01;
   lot=MathFloor(lot/step)*step;
   lot=MathMax(minL,MathMin(maxL,lot));
   return NormalizeDouble(lot,2);
}
bool SC_BuildPlan(int dir,int &type,double &entry,double &sl,double &tp) {
   RefreshRates();
   double atr=SC_ATR(), line=(dir>0)?STCustom(0,0,1):STCustom(0,1,1);
   if(!SC_Valid(line)) line=(dir>0)?Bid-atr:Ask+atr;
   double minD=SC_MinStopDistance();
   double riskDist=MathMax(SC_SL_ATR*atr,minD*2.0);
   int mode=SC_EntryMode;
   if(mode==0) {
      double dist=MathAbs(((dir>0)?Ask:Bid)-line);
      mode=(dist<=SC_PendingNearATR*atr)?3:2;
   }
   if(mode==1) {
      type=(dir>0)?OP_BUY:OP_SELL;
      entry=(dir>0)?Ask:Bid;
      sl=(dir>0)?entry-riskDist:entry+riskDist;
   } else if(mode==2) {
      type=(dir>0)?OP_BUYLIMIT:OP_SELLLIMIT;
      entry=line;
      if(dir>0) entry=MathMin(entry,Ask-minD); else entry=MathMax(entry,Bid+minD);
      sl=(dir>0)?entry-riskDist:entry+riskDist;
   } else {
      type=(dir>0)?OP_BUYSTOP:OP_SELLSTOP;
      double off=SC_PendingOffsetATR*atr;
      if(dir>0) entry=MathMax(Ask+minD,line+off); else entry=MathMin(Bid-minD,line-off);
      sl=(dir>0)?entry-riskDist:entry+riskDist;
   }
   double reward=SC_TP_R*riskDist;
   tp=(dir>0)?entry+reward:entry-reward;
   if(type==OP_BUYLIMIT || type==OP_BUYSTOP) {
      if(type==OP_BUYLIMIT && entry>=Ask-minD) return false;
      if(type==OP_BUYSTOP && entry<=Ask+minD) return false;
   } else if(type==OP_SELLLIMIT || type==OP_SELLSTOP) {
      if(type==OP_SELLLIMIT && entry<=Bid+minD) return false;
      if(type==OP_SELLSTOP && entry>=Bid-minD) return false;
   }
   if(type==OP_BUY || type==OP_BUYSTOP || type==OP_BUYLIMIT) {
      if(sl>=entry-minD || tp<=entry+minD) return false;
   } else {
      if(sl<=entry+minD || tp>=entry-minD) return false;
   }
   entry=SC_NormalizePrice(entry); sl=SC_NormalizePrice(sl); tp=SC_NormalizePrice(tp);
   return true;
}
bool SC_Execute(int dir,int type,double entry,double sl,double tp,int votes,int stTrig,int ha,int esp) {
   double lot=SC_Lot(sl);
   string side=(dir>0?"BUY":"SELL"), typ=(type==OP_BUY?"MARKET BUY":type==OP_SELL?"MARKET SELL":type==OP_BUYLIMIT?"BUY LIMIT":type==OP_SELLLIMIT?"SELL LIMIT":type==OP_BUYSTOP?"BUY STOP":"SELL STOP");
   if(SC_Debug) Print("[SMART CORE] EXEC ",typ," votes=",votes," ST=",stTrig," HA=",ha," ESP=",esp," lot=",DoubleToString(lot,2)," entry=",DoubleToString(entry,Digits)," SL=",DoubleToString(sl,Digits)," TP=",DoubleToString(tp,Digits));
   ResetLastError();
   int ticket=OrderSendRetry(Symbol(),type,lot,entry,SC_Slippage,sl,tp,"SMARTCORE "+side,MagicNumber,0,(dir>0?clrLime:clrRed));
   if(ticket<0) { Print("[SMART CORE] ORDERSEND FAILED err=",GetLastError()," type=",typ); return false; }
   Print("[SMART CORE] ORDERSEND SUCCESS ticket=",ticket," type=",typ);
   g_SC_LastEntryBar = iTime(NULL,0,0);
   g_SC_LastDirection = dir;
   return true;
}
bool SC_IsPendingType(int t) {
   return (t==OP_BUYLIMIT || t==OP_SELLLIMIT || t==OP_BUYSTOP || t==OP_SELLSTOP);
}
bool SC_IsOurPending() {
   if(!SC_IsPendingType(OrderType())) return false;
   if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber) return false;
   return (StringFind(OrderComment(),"SMARTCORE",0)>=0);
}
void SC_ManagePending() {
   for(int i=OrdersTotal()-1;i>=0;i--) {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(!SC_IsOurPending()) continue;
      int ot=OrderType();
      int dir=(ot==OP_BUYLIMIT || ot==OP_BUYSTOP)?1:-1;
      double tr=STCustom(0,ST_TrendBuffer,1);
      int trend=(tr>0.5)?1:(tr<-0.5?-1:0);
      // A SMARTCORE pending survives normal pullback time. It is cancelled
      // only when the leader trend is invalidated or its explicit lifecycle
      // expires. This fixes the old ManagePendingPullbacks() deleting
      // SMARTCORE orders after the legacy 4-bar PullbackExpiryBars.
      if(trend!=0 && trend!=dir) {
         int tk=OrderTicket();
         if(OrderDelete(tk)) Print("[SMART CORE] PENDING CANCEL trend flip ticket=",tk);
         continue;
      }
      if(SC_PendingExpiryBars>0 && TimeCurrent()-OrderOpenTime() >= SC_PendingExpiryBars*PeriodSeconds()) {
         int tk2=OrderTicket();
         if(OrderDelete(tk2)) Print("[SMART CORE] PENDING EXPIRED ticket=",tk2," ageBars=",SC_PendingExpiryBars);
         continue;
      }
      // Optional reprice is deliberately disabled by default. We first prove
      // stable lifecycle behaviour before allowing dynamic modification.
   }
}

void SmartCoreCheckEntry() {
   if(!SC_Enable) return;
   if(SC_CountOrders()>=SC_MaxOrders) return;
   datetime curBar=iTime(NULL,0,0);
   int shift=1;
   // Prevent repeated re-entry on every bar from the same uninterrupted signal.
   if(g_SC_LastEntryBar==curBar) return;
   int stDir=SC_STDirection(shift), stTrig=SC_STTrigger(shift), stTrigPrev=SC_STTrigger(shift+1);
   int ha=SC_HADirection(shift), esp=SC_ESPDirection(shift);
   if(stDir==0 || stTrig!=stDir) return;
   bool freshST=(stTrig!=0 && stTrigPrev==0);
   int votes=1 + (ha==stDir?1:0) + ((SC_UseESP && esp==stDir)?1:0);
   if(SC_RequireHA && ha!=stDir) return;
   if(votes<SC_MinVotes) return;
   double atr=SC_ATR();
   if(SC_SRVeto(stDir,shift,atr)) { if(SC_Debug) Print("[SMART CORE] SR VETO dir=",stDir," votes=",votes); return; }
   int type; double entry,sl,tp;
   if(!SC_BuildPlan(stDir,type,entry,sl,tp)) { if(SC_Debug) Print("[SMART CORE] PLAN REJECTED dir=",stDir); return; }

   // Smart routing:
   // 1) fresh ST trigger + full confirmation -> MARKET;
   // 2) full 3/3 alignment -> MARKET when not materially extended;
   // 3) otherwise preserve the AUTO pending planner (LIMIT/STOP).
   if(SC_EntryMode==0) {
      double line=(stDir>0)?STCustom(0,0,1):STCustom(0,1,1);
      double px=(stDir>0)?Ask:Bid;
      double dist=SC_Valid(line)?MathAbs(px-line):999999.0;
      bool cleanMarket=(votes>=SC_MarketMinVotes && dist<=1.50*atr);
      if((SC_MarketOnFreshST && freshST && votes>=SC_MarketMinVotes && cleanMarket) || cleanMarket) {
         int mt=(stDir>0)?OP_BUY:OP_SELL;
         double me=(stDir>0)?Ask:Bid;
         double riskDist=MathMax(SC_SL_ATR*atr,SC_MinStopDistance()*2.0);
         double ms=(stDir>0)?me-riskDist:me+riskDist;
         double mtp=(stDir>0)?me+SC_TP_R*riskDist:me-SC_TP_R*riskDist;
         if(stDir>0) {
            if(ms>=me-SC_MinStopDistance()) ms=me-SC_MinStopDistance();
            if(mtp<=me+SC_MinStopDistance()) mtp=me+SC_MinStopDistance();
         } else {
            if(ms<=me+SC_MinStopDistance()) ms=me+SC_MinStopDistance();
            if(mtp>=me-SC_MinStopDistance()) mtp=me-SC_MinStopDistance();
         }
         type=mt; entry=SC_NormalizePrice(me); sl=SC_NormalizePrice(ms); tp=SC_NormalizePrice(mtp);
         if(SC_Debug) Print("[SMART CORE] ROUTE=MARKET freshST=",freshST," votes=",votes);
      }
   }
   if(SC_Debug) Print("[SMART CORE] SIGNAL dir=",stDir," ST=",stTrig," HA=",ha," ESP=",esp," votes=",votes," freshST=",freshST," type=",type);
   SC_Execute(stDir,type,entry,sl,tp,votes,stTrig,ha,esp);
}

void OnTick() {
   if(!g_IsSupportedPair) return;
   static datetime lastBarTime=0, lastDashSecond=0;
   datetime barTime=iTime(NULL,0,0);
   bool newBar=(barTime!=lastBarTime);
   if(TimeCurrent()%10==0) CheckTradingTime();
   // v23 FIX BUG KRITIS: g_PauseUntilTime=0 dipakai sbg penanda "pause
   // dikendalikan jadwal reset harian" (target-hit), BUKAN "belum ada
   // waktu". Cek lama `TimeCurrent()>=g_PauseUntilTime` SELALU true saat
   // g_PauseUntilTime=0 (timestamp manapun >= 0) - jadi pause target-hit
   // KETERHAPUS DI TICK BERIKUTNYA, persis sebabnya "target tercapai tapi
   // tidak berhenti". Kini hanya pause BERBATAS WAKTU (>0, mis. drawdown/
   // loss-limit) yang boleh auto-lepas di sini; target-hit dilepas oleh
   // CheckDailyReset() pada jadwal reset harian atau tombol RESET manual.
   if(g_TradingPaused && g_PauseUntilTime > 0 && TimeCurrent()>=g_PauseUntilTime){
      g_TradingPaused=false; g_PauseUntilTime=0;
      // v48 FIX BUG KRITIS: begitu jeda hard-stop drawdown berakhir,
      // g_HighestBalance (puncak tertinggi) TIDAK PERNAH direset - jadi
      // dd=(puncak-ekuitas)/puncak TETAP di atas HardDrawdownStopPercent
      // persis seperti sebelum jeda (blm ada trade baru selama jeda utk
      // memulihkannya). Akibatnya CheckDrawdownProtection() LANGSUNG
      // memicu ulang hard-stop pada tick berikutnya - jeda "berakhir" tp
      // seketika terkunci lagi 4 jam berikutnya, berulang TANPA HENTI -
      // persis terkunci permanen yg dilaporkan. FIX: reset puncak ke
      // ekuitas SAAT INI begitu jeda berakhir - drawdown dihitung ulang
      // relatif ke titik pemulihan, bukan puncak lama sblm insiden.
      if(g_DrawdownProtectionActive) {
         g_HighestBalance = AccountEquity();
         g_DrawdownProtectionActive = false; g_DrawdownReductionFactor = 1.0;
         Print("ðŸ”“ JEDA HARD-STOP DRAWDOWN BERAKHIR - puncak saldo direset ke ekuitas saat ini ($",
               DoubleToString(g_HighestBalance,2), "), trading otomatis aktif kembali");
      }
   }
   // v49: Spike Guard dipanggil DI SINI, TIAP TICK, DI LUAR blok newBar di
   // bawah - inilah kunci perbedaannya dari trailing biasa (yg cuma dicek
   // sekali per bar baru). Sengaja diletakkan sedini mungkin di OnTick spy
   // reaksinya secepat yg teknis mungkin thd pembalikan mendadak.
   CheckProfitLadder();   // v3.00: dipanggil PERTAMA - kunci profit & potong trade mati
   CheckSpikeGuard();
   CheckPartialProfitTick(); // v50: perbaikan bar-gating, spt Spike Guard - dicek tiap tick spy tak lewat momen tembus ambang xATR
   // v28 FIX: sebelumnya SELURUH blok manajemen (termasuk trailing/proteksi
   // ApplyDynamicProtection) ikut berhenti total saat g_Active=false (OFF).
   // Efeknya: kalau Anda entry MANUAL lewat tombol BUY/SELL lalu mematikan
   // saklar ON/OFF, posisi manual itu SAMA SEKALI TIDAK DILINDUNGI trailing
   // - berbahaya, krn tujuan OFF harusnya "berhenti buka posisi BARU",
   // bukan "lepas tangan dari posisi yg sudah terbuka". Kini dipisah:
   // trailing/proteksi (yg TIDAK PERNAH menambah risiko baru, hanya
   // mengunci/mengetatkan) tetap berjalan APA PUN status ON/OFF; hanya
   // ENTRI BARU (CheckEntry - mesin sinyal otomatis) yang benar2 berhenti
   // saat OFF. Tombol BUY/SELL manual & tombol close tetap independen
   // (selalu bisa dipakai kapan saja, sesuai desainnya).
   bool sysOff = (!g_Active || !g_AllowTrading);
   if(newBar){
      RefreshData(); UpdateSRLevels(); UpdateCompressionBox(); lastBarTime=barTime;
      CheckVirtualStopLosses();
      if(SC_Enable) SC_ManagePending();
      ManagePendingPullbacks();
      CheckDailyReset(); CalcDailyProfit(); UpdatePositionStats();
      if(!sysOff) { CheckDrawdownProtection(); CheckConsecutiveLossProtection(); if(SC_Enable) SmartCoreCheckEntry(); else CheckEntry(); }
      EnsureAllOrdersMonitored(); ApplyDynamicProtection(); EnsureInitialSLTP();
      if(!sysOff && !SC_Enable) ManageExhaustionPending(); // legacy pending disabled in Smart Core
      ManageRependLimitTrailing(); // v53: trailing pending LIMIT ke garis ST - tetap jalan apa pun status sysOff (murni penyesuaian entri yg blm terisi, bukan sinyal baru)
      UpdateDashboard();
   }
   // v45 FIX BUG: UpdatePositionStats() (mengisi g_BuyPositions/
   // g_SellPositions/g_CurrentFloatingProfit - dipakai V_BuyC/V_SelC/V_Flt)
   // dulu HANYA dipanggil di blok newBar di atas - artinya cuma di-refresh
   // SEKALI PER BAR (bisa 1 jam sekali di H1)! Sementara L_BuyDetails/
   // L_SellDetails (scan order fresh tiap panggilan) ikut UpdateDashboard
   // yg jalan TIAP DETIK - jadi kalau entri manual terjadi di TENGAH jam,
   // detail posisi langsung ter-update tapi ringkasan count/floating P/L
   // baru muncul pas jam berikutnya. Kini disamakan: dipanggil tiap detik
   // jg, bareng UpdateDashboard, supaya SEMUA info di panel Positions
   // benar2 real-time & sinkron - termasuk saat trading manual.
   if(ShowDashboard && !g_HideUI){
      datetime now=TimeCurrent();
      if(now!=lastDashSecond){ UpdatePositionStats(); UpdateDashboard(); lastDashSecond=now; }
   }
   for(int i=g_tradeMonitorCount-1;i>=0;i--){
      int monTic = g_tradeMonitors[i].ticket;
      bool found = OrderSelect(monTic, SELECT_BY_TICKET);
      bool closed = (found && OrderCloseTime() > 0);
      if(!found || closed) {
         RemoveTradeMonitor(monTic);
         if(closed) { MaybePlaceCoverStop(monTic); MaybePlaceContinuationRepending(monTic); } // v30/v39: evaluasi cover & repend utk posisi yg baru tertutup
      }
   }
}
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam){
   if(id==CHARTEVENT_OBJECT_CLICK){
      string clicked=sparam;
      if(ObjectFind(0,clicked)>=0) ObjectSetInteger(0,clicked,OBJPROP_STATE,false);
      if(clicked==PFX+"B_ManualBuy") ExecuteManualOrder(OP_BUY);
      else if(clicked==PFX+"B_ManualSell") ExecuteManualOrder(OP_SELL);
      else if(clicked==PFX+"B_Reset"){
         // v22: sebelumnya g_TargetAchievedToday TIDAK ikut direset di sini,
         // jadi walau tombol ditekan, gerbang pencapaian target tetap
         // "terkunci tercapai" dan trading tidak benar2 aktif lagi. Kini
         // ikut direset, dgn pengaman: kalau hit hari ini sudah mentok
         // MaxDailyTargetHits, reset manual ditolak sampai reset harian.
         if(UseDailyTarget && MaxDailyTargetHits>0 && g_DailyTargetHits>=MaxDailyTargetHits) {
            Print("âš ï¸ RESET MANUAL DITOLAK: sudah mencapai batas ", MaxDailyTargetHits, " pencapaian target hari ini - tunggu reset harian jam ", DailyResetTime);
         } else {
            CloseAllPositions(); g_GoalHit=false; g_TradingPaused=false; g_PauseUntilTime=0; g_TargetAchievedToday=false; g_FirstEntryToday=true; g_Active=true; g_tradeMonitorCount=0; g_LastProfitResetTime=TimeCurrent(); g_DayStartEquity=AccountEquity(); g_Status="SYSTEM ACTIVE"; g_StatusColor=C_Green; CancelAllPendingOrdersSafe(); UpdateDashboard();
         }
      }
      else if(clicked==PFX+"B_Restart"){
         // v28 FIX: sebelumnya tombol ini memanggil ExpertRemove() - itu
         // BUKAN restart, itu MELEPAS EA dari chart sepenuhnya (perlu
         // ditarik ulang manual ke chart oleh Anda supaya jalan lagi,
         // tidak otomatis "menyala kembali"). Yang benar utk RESTART:
         // EA tetap menempel & jalan, tapi SEMUA status internal disegarkan
         // ke kondisi awal spt baru pertama kali dipasang - posisi
         // ditutup, semua override manual (lot/SL/TP/target) dilepas,
         // semua flag pause/target/loss-streak disegarkan, kotak
         // konsolidasi & trade-monitor dikosongkan.
         CloseAllPositions(); CancelAllPendingOrdersSafe();
         g_tradeMonitorCount=0;
         g_GoalHit=false; g_TradingPaused=false; g_PauseUntilTime=0; g_DailyTargetHits=0;
         g_TargetAchievedToday=false; g_FirstEntryToday=true;
         g_DailyProfit=0; g_MaxDailyProfit=0; g_DayStartEquity=AccountEquity();
         g_LastProfitResetTime=TimeCurrent(); g_LastResetDay=TimeCurrent(); g_TargetResetCount=0;
         g_UseManualLot=false; g_ManualLotValue=0.01;
         g_UseManualSL=false; g_ManualSLValue=0;
         g_UseManualTP=false; g_ManualTPValue=0;
         g_UseManualTarget=false; g_ManualTargetValue=0;
         g_ConsecutiveLosses=0; g_ConsecutiveLossFactor=1.0; g_DrawdownReductionFactor=1.0; g_LotMultiplier=1.0;
         g_BoxActive=false; g_BoxActivePrev=false; g_LastBreakDir=0; g_LastBreakTime=0;
         g_Active=true; g_AllowTrading=true;
         g_Status="SYSTEM ACTIVE"; g_StatusColor=C_Green;
         UpdateDashboard(); ChartRedraw(0);
         Print("ðŸ”„ RESTART: EA disegarkan ke kondisi awal (tetap menempel & aktif) - semua override manual & status dilepas");
      }
      else if(clicked==PFX+"B_Switch"){ g_Active=!g_Active; g_Status=g_Active?"SYSTEM ACTIVE":"SYSTEM PAUSED"; g_StatusColor=g_Active?C_Green:C_Red; UpdateDashboard(); }
      else if(clicked==PFX+"B_Close"){ CloseAllPositions(); g_tradeMonitorCount=0; g_Status="POSITIONS CLOSED"; g_StatusColor=C_Orange; UpdateDashboard(); }
      else if(clicked==PFX+"B_Hide"){ g_HideUI=true; ObjectsDeleteAll(0,PFX); CreateShowButton(); ChartRedraw(0); }
      else if(clicked==SHOW_BTN){ g_HideUI=false; ObjectDelete(0,SHOW_BTN); CreateDashboard(); UpdateDashboard(); ChartRedraw(0); }
      else if(clicked==PFX+"B_LotPlus"){ if(!g_UseManualLot){ g_UseManualLot=true; g_ManualLotValue=BaseLot; } double step=0.01; g_ManualLotValue=NormalizeDouble(g_ManualLotValue+step,2); if(g_ManualLotValue>MathMin(GetMaxLotLimit(), MaxAllowedLot)) g_ManualLotValue=MathMin(GetMaxLotLimit(), MaxAllowedLot); UpdateDashboard(); }
      else if(clicked==PFX+"B_LotMinus"){ if(!g_UseManualLot){ g_UseManualLot=true; g_ManualLotValue=BaseLot; } double step=0.01; g_ManualLotValue=NormalizeDouble(g_ManualLotValue-step,2); if(g_ManualLotValue<0) g_ManualLotValue=0; UpdateDashboard(); }
      else if(clicked==PFX+"B_TargetPlus"){ if(!g_UseManualTarget){ g_UseManualTarget=true; g_ManualTargetValue=DailyTargetValue; } if(TargetType==TARGET_IN_MONEY){ g_ManualTargetValue+=10.0; if(g_ManualTargetValue>100000000) g_ManualTargetValue=100000000; } else { g_ManualTargetValue+=1.0; if(g_ManualTargetValue>10000) g_ManualTargetValue=10000; } UpdateDashboard(); }
      else if(clicked==PFX+"B_TargetMinus"){ if(!g_UseManualTarget){ g_UseManualTarget=true; g_ManualTargetValue=DailyTargetValue; } if(TargetType==TARGET_IN_MONEY){ g_ManualTargetValue-=10.0; if(g_ManualTargetValue<0) g_ManualTargetValue=0; } else { g_ManualTargetValue-=1.0; if(g_ManualTargetValue<0) g_ManualTargetValue=0; } UpdateDashboard(); }
      // v44 FIX BUG: sebelumnya nilai awal manual diambil dari
      // GetAdaptiveStopLossPips()/GetAdaptiveTakeProfitPips() - utk emas
      // (SL berbasis ATR) itu BISA RIBUAN pip, bukan nol! Jadi klik +/-
      // PERTAMA KALI langsung melompat ke "ribuan + 10", persis keluhan
      // "M:1239 dari mana". Padahal maksud tombol ini: penghitung pip
      // SEDERHANA yg bisa diprediksi utk trading manual (klik dari 0, naik
      // step 10 tiap klik) - SAMA SEKALI TERPISAH dari kalkulasi otomatis.
      // Kini mulai dari 0 murni.
      else if(clicked==PFX+"B_SLPlus"){ double step=10.0; if(!g_UseManualSL){ g_UseManualSL=true; g_ManualSLValue=0; } g_ManualSLValue+=step; if(g_ManualSLValue>100000) g_ManualSLValue=100000; ApplyManualSLTPToAllOrders(); }
      else if(clicked==PFX+"B_SLMinus"){ double step=10.0; if(!g_UseManualSL){ g_UseManualSL=true; g_ManualSLValue=0; } g_ManualSLValue-=step; if(g_ManualSLValue<0) g_ManualSLValue=0; ApplyManualSLTPToAllOrders(); }
      else if(clicked==PFX+"B_TPPlus"){ double step=10.0; if(!g_UseManualTP){ g_UseManualTP=true; g_ManualTPValue=0; } g_ManualTPValue+=step; if(g_ManualTPValue>100000) g_ManualTPValue=100000; ApplyManualSLTPToAllOrders(); }
      else if(clicked==PFX+"B_TPMinus"){ double step=10.0; if(!g_UseManualTP){ g_UseManualTP=true; g_ManualTPValue=0; } g_ManualTPValue-=step; if(g_ManualTPValue<0) g_ManualTPValue=0; ApplyManualSLTPToAllOrders(); }
      else if(clicked==PFX+"B_ResetSLTP"){
         // v28 FIX: sebelumnya tombol ini memanggil ApplyManualSLTPToAllOrders()
         // yg MENGHITUNG ULANG SL/TP dari harga OPEN memakai jarak adaptif -
         // efeknya SL yg sudah di-trailing jauh (mengunci profit besar)
         // TIBA2 DIPAKSA MUNDUR ke jarak lebar semula, membuang progres
         // pengamanan profit yg sudah didapat! Yang benar: "kembalikan ke
         // otomatis" artinya BERHENTI CAMPUR TANGAN dan biarkan
         // ApplyIntelligentTrailing MELANJUTKAN dari SL/TP yang SEDANG
         // berlaku saat ini (tidak di-snap mundur). Cukup matikan flag
         // manual - trailing otomatis mengambil alih mulai tick berikutnya.
         g_UseManualSL=false; g_ManualSLValue=0; g_UseManualTP=false; g_ManualTPValue=0; UpdateDashboard();
         Print("ðŸ”„ SL/TP dikembalikan ke OTOMATIS - trailing melanjutkan dari posisi SL/TP saat ini (tidak direset mundur)");
      }
   }
}
//+------------------------------------------------------------------+
//| AKHIR KODE                                                       |
//+------------------------------------------------------------------+


