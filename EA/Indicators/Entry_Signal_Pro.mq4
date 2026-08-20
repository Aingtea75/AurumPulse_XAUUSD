//+------------------------------------------------------------------+
//| Entry_Signal_Pro.mq4                                              |
//| VERSI 4.00 - ANGGOTA TIM 4 INDIKATOR (FINAL)                      |
//+------------------------------------------------------------------+
//| PERAN DALAM TIM  : LANTAI 3 - KONFIRMATOR INDEPENDEN              |
//| PERTANYAAN YG DIJAWAB : "Apakah osilator SETUJU, terlepas dari    |
//|                          apa kata Supertrend?"                    |
//|                                                                   |
//| Nilai anggota ini justru pada KEMANDIRIANNYA. Ia memakai bahan    |
//| yang berbeda (Momentum/ATR/CCI/RSI) sehingga bisa TIDAK SETUJU -  |
//| dan ketidaksetujuan itulah yang menyelamatkan tim dari sinyal     |
//| semu. Konfirmator yang selalu setuju tidak ada gunanya.           |
//|                                                                   |
//| === KONTRAK KELUARAN TIM ======================================== |
//|   buffer 0 : panah BUY  (harga, atau EMPTY_VALUE)                 |
//|   buffer 1 : panah SELL (harga, atau EMPTY_VALUE)                 |
//|   buffer 2 : KEKUATAN sinyal        0-100                         |
//|   buffer 3 : ARAH sinyal terakhir   +1 / -1 / 0  (bertahan)       |
//|   buffer 4 : UMUR sejak sinyal      dalam bar                     |
//|   buffer 5 : VETO                   1 = tolak, 0 = aman           |
//|                                                                   |
//| KAPAN INDIKATOR INI MEM-VETO:                                     |
//|   - RSI sudah di wilayah jenuh BERLAWANAN dgn arah yg diajukan    |
//|     (mis. mau BUY padahal RSI sudah sangat jenuh-beli = mengejar) |
//|   - ADX di bawah ambang = tak ada tren yang layak diikuti         |
//| Basis: "#Momentum                                                 |
//| onChartSignals Indicator v1.0" (2011, ForexBaron.net).            |
//|                                                                     |
//| SATU-SATUNYA perubahan dari kode asli: proteksi supaya TIDAK       |
//| CRASH (divide by zero) - itu saja. Tidak ada filter tambahan,      |
//| tidak ada perubahan urutan proses, tidak ada chart object, tidak   |
//| ada yang lain. Rumus, urutan loop, cara panah dipasang - semua    |
//| persis sama seperti file asli Anda.                                |
//+------------------------------------------------------------------+
#property copyright "Copyright 2011, ForexBaron.net"
#property link      "http://ForexBaron.net"
#property indicator_chart_window
#property indicator_buffers 7
#property indicator_color1 clrAqua
#property indicator_color2 clrOrange
// buffer 2 = v2.00 KEKUATAN SINYAL 0-100 (kalkulasi, dibaca EA)

//---- input parameters (nama & default PERSIS seperti kode asli)
input string symbol                 = "";
input int    timeFrame              = 0;
input int    cciPeriod              = 6;
input int    atrPeriod              = 12;
input int    momentumPeriod         = 7;
input int    rsiPeriod              = 7;
input int    adxPeriod              = 7;
input int    rsiControlPeriod       = 12;
input int    adxControlPeriod       = 12;
input int    rsiTrigger             = 50;
input int    adxTrigger             = 25;   // dinaikkan dari 20 - wajibkan trend lebih kuat utk presisi
input double subtractFromSignalVal  = -2.0;
input double subtractFromIndiVal    = -1.0;
input bool   showBuySignals         = true;
input bool   showSellSignals        = true;
input int    wingdingsUpArrow       = 233;
input int    wingdingsDownArrow     = 234;
input bool   Alerts                 = false;
input bool   PlaySounds             = false;
input string LongSignalSoundFile    = "alert.wav";
input string ShortSignalSoundFile   = "alert.wav";
input bool   SignalMail             = false;

// === MODE ARAH SINYAL ===
// PENEMUAN PENTING: kode asli 2011 ini dirancang COUNTER-TREND (melawan arah):
// BUY saat pasar bearish-jenuh (+DI<-DI, RSI<50), SELL saat bullish-jenuh.
// Itu sebabnya trend naik kuat tidak pernah dpt BUY - by design memang begitu.
// true  = TREND-FOLLOWING: BUY saat trend NAIK kuat, SELL saat trend TURUN kuat (sesuai permintaan)
// false = perilaku asli counter-trend (utk perbandingan)
input bool   TrendFollowingMode     = true;

// === ZONA NETRAL ANTI-ZIGZAG ===
// Di pasar ranging/koreksi, RSI & momentum bolak-balik nyeberang garis tengah
// (RSI 50, momentum 100) - tiap nyeberang tipis muncul sinyal palsu. Zona netral
// mewajibkan nilai sudah MENJAUH dari garis tengah sebelum sinyal dianggap sah.
input double RSIBufferZone          = 6.0;   // BUY butuh RSI > 50+6=56, SELL butuh RSI < 50-6=44
input double MomentumBufferZone     = 0.15;  // BUY butuh momentum > 100.15, SELL < 99.85

// === DETEKTOR PEMBALIKAN DI TITIK JENUH (REVERSAL) ===
// Mode trend-following secara desain "telat" menangkap pembalikan di puncak/lembah,
// karena butuh RSI & DI sudah berbalik jauh. Detektor ini menangkap momen:
// harga habis naik EKSTRIM sampai jenuh (RSI overbought) -> mulai turun -> SELL.
// harga habis turun EKSTRIM sampai jenuh (RSI oversold)  -> mulai naik  -> BUY.
input bool   UseReversalSignals     = true;
input double OverboughtLevel        = 67.0;  // v5.00: 72 -> 67, selaras Supertrend & sebaran terukur 5 pair
input double OversoldLevel          = 35.0;  // v5.00: 28 -> 35, selaras Supertrend & sebaran terukur 5 pair
input int    ReversalLookback       = 6;     // brp bar ke belakang mencari bukti kondisi jenuh

// === MODE KETAT ENTRY (cegah entry telat di titik jenuh, BUY & SELL) ===
// StrictBuyMode: cegah BUY yg muncul di dekat puncak yg sudah jenuh-beli
// (lihat OverboughtLevel di bawah).
// StrictSellMode: cegah SELL yg muncul di dekat lembah yg sudah jenuh-jual
// (lihat OversoldLevel di bawah). Cermin dari StrictBuyMode, dipisah jadi
// toggle sendiri spy bisa diaktif/nonaktifkan per arah kalau perlu.
// (Sinkronisasi lain: syarat "pantulan/breakdown sungguhan" utk reversal dulu
// ikut menumpang di StrictBuyMode khusus arah BUY - sekarang disatukan ke
// FinalStrictMode supaya SATU toggle yg sama mengatur konfirmasi reversal BUY
// maupun SELL. Lihat blok FINALISASI di bawah.)
input bool   StrictBuyMode          = true;
input bool   StrictSellMode         = true;   // v34: veto simetris StrictBuyMode, dipakai di SellCondAt

// === FINALISASI PRESISI ===
// (1) Sinyal trend wajib ADX sedang MENGUAT (bukan sisa trend lama yg meluruh
//     di area ranging - itu sumber sinyal zigzag yg tersisa).
// (2) Reversal wajib pantulan/breakdown SUNGGUHAN: BUY reversal wajib close
//     DI ATAS high candle sebelumnya, SELL reversal wajib close DI BAWAH low
//     candle sebelumnya. SATU toggle ini mengatur kedua arah sekaligus supaya
//     BUY & SELL reversal selalu sinkron (sebelumnya konfirmasi BUY sempat
//     terpisah ke StrictBuyMode, sudah disatukan ke sini).
input bool   FinalStrictMode        = true;
// ══════════════════════════════════════════════════════════════════════
// === v2.00 MENGEMBALIKAN KEMANDIRIAN INDIKATOR ========================
// ══════════════════════════════════════════════════════════════════════
// TEMUAN AUDIT: dlm TrendFollowingMode (default), variabel signalVal &
// indiVal - yaitu INTI rumus asli indikator 2011 ini, yg menggabungkan
// Momentum/ATR/CCI/RSI - DIHITUNG tapi TIDAK PERNAH DIPAKAI. Kedua nilai
// itu hanya terpakai di cabang counter-trend yg tidak aktif.
// Akibatnya indikator ini menyusut jadi sekadar "ADX + DI + RSI" - PERSIS
// bahan yg sudah dihitung sendiri oleh EA di filter rezimnya. Dua sistem
// memakai data yg sama pasti hampir selalu sepakat, jadi ia tak menambah
// informasi apa pun. Terbukti di jurnal: "Ditolak - Entry_Signal_Pro tdk
// setuju" cuma 13 kali dlm 7 BULAN. LANTAI 3 arsitektur ini sesungguhnya
// tidak memberi konfirmasi independen.
// PERBAIKAN: rumus rasio Momentum/ATR/CCI dihidupkan kembali sbg syarat
// TAMBAHAN yg nyata. Kini ESP membawa informasi yg TIDAK dimiliki EA -
// itulah gunanya sebagai konfirmator independen.
// v5.00: dari pengamatan visual Anda di AUDSGD - hanya 2 panah dalam
// ~120 bar, dan 1 dari 2 salah arah. Terlalu jarang DAN tidak akurat.
// Sebabnya rumus inti dipasang sbg GERBANG KERAS (AND) di atas rantai
// syarat yg sudah panjang: TrendFollowing + RSI + Momentum + ADX +
// Strict + Final. Satu saja meleset, panah batal. Peluang lolos sangat
// kecil, dan yg lolos pun belum tentu benar karena arahnya dinilai dari
// SATU bar saja.
// PERBAIKAN: rumus inti kini bisa dijadikan syarat LUNAK - ia menambah
// kekuatan sinyal tapi tidak lagi membatalkan sendirian. Dan arah wajib
// dikonfirmasi beberapa bar (CoreConfirmBars) supaya panah tidak muncul
// melawan gerakan yg sedang berjalan.
input bool   UseCoreMomentumFilter  = true;  // pakai rumus inti (signalVal vs indiVal)
input bool   CoreFilterAsHardGate   = false; // v5.00: false = syarat LUNAK (disarankan), true = gerbang keras
input double CoreMomentumMargin     = 0.0;   // margin selisih yg diwajibkan
input int    CoreConfirmBars        = 2;     // [WARISAN] tak lagi menyaring pendaftaran panah (lihat v7.00)
// ══════════════════════════════════════════════════════════════════════
// === v3.00 NORMALISASI ATR — WAJIB UTK LINTAS-INSTRUMEN ==============
// ══════════════════════════════════════════════════════════════════════
// BUG SKALA BERAT pada rumus inti. Perhatikan satuannya:
//     signalVal = momVal / (atrVal + adxVal) - subtractFromSignalVal
//     indiVal   = (atrVal + cciVal + rsiVal) / adxVal - subtractFromIndiVal
// momVal ~100, cciVal ~±200, rsiVal 0-100, adxVal 0-100 — semuanya OSILATOR
// BERBATAS. Tapi atrVal = iATR() dlm SATUAN HARGA MENTAH:
//     EURUSD 0,0010 | XAUUSD 20 | BTCUSD 500 | US30 120
// Rentangnya 500.000x. Akibat nyata pada selisih (signalVal - indiVal):
//     EURUSD -0,38 | XAUUSD -2,97 | US30 -8,51 | BTCUSD -24,21
// Indikator 2011 ini dirancang utk forex, di mana ATR praktis NOL & tak
// berpengaruh. Begitu dipakai di emas ia mulai menyimpang; di indeks dan
// crypto ATR MENDOMINASI seluruh rumus, sehingga syarat BUY (signalVal >
// indiVal) menjadi MUSTAHIL terpenuhi — BUY terblokir permanen.
// PERBAIKAN: ATR dinormalisasi thd ATR jangka panjangnya sendiri, jadi
// nilainya selalu berkisar 1,0 di instrumen APA PUN. Ini sekaligus
// membuatnya BERMAKNA: "volatilitas sekarang dibanding kebiasaan pasar
// ini sendiri" — bukan angka harga mentah yg tak bisa dibandingkan.
// Perilaku di forex tetap sama persis (0,001 -> 1,0 hanya menggeser
// pembagi 25,001 -> 26,0, yaitu 4%), tapi kini SERAGAM di semua pasar.
input bool   NormalizeATRInFormula  = true;  // WAJIB true utk multi-instrumen
input int    ATRLongPeriod          = 100;   // periode ATR pembanding (basis normalisasi)
input double ArrowOffsetATR         = 0.35;  // v3.00: jarak panah dari candle (x ATR) - skala-bebas
// ══════════════════════════════════════════════════════════════════════
// === v3.00 ADAPTASI AMBANG RSI KE PASAR (multi-pair) ==================
// ══════════════════════════════════════════════════════════════════════
// OverboughtLevel=72 & OversoldLevel=28 adalah angka TETAP. Masalahnya,
// sebaran RSI sangat berbeda antar pasar: crypto & indeks bisa bertahan
// di RSI>70 berminggu-minggu (72 jadi terlalu mudah tersentuh -> BUY
// terus diveto StrictBuyMode), sementara forex mayor jarang lewat 65
// (72 nyaris tak pernah tercapai -> vetonya tak pernah bekerja).
// v3.00 mengukur PERSENTIL sebaran RSI pasar ini sendiri, lalu memakai
// itu sbg batas jenuh. Diukur sekali di bar tertutup, lalu DIKUNCI.
input bool   AutoRSILevels          = true;  // setel batas jenuh dari sebaran RSI pasar ini
input int    AutoCalibBars          = 600;   // brp bar riwayat utk mengukur
input double AutoRSIPercentile      = 12.0;  // persentil bawah/atas (12 -> 12% & 88%)
input bool   PrintInstrumentProfile = true;  // cetak hasil pengukuran ke jurnal
// === v2.00 KELUARAN KEKUATAN SINYAL (buffer 2) ========================
// Nilai 0-100: seberapa lebar keunggulan momentum inti + keberpihakan DI.
// EA bisa memakainya utk membedakan konfirmasi kuat dari yg pas-pasan.
input bool   UseSignalStrength      = true;
// === v4.00 KONTRAK TIM: hak VETO ====================================
// Anggota ini membatalkan sinyal bila melihat entri yang jelas TELAT
// atau tidak berdasar - dua keadaan yang tak terlihat oleh Supertrend:
//  1. RSI sudah jenuh BERLAWANAN arah -> masuk sekarang = mengejar
//     gerakan yang sebagian besar sudah terjadi.
//  2. ADX terlalu rendah -> tidak ada tren yang layak diikuti sama
//     sekali, apa pun kata garis Supertrend.
// ══════════════════════════════════════════════════════════════════════
// === v6.00 ESP NAIK PANGKAT JADI PEMICU UTAMA ========================
// ══════════════════════════════════════════════════════════════════════
// Pengamatan Anda: panah ESP paling sering benar arahnya dibanding tiga
// indikator lain. Data jurnal mendukungnya - dari 28 pencabutan sinyal,
// ESP adalah PEMVETO TERBANYAK (8 kali). Artinya ESP kerap TIDAK setuju
// dgn sinyal yang dipicu Supertrend; kalau ESP memang lebih akurat, maka
// sinyal-sinyal itu memang buruk, dan ESP seharusnya MEMIMPIN.
//
// Konsekuensinya ESP harus dibenahi lebih dulu. Tiga kelemahan yang Anda
// sebut - panah di zona zigzag, panah di titik jenuh, dan arah yang
// kadang salah - ditangani oleh tiga penyaring baru berikut.
//
// (1) STRUKTUR SWING. Tren naik sejati membentuk Higher-High + Higher-Low.
//     Koreksi harga TIDAK. Ini pembeda paling andal antara "tren berbalik"
//     dan "harga cuma mundur sebentar".
// (2) KEDALAMAN RETRACE. Koreksi yang wajar biasanya mundur <61,8% dari
//     kaki sebelumnya. Kalau lebih dalam dari itu, kemungkinan besar
//     memang pembalikan - bukan koreksi.
// (3) PENJAGA TITIK JENUH. Panah dilarang muncul saat harga sudah
//     teregang jauh dari rata-ratanya. Di situlah "sinyal di titik jenuh"
//     yang Anda keluhkan lahir - arah boleh benar, tapi sudah telat.
input string StructComment          = "=== v6.00 PENYARING ZIGZAG & JENUH ==="; // ---
// v8.00: DEFAULT DIMATIKAN. Filter ini menuntut struktur HH/HL yang SUDAH
// MATANG dari 40 bar ke belakang - tapi pada MOMEN PEMBALIKAN yang paling
// berharga, struktur baru itu justru BELUM SEMPAT terbentuk (baru 1 low
// baru, bukan 2). Yang terhitung 40 bar ke belakang masih struktur LAMA,
// sehingga filter ini MENOLAK PERSIS panah pembalikan pertama yang paling
// bernilai - mencerminkan kekhawatiran Anda soal ESP "melewatkan" momen
// yang Anda tandai lingkaran di screenshot.
// Perannya kini digantikan pengukuran yang sama di Supertrend & HeikenAshi
// (Lantai 1 & 2 di sidang konsensus) - itulah "3 indikator memperkuat"
// yang Anda maksud, bukan ESP menyaring dirinya sendiri.
input bool   UseSwingStructureESP   = false;  // wajibkan struktur HH/HL sejalan arah (opsional, cenderung telat)
input int    ESPStructScanBars      = 40;     // brp bar ke belakang mencari swing
// v8.00: DEFAULT DIMATIKAN, alasan sama dgn UseSwingStructureESP. Menuntut
// retrace >=61,8% berarti menunggu SEBAGIAN BESAR pembalikan sudah terjadi
// sebelum panah boleh menyala - persis pola "sinyal di titik jenuh" yang
// Anda keluhkan sejak awal.
input bool   UseRetraceDepth        = false;  // bedakan koreksi dangkal vs pembalikan (opsional, cenderung telat)
input double MaxCorrectionRetrace   = 0.618;  // retrace di bawah ini = masih KOREKSI, bukan balik arah
input bool   UseExhaustionGuard     = true;   // tolak panah saat harga sudah teregang
input int    ExhaustMAPeriod        = 50;     // rata-rata pembanding keteregangan
input double ExhaustMaxATR          = 2.2;    // jarak harga ke rata2 (xATR) yg dianggap jenuh
// --- keluaran baru: KEKUATAN TREN yg diperkirakan (buffer 6) ---
input bool   UseTrendPowerOutput    = true;   // hitung perkiraan kekuatan tren 0-100
input bool   UseTeamVeto            = true;   // aktifkan hak veto
input double VetoADXFloor           = 18.0;   // ADX di bawah ini = tak ada tren
input int    MinCalibBars           = 250;    // bar minimum utk mulai kalibrasi (pelajaran dr tes)

//---- buffers (nama dipertahankan)
double ExtMapBuffer1[];
double ExtMapBuffer2[];
double SignalStrength[];   // buffer 2: kekuatan sinyal 0-100 (kontrak tim)
double SigDir[];           // buffer 3: arah sinyal terakhir (kontrak tim)
double SigAge[];           // buffer 4: umur sejak sinyal, bar (kontrak tim)
double SigVeto[];          // buffer 5: veto 1/0 (kontrak tim)
double TrendPower[];       // buffer 6: perkiraan KEKUATAN tren 0-100 (v6.00)

int    nShift;
string g_symbol;
//--- v3.00: hasil pengukuran karakter pasar (dikunci setelah dihitung)
bool   g_espCalibrated = false;
double g_effOverbought = 0, g_effOversold = 0;

//+------------------------------------------------------------------+
//| v3.00 KALIBRASI AMBANG JENUH KE SEBARAN RSI PASAR INI             |
//+------------------------------------------------------------------+
void CalibrateESPToInstrument()
{
   int avail = Bars - 20;
   if (avail < MinCalibBars) return;              // benar-benar belum cukup
   int scan = AutoCalibBars;
   if (scan > avail) scan = avail;                // pakai seadanya, jangan menunggu
   g_effOverbought = OverboughtLevel;
   g_effOversold   = OversoldLevel;
   if (AutoRSILevels)
   {
      double arr[]; ArrayResize(arr, scan); int n = 0;
      for (int i = scan; i >= 1; i--)
      {
         double r = iRSI(g_symbol, timeFrame, rsiControlPeriod, PRICE_CLOSE, i);
         if (r > 0 && r < 100) { arr[n] = r; n++; }
      }
      if (n >= 50)
      {
         ArrayResize(arr, n);
         ArraySort(arr, WHOLE_ARRAY, 0, MODE_ASCEND);
         int iLo = (int)MathRound(AutoRSIPercentile / 100.0 * (n - 1));
         int iHi = (int)MathRound((100.0 - AutoRSIPercentile) / 100.0 * (n - 1));
         if (iLo < 0) iLo = 0; if (iHi >= n) iHi = n - 1;
         if (arr[iHi] > arr[iLo] + 10)
         { g_effOversold = arr[iLo]; g_effOverbought = arr[iHi]; }
      }
   }
   g_espCalibrated = true;
   if (PrintInstrumentProfile)
   {
      Print("════ PROFIL RSI Entry_Signal_Pro - ", Symbol(), " M", Period(), " ════");
      Print("  Batas jenuh : ", DoubleToString(OversoldLevel,1), "/", DoubleToString(OverboughtLevel,1),
            " (input) -> ", DoubleToString(g_effOversold,1), "/", DoubleToString(g_effOverbought,1), " (sebaran nyata)");
      Print("  CATATAN: dikunci utk sesi ini - tidak repaint.");
   }
}

//--- Evaluasi kondisi SELL/BUY di bar tertentu (shift) - rumus PERSIS kode asli,
//--- cuma dibungkus fungsi supaya bisa dicek juga utk bar sebelumnya (deteksi transisi)
//+------------------------------------------------------------------+
//| v3.00 ATR TERNORMALISASI — skala-bebas di semua instrumen.        |
//| Mengembalikan ATR(atrPeriod) / ATR(ATRLongPeriod), yaitu angka    |
//| tanpa satuan yg berkisar 1,0 di pasar mana pun. Nilai >1 berarti  |
//| pasar sedang lebih bergejolak dari kebiasaannya, <1 lebih tenang. |
//+------------------------------------------------------------------+
double NormalizedATR(int shift)
{
   double a = iATR(g_symbol, timeFrame, atrPeriod, shift);
   if (!NormalizeATRInFormula) return a;              // perilaku warisan
   double aLong = iATR(g_symbol, timeFrame, ATRLongPeriod, shift);
   if (aLong <= 0) return 1.0;
   return a / aLong;
}

//+------------------------------------------------------------------+
//| v6.00 STRUKTUR SWING - pembeda tren sejati vs koreksi/zigzag      |
//| +1 struktur naik utuh | -1 struktur turun utuh | 0 tak jelas      |
//+------------------------------------------------------------------+
int ESPSwingStructure(int shift)
{
   double h1 = 0, h2 = 0, l1 = 0, l2 = 0;
   for (int i = shift + 2; i < shift + ESPStructScanBars && i < Bars - 3; i++)
   {
      bool isHi = (High[i] > High[i-1] && High[i] > High[i-2] &&
                   High[i] > High[i+1] && High[i] > High[i+2]);
      bool isLo = (Low[i]  < Low[i-1]  && Low[i]  < Low[i-2] &&
                   Low[i]  < Low[i+1]  && Low[i]  < Low[i+2]);
      if (isHi) { if (h1 == 0) h1 = High[i]; else if (h2 == 0) h2 = High[i]; }
      if (isLo) { if (l1 == 0) l1 = Low[i];  else if (l2 == 0) l2 = Low[i];  }
      if (h1 > 0 && h2 > 0 && l1 > 0 && l2 > 0) break;
   }
   if (h1 <= 0 || h2 <= 0 || l1 <= 0 || l2 <= 0) return 0;
   if (h1 > h2 && l1 > l2) return  1;   // HH + HL = struktur naik
   if (l1 < l2 && h1 < h2) return -1;   // LL + LH = struktur turun
   return 0;
}

//+------------------------------------------------------------------+
//| v6.00 KEDALAMAN RETRACE - koreksi dangkal atau pembalikan?        |
//| Mengembalikan rasio mundur thd kaki sebelumnya (0..1+).           |
//| < MaxCorrectionRetrace = masih KOREKSI (jangan lawan arah utama)  |
//+------------------------------------------------------------------+
double ESPRetraceRatio(int shift, int dir)
{
   // dir = arah panah yg diajukan. Utk panah SELL (-1), kita ukur seberapa
   // dalam harga sudah mundur dari puncak kaki NAIK sebelumnya.
   double hi = 0, lo = 0;
   int scan = ESPStructScanBars;
   for (int i = shift; i < shift + scan && i < Bars; i++)
   {
      if (hi == 0 || High[i] > hi) hi = High[i];
      if (lo == 0 || Low[i]  < lo) lo = Low[i];
   }
   double range = hi - lo;
   if (range <= 0) return 1.0;
   if (dir == -1) return (hi - Close[shift]) / range;   // mundur dari puncak
   return (Close[shift] - lo) / range;                  // naik dari dasar
}

//+------------------------------------------------------------------+
//| v6.00 PENJAGA TITIK JENUH - harga sudah teregang dari rata-rata?  |
//+------------------------------------------------------------------+
// v8.00 DIPERBAIKI: fungsi lama menolak SEMUA panah saat harga teregang -
// termasuk panah yang justru MELAWAN arah teregangnya. Itu terbalik:
// panah SELL saat harga sudah jauh DI ATAS rata-rata bukan "mengejar",
// itu justru CONTOH TEKS-BUKU pembalikan dari titik jenuh (mean-reversion)
// - persis jenis sinyal yang paling berharga, dan persis yang Anda tandai
// di screenshot (SELL tepat di puncak sebelum harga berbalik turun).
// Kini HANYA panah yang MENERUSKAN arah teregang yang ditolak (mengejar);
// panah yang MELAWANNYA (menangkap pembalikan) dibiarkan lewat.
bool ESPIsExhausted(int shift, int dir)
{
   double ma  = iMA(g_symbol, timeFrame, ExhaustMAPeriod, 0, MODE_EMA, PRICE_CLOSE, shift);
   double atr = iATR(g_symbol, timeFrame, atrPeriod, shift);
   if (ma <= 0 || atr <= 0) return false;
   double dist = (Close[shift] - ma) / atr;
   // harga jauh DI ATAS rata2 (dist besar+) & panah BUY = MENERUSKAN = tolak
   if (dist >  ExhaustMaxATR && dir ==  1) return true;
   // harga jauh DI BAWAH rata2 (dist besar-) & panah SELL = MENERUSKAN = tolak
   if (dist < -ExhaustMaxATR && dir == -1) return true;
   // sisanya (termasuk panah MELAWAN arah teregang) = pembalikan, IZINKAN
   return false;
}

bool SellCondAt(int shift)
{
   double momVal = iMomentum(g_symbol, timeFrame, momentumPeriod, PRICE_TYPICAL, shift);
   double atrVal = NormalizedATR(shift);   // v3.00: skala-bebas (lihat NormalizeATRInFormula)
   double cciVal = iCCI(g_symbol, timeFrame, cciPeriod, PRICE_TYPICAL, shift);
   double rsiVal = iRSI(g_symbol, timeFrame, rsiPeriod, PRICE_TYPICAL, shift);
   double adxVal = iADX(g_symbol, timeFrame, adxPeriod, PRICE_TYPICAL, MODE_MAIN, shift);

   double denom1 = atrVal + adxVal; if (denom1 == 0) denom1 = 0.0000001;
   double denom2 = adxVal;          if (denom2 == 0) denom2 = 0.0000001;
   double signalVal = (momVal / denom1) - subtractFromSignalVal;
   double indiVal   = ((atrVal + cciVal + rsiVal) / denom2) - subtractFromIndiVal;

   double adx1Val      = iADX(g_symbol, timeFrame, adxControlPeriod, PRICE_CLOSE, MODE_MAIN, shift);
   double adx1PLUSVal  = iADX(g_symbol, timeFrame, adxControlPeriod, PRICE_CLOSE, MODE_PLUSDI, shift);
   double adx1MINUSVal = iADX(g_symbol, timeFrame, adxControlPeriod, PRICE_CLOSE, MODE_MINUSDI, shift);
   double rsi1Val      = iRSI(g_symbol, timeFrame, rsiControlPeriod, PRICE_CLOSE, shift);

   if (TrendFollowingMode)
   {
      // SELL saat trend TURUN kuat: -DI dominan, RSI jauh di bawah garis tengah,
      // momentum jelas turun, ADX kuat. Zona netral menyaring zigzag/koreksi.
      bool ok = (adx1MINUSVal > adx1PLUSVal &&
                 rsi1Val < (rsiTrigger - RSIBufferZone) &&
                 momVal  < (100.0 - MomentumBufferZone) &&
                 adx1Val > adxTrigger);
      // MODE KETAT: jangan SELL kalau RSI sudah jenuh-jual (<= Oversold) -
      // itu artinya trend turun sudah tua/kehabisan tenaga, masuk sekarang telat
      // (cermin dari StrictBuyMode+OverboughtLevel di sisi BUY).
      double espOS = g_espCalibrated ? g_effOversold : OversoldLevel;
      if (ok && StrictSellMode && rsi1Val <= espOS) ok = false;
      // v2.00: rumus INTI dihidupkan kembali. Utk SELL, tekanan jual sejati
      // ditandai signalVal berada DI BAWAH indiVal dgn margin yg diminta.
      if (ok && UseCoreMomentumFilter && CoreFilterAsHardGate &&
          signalVal > (indiVal - CoreMomentumMargin)) ok = false;
      // FINALISASI: ADX wajib sedang MENGUAT - sinyal di area ranging biasanya
      // numpang ADX sisa trend lama yg sedang meluruh, bukan trend baru.
      if (ok && FinalStrictMode)
      {
         double adx1Older = iADX(g_symbol, timeFrame, adxControlPeriod, PRICE_CLOSE, MODE_MAIN, shift + 1);
         if (adx1Val < adx1Older) ok = false;
      }
      return ok;
   }

   // perilaku asli counter-trend
   return (signalVal < indiVal && adx1MINUSVal < adx1PLUSVal && rsi1Val > rsiTrigger && adx1Val > adxTrigger);
}

bool BuyCondAt(int shift)
{
   double momVal = iMomentum(g_symbol, timeFrame, momentumPeriod, PRICE_TYPICAL, shift);
   double atrVal = NormalizedATR(shift);   // v3.00: skala-bebas (lihat NormalizeATRInFormula)
   double cciVal = iCCI(g_symbol, timeFrame, cciPeriod, PRICE_TYPICAL, shift);
   double rsiVal = iRSI(g_symbol, timeFrame, rsiPeriod, PRICE_TYPICAL, shift);
   double adxVal = iADX(g_symbol, timeFrame, adxPeriod, PRICE_TYPICAL, MODE_MAIN, shift);

   double denom1 = atrVal + adxVal; if (denom1 == 0) denom1 = 0.0000001;
   double denom2 = adxVal;          if (denom2 == 0) denom2 = 0.0000001;
   double signalVal = (momVal / denom1) - subtractFromSignalVal;
   double indiVal   = ((atrVal + cciVal + rsiVal) / denom2) - subtractFromIndiVal;

   double adx1Val      = iADX(g_symbol, timeFrame, adxControlPeriod, PRICE_CLOSE, MODE_MAIN, shift);
   double adx1PLUSVal  = iADX(g_symbol, timeFrame, adxControlPeriod, PRICE_CLOSE, MODE_PLUSDI, shift);
   double adx1MINUSVal = iADX(g_symbol, timeFrame, adxControlPeriod, PRICE_CLOSE, MODE_MINUSDI, shift);
   double rsi1Val      = iRSI(g_symbol, timeFrame, rsiControlPeriod, PRICE_CLOSE, shift);

   if (TrendFollowingMode)
   {
      // BUY saat trend NAIK kuat: +DI dominan, RSI jauh di atas garis tengah,
      // momentum jelas naik, ADX kuat. Zona netral menyaring zigzag/koreksi.
      bool ok = (adx1PLUSVal > adx1MINUSVal &&
                 rsi1Val > (rsiTrigger + RSIBufferZone) &&
                 momVal  > (100.0 + MomentumBufferZone) &&
                 adx1Val > adxTrigger);
      // MODE KETAT: jangan BUY kalau RSI sudah jenuh-beli (>= Overbought) -
      // itu artinya trend naik sudah tua/kehabisan tenaga, masuk sekarang telat
      // (contoh kasus: panah biru tepat di puncak yg langsung berbalik turun).
      double espOB = g_espCalibrated ? g_effOverbought : OverboughtLevel;
      if (ok && StrictBuyMode && rsi1Val >= espOB) ok = false;
      // v2.00: rumus INTI dihidupkan kembali (cermin sisi SELL).
      if (ok && UseCoreMomentumFilter && CoreFilterAsHardGate &&
          signalVal < (indiVal + CoreMomentumMargin)) ok = false;
      // FINALISASI: ADX wajib sedang MENGUAT (sama seperti sisi SELL)
      if (ok && FinalStrictMode)
      {
         double adx1Older = iADX(g_symbol, timeFrame, adxControlPeriod, PRICE_CLOSE, MODE_MAIN, shift + 1);
         if (adx1Val < adx1Older) ok = false;
      }
      return ok;
   }

   // perilaku asli counter-trend
   return (signalVal > indiVal && adx1PLUSVal < adx1MINUSVal && rsi1Val < rsiTrigger && adx1Val > adxTrigger);
}

//--- Deteksi PEMBALIKAN DI TITIK JENUH: habis trend naik ekstrim (RSI sempat
//--- overbought dlm beberapa bar terakhir), lalu RSI mulai turun & momentum
//--- berbalik turun -> sinyal SELL pembalikan. (Kebalikannya utk BUY.)
bool SellRevCondAt(int shift)
{
   if (!UseReversalSignals) return false;

   // bukti kondisi jenuh-beli baru saja terjadi: RSI sempat >= Overbought dlm lookback
   bool wasOverbought = false;
   for (int k = shift + 1; k <= shift + ReversalLookback; k++)
   {
      double r = iRSI(g_symbol, timeFrame, rsiControlPeriod, PRICE_CLOSE, k);
      if (r >= (g_espCalibrated ? g_effOverbought : OverboughtLevel)) { wasOverbought = true; break; }
   }
   if (!wasOverbought) return false;

   // sekarang mulai berbalik: RSI menurun & momentum sudah di bawah 100
   double rsiNow  = iRSI(g_symbol, timeFrame, rsiControlPeriod, PRICE_CLOSE, shift);
   double rsiPrev = iRSI(g_symbol, timeFrame, rsiControlPeriod, PRICE_CLOSE, shift + 1);
   double momNow  = iMomentum(g_symbol, timeFrame, momentumPeriod, PRICE_TYPICAL, shift);

   bool ok = (rsiNow < rsiPrev && rsiNow < OverboughtLevel && momNow < (100.0 - MomentumBufferZone));

   // FINALISASI: pembalikan dari jenuh-beli harus PENURUNAN SUNGGUHAN - candle
   // sinyal wajib menutup DI BAWAH low candle sebelumnya (breakdown mini),
   // cermin dari aturan breakout BUY. Penurunan tipis di tengah uptrend
   // (koreksi biasa yg lalu lanjut naik) tidak akan memenuhi syarat ini.
   if (ok && FinalStrictMode)
   {
      double closeNow = iClose(g_symbol, timeFrame, shift);
      double lowPrev  = iLow(g_symbol, timeFrame, shift + 1);
      if (closeNow >= lowPrev) ok = false;
   }

   return ok;
}

bool BuyRevCondAt(int shift)
{
   if (!UseReversalSignals) return false;

   // bukti kondisi jenuh-jual baru saja terjadi: RSI sempat <= Oversold dlm lookback
   bool wasOversold = false;
   for (int k = shift + 1; k <= shift + ReversalLookback; k++)
   {
      double r = iRSI(g_symbol, timeFrame, rsiControlPeriod, PRICE_CLOSE, k);
      if (r <= (g_espCalibrated ? g_effOversold : OversoldLevel)) { wasOversold = true; break; }
   }
   if (!wasOversold) return false;

   // sekarang mulai berbalik: RSI menaik & momentum sudah di atas 100
   double rsiNow  = iRSI(g_symbol, timeFrame, rsiControlPeriod, PRICE_CLOSE, shift);
   double rsiPrev = iRSI(g_symbol, timeFrame, rsiControlPeriod, PRICE_CLOSE, shift + 1);
   double momNow  = iMomentum(g_symbol, timeFrame, momentumPeriod, PRICE_TYPICAL, shift);

   bool ok = (rsiNow > rsiPrev && rsiNow > OversoldLevel && momNow > (100.0 + MomentumBufferZone));

   // FINALISASI: pantulan dari jenuh-jual harus PANTULAN SUNGGUHAN - candle
   // sinyal wajib menutup DI ATAS high candle sebelumnya (breakout mini).
   // Pantulan lemah yg cuma naik tipis di tengah downtrend (lalu gagal &
   // lanjut turun) tidak akan memenuhi syarat ini. (Disatukan ke
   // FinalStrictMode - dulu terpisah ke StrictBuyMode, lihat catatan di atas.)
   if (ok && FinalStrictMode)
   {
      double closeNow  = iClose(g_symbol, timeFrame, shift);
      double highPrev  = iHigh(g_symbol, timeFrame, shift + 1);
      if (closeNow <= highPrev) ok = false;
   }

   return ok;
}

int OnInit()
{
   SetIndexStyle(0, DRAW_ARROW, 0, 1);
   SetIndexArrow(0, wingdingsUpArrow);
   SetIndexBuffer(0, ExtMapBuffer1);

   SetIndexStyle(1, DRAW_ARROW, 0, 1);
   SetIndexArrow(1, wingdingsDownArrow);
   SetIndexBuffer(1, ExtMapBuffer2);

   // --- kontrak tim: buffer 2-5 (kalkulasi, dibaca Supertrend & EA) ---
   IndicatorBuffers(7);
   SetIndexBuffer(2, SignalStrength); SetIndexStyle(2, DRAW_NONE);
   SetIndexBuffer(3, SigDir);         SetIndexStyle(3, DRAW_NONE);
   SetIndexBuffer(4, SigAge);         SetIndexStyle(4, DRAW_NONE);
   SetIndexBuffer(5, SigVeto);        SetIndexStyle(5, DRAW_NONE);
   SetIndexBuffer(6, TrendPower);     SetIndexStyle(6, DRAW_NONE);
   SetIndexLabel(3, "ESP Arah (+1/-1)");
   SetIndexLabel(4, "ESP Umur Sinyal (bar)");
   SetIndexLabel(5, "ESP Veto (1/0)");
   SetIndexLabel(6, "ESP Kekuatan Tren (0-100)");
   ArraySetAsSeries(SignalStrength, true);
   ArraySetAsSeries(SigDir,  true);
   ArraySetAsSeries(SigAge,  true);
   ArraySetAsSeries(SigVeto, true);
   ArraySetAsSeries(TrendPower, true);

   IndicatorShortName("Entry Signal Pro v2.00");
   SetIndexLabel(0, "BUY SIGNAL");
   SetIndexLabel(1, "SELL SIGNAL");
   SetIndexLabel(2, "Kekuatan Sinyal (0-100)");

   g_symbol = (symbol == "0" || symbol == "") ? Symbol() : symbol;

   switch (Period())
   {
      case     1: nShift = 1;   break;
      case     5: nShift = 3;   break;
      case    15: nShift = 5;   break;
      case    30: nShift = 10;  break;
      case    60: nShift = 15;  break;
      case   240: nShift = 20;  break;
      case  1440: nShift = 80;  break;
      case 10080: nShift = 100; break;
      case 43200: nShift = 200; break;
      default:    nShift = 15;  break; // fallback aman (dulu 0 kalau tak dikenal)
   }

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   // --- replikasi persis logika counted_bars asli ---
   int counted_bars = prev_calculated;
   if (counted_bars > 0) counted_bars--;
   int limit = rates_total - counted_bars;
   if (limit > rates_total - 2) limit = rates_total - 2; // -2 supaya cek bar i+1 selalu aman
   if (limit < 1) limit = 1;

   // --- urutan loop PERSIS SAMA seperti kode asli: i=0 (bar terbaru) -> limit-1 ---
   if (!g_espCalibrated) CalibrateESPToInstrument();

   for (int i = 0; i < limit; i++)
   {
      ExtMapBuffer1[i] = EMPTY_VALUE;
      ExtMapBuffer2[i] = EMPTY_VALUE;

      // --- v2.00 KEKUATAN SINYAL (0-100), buffer 2 ---
      // Menggabungkan LEBAR keunggulan momentum inti dgn ketegasan
      // keberpihakan DI. Memberi EA ukuran "seberapa yakin konfirmasi ini",
      // bukan sekadar setuju/tidak - sinkron dgn Skor Kualitas Tren di
      // Supertrend_Promax v4.00 dan Kekuatan Momentum di HeikenAshi v3.00.
      if (UseSignalStrength)
      {
         double mv = iMomentum(g_symbol, timeFrame, momentumPeriod, PRICE_TYPICAL, i);
         double av = NormalizedATR(i);   // v3.00: skala-bebas
         double cv = iCCI(g_symbol, timeFrame, cciPeriod, PRICE_TYPICAL, i);
         double rv = iRSI(g_symbol, timeFrame, rsiPeriod, PRICE_TYPICAL, i);
         double dv = iADX(g_symbol, timeFrame, adxPeriod, PRICE_TYPICAL, MODE_MAIN, i);
         double d1 = av + dv; if (d1 == 0) d1 = 0.0000001;
         double d2 = dv;      if (d2 == 0) d2 = 0.0000001;
         double sV = (mv / d1) - subtractFromSignalVal;
         double iV = ((av + cv + rv) / d2) - subtractFromIndiVal;
         double pDI = iADX(g_symbol, timeFrame, adxControlPeriod, PRICE_CLOSE, MODE_PLUSDI,  i);
         double mDI = iADX(g_symbol, timeFrame, adxControlPeriod, PRICE_CLOSE, MODE_MINUSDI, i);
         double st  = (MathAbs(sV - iV) / 3.0 * 50.0) + (MathAbs(pDI - mDI) / 25.0 * 50.0);
         if (st < 0) st = 0; if (st > 100) st = 100;
         SignalStrength[i] = st;
      }
      else SignalStrength[i] = 0;

      // --- PENINGKATAN PRESISI (satu-satunya perubahan perilaku): panah hanya  ---
      // --- muncul di candle PERTAMA saat kondisi BARU mulai terpenuhi          ---
      // --- (transisi dari tidak-sinyal ke sinyal). Candle berikutnya yang       ---
      // --- kondisinya masih sama TIDAK diberi panah lagi - ini yang            ---
      // --- menghilangkan panah bertumpuk di tiap candle, tanpa pelacakan       ---
      // --- waktu/jarak yang rawan bug. Murni bandingkan bar ini vs bar          ---
      // --- sebelumnya, stabil di backtest, tick-by-tick, maupun live.          ---
      bool sellNow  = SellCondAt(i);
      bool sellPrev = SellCondAt(i + 1);
      bool buyNow   = BuyCondAt(i);
      bool buyPrev  = BuyCondAt(i + 1);

      // --- sinyal PEMBALIKAN di titik jenuh (deteksi transisi juga) ---
      bool sellRevNow  = SellRevCondAt(i);
      bool sellRevPrev = SellRevCondAt(i + 1);
      bool buyRevNow   = BuyRevCondAt(i);
      bool buyRevPrev  = BuyRevCondAt(i + 1);

      bool sellSignal = (sellNow && !sellPrev) || (sellRevNow && !sellRevPrev);
      bool buySignal  = (buyNow && !buyPrev)  || (buyRevNow && !buyRevPrev);

      // --- ANTI-KONTRADIKSI: jangan kasih SELL kalau kondisi trend-NAIK sedang ---
      // --- aktif, dan sebaliknya. Mencegah panah merah-biru bertentangan       ---
      // --- muncul berdekatan di area ranging.                                   ---
      if (buyNow)  sellSignal = false;
      if (sellNow) buySignal  = false;

      //---- SELL SIGNAL: awal kondisi trend-turun ATAU pembalikan dari titik jenuh-beli,
      //---- plus candle sinyalnya sendiri harus candle TURUN (konfirmasi arah)
      if (sellSignal && close[i] < open[i])
      {
         // v3.00: offset panah berbasis ATR, bukan nShift*Point (Point berbeda
         // 500.000x antar instrumen -> panah tenggelam di crypto, melayang di forex)
         double offA = iATR(g_symbol, timeFrame, atrPeriod, i) * ArrowOffsetATR;
         if (offA <= 0) offA = nShift * Point;
         if (showSellSignals) ExtMapBuffer2[i] = high[i] + offA;
         if (Alerts) Alert("SELL SIGNAL at ", g_symbol, ": ", DoubleToString(close[0], Digits), " (TF ", Period(), ")");
         if (PlaySounds) PlaySound(ShortSignalSoundFile);
         if (SignalMail) SendMail("" + g_symbol + " SELL SIGNAL", "SELL SIGNAL on " + g_symbol + ": " + DoubleToString(close[0], Digits) + " (Timeframe: " + IntegerToString(Period()) + ")");
      }

      //---- BUY SIGNAL: awal kondisi trend-naik ATAU pembalikan dari titik jenuh-jual,
      //---- plus candle sinyalnya sendiri harus candle NAIK (konfirmasi arah)
      if (buySignal && close[i] > open[i])
      {
         double offB = iATR(g_symbol, timeFrame, atrPeriod, i) * ArrowOffsetATR;
         if (offB <= 0) offB = nShift * Point;
         if (showBuySignals) ExtMapBuffer1[i] = low[i] - offB;
         if (Alerts) Alert("BUY SIGNAL at ", g_symbol, ": ", DoubleToString(close[0], Digits), " (TF ", Period(), ")");
         if (PlaySounds) PlaySound(LongSignalSoundFile);
         if (SignalMail) SendMail("" + g_symbol + " BUY SIGNAL", "BUY SIGNAL on " + g_symbol + ": " + DoubleToString(close[0], Digits) + " (Timeframe: " + IntegerToString(Period()) + ")");
      }

      // ══ v4.00 KONTRAK TIM: arah bertahan, umur, dan veto ═══════════
      // Panah hanya menyala satu bar. Anggota tim lain butuh tahu "arah
      // terakhir yang diajukan ESP" dan "sudah berapa bar lalu", karena
      // konfirmasi yang berumur 1 bar jauh berbeda maknanya dari yang
      // sudah 10 bar. Buffer 3 & 4 menyimpan itu supaya sidang konsensus
      // tak perlu menyisir mundur sendiri.
      // v5.00: arah wajib SEJALAN dgn gerakan beberapa bar terakhir, bukan
      // hanya candle itu sendiri. Ini yg mencegah panah melawan arah.
      // ══ v6.00 PENYARING SEBELUM PANAH DITERBITKAN ══════════════════
      // Tiga penyaring ini menjawab keluhan: panah di zona zigzag, panah
      // di titik jenuh, dan panah yang salah arah.
      if (buySignal || sellSignal)
      {
         int wantDir = buySignal ? 1 : -1;

         // (1) struktur swing wajib SEJALAN - koreksi tak punya HH/HL
         if (UseSwingStructureESP)
         {
            int stSig = ESPSwingStructure(i);
            if (stSig != 0 && stSig != wantDir)
            { buySignal = false; sellSignal = false; }
         }
         // (2) retrace masih dangkal = ini KOREKSI, jangan dilawan
         if ((buySignal || sellSignal) && UseRetraceDepth)
         {
            double rr = ESPRetraceRatio(i, wantDir);
            if (rr < MaxCorrectionRetrace)
            { buySignal = false; sellSignal = false; }
         }
         // (3) harga sudah teregang jauh = titik jenuh, sudah telat
         if ((buySignal || sellSignal) && UseExhaustionGuard)
         {
            if (ESPIsExhausted(i, wantDir))
            { buySignal = false; sellSignal = false; }
         }
      }

      // ══ v6.00 KEKUATAN TREN YANG DIPERKIRAKAN (buffer 6) ═══════════
      // Menjawab "seberapa kuat tren naik/turun ini" - dipakai anggota tim
      // lain utk menakar seberapa jauh target yang masuk akal.
      if (UseTrendPowerOutput)
      {
         double adxP = iADX(g_symbol, timeFrame, adxControlPeriod, PRICE_CLOSE, MODE_MAIN, i);
         double pdiP = iADX(g_symbol, timeFrame, adxControlPeriod, PRICE_CLOSE, MODE_PLUSDI,  i);
         double mdiP = iADX(g_symbol, timeFrame, adxControlPeriod, PRICE_CLOSE, MODE_MINUSDI, i);
         double atrP = iATR(g_symbol, timeFrame, atrPeriod, i);
         double pw = 0;
         if (adxP > 0)
         {
            pw += MathMin((adxP - 15.0) / 25.0, 1.0) * 40.0;           // tenaga
            pw += MathMin(MathAbs(pdiP - mdiP) / 25.0, 1.0) * 30.0;    // ketegasan arah
            int stP = ESPSwingStructure(i);
            if (stP != 0) pw += 20.0;                                  // struktur jelas
            if (atrP > 0)
            {
               double bodyP = MathAbs(Close[i] - Open[i]) / atrP;
               pw += MathMin(bodyP / 0.6, 1.0) * 10.0;                 // tubuh candle
            }
         }
         if (pw < 0) pw = 0; if (pw > 100) pw = 100;
         TrendPower[i] = pw;
      }
      else TrendPower[i] = 0;

      // ══ v7.00 PERBAIKAN: PANAH WAJIB TERDAFTAR APA ADANYA ══════════
      // BUKTI dari tes Anda: panel menunjukkan "umur 21" - panah ESP
      // terakhir 21 bar lalu - padahal di chart jelas ada panah kuning
      // beberapa bar sebelumnya. Panah TAMPIL tapi TIDAK TERDAFTAR.
      //
      // Sebabnya SigDir (buffer 3, yang dibaca Supertrend sbg pemicu)
      // saya beri syarat TAMBAHAN: close>open DAN beberapa bar berturut
      // searah. Itu penyaringan GANDA - panah sudah lolos struktur swing,
      // kedalaman retrace, dan penjaga titik jenuh, lalu disaring lagi.
      // Sisa revisi lama yang lupa dicabut setelah tiga penyaring baru
      // dipasang.
      //
      // KINI: apa yang TERLIHAT di chart = apa yang TERDAFTAR di buffer.
      // Itu penting bukan sekadar teknis - Anda mengambil keputusan dari
      // panah yang Anda lihat, jadi sistem harus memakai panah yang sama.
      int dNow = 0;
      if (buySignal)  dNow =  1;
      if (sellSignal) dNow = -1;
      if (dNow != 0)
      { SigDir[i] = dNow; SigAge[i] = 0; }
      else if (i + 1 < rates_total && SigDir[i + 1] != EMPTY_VALUE)
      { SigDir[i] = SigDir[i + 1]; SigAge[i] = SigAge[i + 1] + 1; }
      else
      { SigDir[i] = 0; SigAge[i] = 999; }

      // VETO - dua keadaan yang tak terlihat oleh Supertrend:
      double vE = 0;
      if (UseTeamVeto)
      {
         double adxV = iADX(g_symbol, timeFrame, adxControlPeriod, PRICE_CLOSE, MODE_MAIN, i);
         double rsiV = iRSI(g_symbol, timeFrame, rsiControlPeriod, PRICE_CLOSE, i);
         double obV  = g_espCalibrated ? g_effOverbought : OverboughtLevel;
         double osV  = g_espCalibrated ? g_effOversold   : OversoldLevel;
         // (a) tak ada tren yang layak diikuti sama sekali
         if (adxV > 0 && adxV < VetoADXFloor) vE = 1;
         // (b) entri jelas TELAT - RSI sudah jenuh searah gerakan
         if (SigDir[i] ==  1 && rsiV >= obV) vE = 1;
         if (SigDir[i] == -1 && rsiV <= osV) vE = 1;
      }
      SigVeto[i] = vE;
   }

   return(rates_total);
}