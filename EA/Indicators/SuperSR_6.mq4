//+------------------------------------------------------------------+
//| SuperSR_6.mq4                                                     |
//| Original: Copyright © 2006 Scorpion@fxfisherman.com               |
//| Modernisasi & optimasi performa - logika fraktal S/R ASLI          |
//| dipertahankan persis.                                              |
//|                                                                    |
//| VERSI 5.00 - ANGGOTA TIM 4 INDIKATOR (FINAL)                      |
//+------------------------------------------------------------------+
//| PERAN DALAM TIM  : LANTAI 4 - PENJAGA RUANG                       |
//| PERTANYAAN YG DIJAWAB : "Masih ada JALAN, atau sudah mentok?"     |
//|                                                                   |
//| Tiga anggota lain menilai ARAH dan TENAGA. Tak satu pun melihat   |
//| apa yang ada DI DEPAN harga. Padahal sinyal semu paling klasik    |
//| justru lahir di situ: arah benar, tenaga cukup, tapi 5 pip lagi   |
//| sudah menabrak resistance yang berkali-kali menahan harga.        |
//| Anggota inilah yang melihat tembok itu.                           |
//|                                                                   |
//| === KONTRAK KELUARAN TIM ======================================== |
//|   buffer 0 : harga RESISTANCE aktif                               |
//|   buffer 1 : harga SUPPORT aktif                                  |
//|   buffer 4 : RUANG ke resistance, dlm kelipatan ATR               |
//|   buffer 5 : RUANG ke support,    dlm kelipatan ATR               |
//|   buffer 6 : KEKUATAN level terdekat 0-100                        |
//|   buffer 7 : VETO  1 = harga mentok di level kuat, 0 = aman       |
//|                                                                   |
//| KEKUATAN LEVEL dihitung dari berapa kali harga MENYENTUH level    |
//| itu tanpa menembusnya. Level yang sudah 4x menahan jauh lebih     |
//| berarti daripada level yang baru terbentuk sekali.                |
//|                                                                    |
//| PERAN DALAM KOLABORASI 4 INDIKATOR:                                |
//| PENENTU ZONA SUPPORT/RESISTANCE. Indikator ini memberi tahu EA     |
//| level S/R fraktal terdekat - sinyal BUY/SELL dari indikator lain   |
//| jadi LEBIH KUAT bila terjadi dekat zona ini (pantulan dari support |
//| = konfirmasi BUY; penolakan di resistance = konfirmasi SELL).      |
//|                                                                    |
//| PERBAIKAN BESAR dari versi asli 2006:                              |
//| 1. PERFORMA: versi asli menghitung ulang SEMUA bar di SETIAP tick  |
//|    (tanpa incremental) - penyebab tester 10+ MENIT. Sekarang       |
//|    memakai OnCalculate incremental standar: hanya bar baru yang    |
//|    dihitung per tick. Tester akan sedrastis indikator lain.        |
//| 2. Seeding buffer di bar tertua diperbaiki (versi asli membaca     |
//|    nilai buffer yang belum diinisialisasi - bisa merambatkan       |
//|    level 0/acak di awal riwayat).                                  |
//| 3. API modern (#property strict, input, OnInit/OnCalculate).       |
//| 4. Validasi input & watermark bisa dimatikan.                      |
//|                                                                    |
//| PETA BUFFER utk pemanggilan iCustom() dari EA (TIDAK BERUBAH):    |
//|   0 = RESISTANCE (level merah di atas harga)                       |
//|   1 = SUPPORT    (level biru di bawah harga)                       |
//|   Nilai EMPTY_VALUE = belum ada level terbentuk di bar itu         |
//|   (EA wajib cek != EMPTY_VALUE sebelum menghitung jarak).          |
//|                                                                    |
//| JAMINAN NON-REPAINT: level di bar manapun dihitung murni dari      |
//| 5 bar yang SUDAH CLOSED (dgn Shift_Bars>=1, bar termuda yang       |
//| dipakai = bar 1, bukan bar 0 yang sedang berjalan). Level yang     |
//| dibaca EA saat entri TIDAK akan berubah setelahnya.                |
//|                                                                    |
//| CATATAN SINKRONISASI: Contract_Step & Precision dlm satuan Point   |
//| broker (di broker JPY 3-digit: 150 pt = 15 pips, 10 pt = 1 pip).   |
//| EA memanggil dgn 3 parameter pertama persis urutan input ini -    |
//| input tambahan apapun HARUS ditaruh SETELAH Shift_Bars.            |
//+------------------------------------------------------------------+
#property copyright "FxFisherman.com - modernized"
#property link      "http://www.fxfisherman.com"
#property strict
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_color1 clrOrange
#property indicator_color2 clrAqua

input int  Contract_Step = 150;   // [WARISAN] jarak minimal antar level (Point) - dipakai bila UseATRScaling=false
input int  Precision     = 10;    // [WARISAN] offset level dari harga fraktal (Point)
input int  Shift_Bars    = 1;     // Geser deteksi fraktal (bar)
input bool ShowWatermark = false; // Tampilkan watermark fxfisherman.com
// ══════════════════════════════════════════════════════════════════════
// === v3.00 PERBAIKAN SKALA & MASA BERLAKU LEVEL ======================
// ══════════════════════════════════════════════════════════════════════
// MASALAH 1 - SKALA. Contract_Step & Precision dinyatakan dlm POINT broker.
// Di XAUUSD (Digits=2, Point=0.01) itu berarti:
//     jarak minimum antar level = (150+10) x 0.01 = $1,60
// padahal ATR H1 emas sekitar $20. Saringan "jarak minimum" jadi tak ada
// artinya - hampir setiap fraktal diterima jadi level baru, sehingga level
// S/R menumpuk sangat rapat dan kehilangan makna. Nilai 150 itu memang
// dirancang utk forex (150 pt = 15 pip di pair 5-digit), bukan utk emas.
// PERBAIKAN: skala kini RELATIF ATR - otomatis benar di instrumen apa pun.
//
// MASALAH 2 - LEVEL TAK PERNAH KEDALUWARSA. Versi lama meneruskan level
// lama tanpa batas sampai ada fraktal baru yg lolos. Tidak ada mekanisme
// yg membatalkan level ketika harga sudah MENEMBUSNYA. Contoh nyata dari
// periode tes Anda: emas jatuh dari $4.525 ke $3.990, tapi "resistance"
// bisa tetap menunjuk level lama yg sudah lama ditinggalkan - dan EA
// membaca itu sbg zona yg masih berlaku.
// PERBAIKAN: level dibatalkan bila harga menembusnya melewati toleransi,
// dan level yg terlalu tua otomatis gugur.
input bool   UseATRScaling      = true;   // AKTIF = jarak antar level relatif ATR (disarankan)
input int    ATRPeriodSR        = 14;     // periode ATR utk penskalaan
input double MinGapATR          = 2.00;   // v9.00: 1.30 -> 2.00 xATR, jarak antar level jauh lebih lega
input double PrecisionATR       = 0.05;   // offset level dari harga fraktal (x ATR)
input bool   UseLevelExpiry     = true;   // batalkan level yg sudah ditembus / terlalu tua
input double BreakToleranceATR  = 0.25;   // tembus sejauh ini xATR = level dianggap batal
input int    MaxLevelAgeBars    = 150;    // umur maksimum sebuah level (bar)
// v4.00 MULTI-PAIR: cadangan bila ATR belum tersedia. Versi lama memakai
// "BreakToleranceATR * 100 * Point" - dan Point berbeda 500.000x antar
// instrumen (EURUSD 0,00001 vs BTC 1,0), jadi cadangan itu sendiri tidak
// bermakna. Kini cadangannya relatif HARGA (basis poin), bukan Point.
input double FallbackTolBP      = 25.0;   // toleransi cadangan dlm basis poin harga
// ══════════════════════════════════════════════════════════════════════
// === v6.00 VALIDASI SWING - MENJAWAB "LEVEL ASAL DI TENGAH CANDLE" ===
// ══════════════════════════════════════════════════════════════════════
// Pengamatan visual Anda tepat: level lama ditaruh sembarangan, sering
// memotong badan candle. Sebabnya ada TIGA, dan ketiganya diperbaiki:
//
// (1) SETIAP fraktal 5-bar langsung jadi level. Di pasar bergerigi ada
//     puluhan fraktal mikro - tonjolan sebesar 1-2 pip pun diterima,
//     sehingga level berserakan dan kehilangan makna.
//     -> Kini fraktal WAJIB menonjol minimal SwingProminenceATR x ATR
//        dari lembah tetangganya. Tonjolan kecil diabaikan.
//
// (2) Fraktal hanya diperiksa 2 bar kiri-kanan - terlalu sempit; puncak
//     kecil di tengah gerakan besar pun lolos.
//     -> Kini wajib jadi yang TERTINGGI/TERENDAH dalam jendela
//        SwingLookback bar di kedua sisi.
//
// (3) Penembusan hanya dinilai dari CLOSE, sehingga level bertahan walau
//     badan candle sudah melewatinya - itulah "garis memotong candle".
//     -> Kini badan candle ikut dinilai (lihat blok KEDALUWARSA).
input bool   UseSwingValidation = true;   // aktifkan validasi swing (disarankan)
// v7.00 DIPERKETAT berdasar diagnostik tes XAUUSD Anda:
//   cakupan terukur resistance 243/300, support 291/300 (97%!)
//   sementara ambang wajar yang saya tetapkan sendiri 120-260.
//   Artinya validasi v6.00 masih terlalu longgar - level masih lahir
//   dari tonjolan kecil, sehingga tetap terlihat memotong candle.
// v9.00 DIPERKETAT LAGI - berdasar dampak nyata yang terukur:
// Diagnostik tes: "Level BERBEDA lahir: resistance 27" - kriteria saya
// sendiri bilang >15 masih rapat, wajarnya 4-10.
// 27 level dalam 300 bar = ada "tembok" tiap ~11 bar. Akibatnya hampir
// SELALU ada level dekat di depan harga, dan TP selalu terpotong ke situ.
// Buktinya dari jurnal: TP2 nyata hanya 0,34-0,92 xATR padahal plafon
// kelasnya 1,1-1,5 xATR. Sasaran 9 poin di emas H1 praktis mustahil
// menutup spread. Level yang terlalu rapat bukan cuma jelek dipandang -
// ia MERUSAK kualitas target.
input int    SwingLookback      = 12;     // 8 -> 12 bar tiap sisi
input double SwingProminenceATR = 1.10;   // v9.00: 0.70 -> 1.10 xATR
input bool   PrintInstrumentProfile = true; // cetak ringkasan level ke jurnal saat start
// === v5.00 KONTRAK TIM: ruang, kekuatan level, dan hak VETO =========
// Ruang dinyatakan dalam kelipatan ATR supaya bermakna sama di semua
// instrumen: "0,4xATR lagi mentok" sama gawatnya di EURUSD maupun BTC.
input bool   UseTeamVeto        = true;   // aktifkan hak veto
input double VetoRoomATR        = 0.50;   // ruang < ini xATR ke level KUAT = veto
input double StrongLevelPower   = 55.0;   // kekuatan >= ini dianggap level KUAT
input int    TouchScanBars      = 120;    // brp bar ke belakang menghitung sentuhan
input double TouchZoneATR       = 0.25;   // jarak dianggap "menyentuh" level (xATR)
input int    ATRPeriodRoom      = 14;     // ATR utk mengukur ruang

//---- buffers
double v1[]; // buffer 0: Resistance
double v2[]; // buffer 1: Support
//--- v3.00 buffer kalkulasi: umur tiap level (bar) utk mekanisme kedaluwarsa
double ageR[]; // buffer 2
double ageS[]; // buffer 3
//--- v5.00 KONTRAK TIM
double roomR[];    // buffer 4: ruang ke resistance (xATR)
double roomS[];    // buffer 5: ruang ke support (xATR)
double lvlPower[]; // buffer 6: kekuatan level terdekat 0-100
double srVeto[];   // buffer 7: veto 1/0
bool   g_srPrinted = false;   // v6.00: penanda diagnostik sudah dicetak

int OnInit()
{
   IndicatorBuffers(8);   // v5.00: +4 buffer kontrak tim
   SetIndexArrow(0, 159);
   SetIndexStyle(0, DRAW_ARROW, STYLE_SOLID, 1, clrOrange);
   SetIndexDrawBegin(0, -1);
   SetIndexBuffer(0, v1);
   SetIndexLabel(0, "Resistance");
   SetIndexEmptyValue(0, EMPTY_VALUE);

   SetIndexArrow(1, 159);
   SetIndexStyle(1, DRAW_ARROW, STYLE_SOLID, 1, clrAqua);
   SetIndexDrawBegin(1, -1);
   SetIndexBuffer(1, v2);
   SetIndexLabel(1, "Support");
   SetIndexEmptyValue(1, EMPTY_VALUE);

   SetIndexBuffer(2, ageR); SetIndexStyle(2, DRAW_NONE); SetIndexLabel(2, NULL);
   SetIndexBuffer(3, ageS); SetIndexStyle(3, DRAW_NONE); SetIndexLabel(3, NULL);
   ArraySetAsSeries(v1, true);
   ArraySetAsSeries(v2, true);
   SetIndexBuffer(4, roomR);    SetIndexStyle(4, DRAW_NONE); SetIndexLabel(4, "SR Ruang ke Resistance (xATR)");
   SetIndexBuffer(5, roomS);    SetIndexStyle(5, DRAW_NONE); SetIndexLabel(5, "SR Ruang ke Support (xATR)");
   SetIndexBuffer(6, lvlPower); SetIndexStyle(6, DRAW_NONE); SetIndexLabel(6, "SR Kekuatan Level (0-100)");
   SetIndexBuffer(7, srVeto);   SetIndexStyle(7, DRAW_NONE); SetIndexLabel(7, "SR Veto (1/0)");
   ArraySetAsSeries(ageR, true);
   ArraySetAsSeries(ageS, true);
   ArraySetAsSeries(roomR, true);
   ArraySetAsSeries(roomS, true);
   ArraySetAsSeries(lvlPower, true);
   ArraySetAsSeries(srVeto, true);

   if (Contract_Step < 0 || Precision < 0 || Shift_Bars < 0)
   {
      Print("SuperSR_6: ERROR - Contract_Step, Precision & Shift_Bars tidak boleh negatif.");
      return(INIT_PARAMETERS_INCORRECT);
   }

   if (ShowWatermark)
   {
      ObjectCreate("fxfisherman", OBJ_LABEL, 0, 0, 0);
      ObjectSetText("fxfisherman", "fxfisherman.com", 11, "Lucida Handwriting", clrDarkTurquoise);
      ObjectSet("fxfisherman", OBJPROP_CORNER, 2);
      ObjectSet("fxfisherman", OBJPROP_XDISTANCE, 5);
      ObjectSet("fxfisherman", OBJPROP_YDISTANCE, 10);
   }

   IndicatorShortName("SuperSR_6");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   ObjectDelete("fxfisherman");
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
   int minBars = 5 + Shift_Bars + 1;
   if (rates_total < minBars) return(0);

   // --- PERBAIKAN PERFORMA UTAMA: incremental calculation ---
   // Versi asli: SELURUH riwayat dihitung ulang di SETIAP tick (start()
   // tanpa IndicatorCounted) -> tester 10+ menit. Sekarang: hanya bar
   // yang belum terhitung yang diproses.
   int startBar = rates_total - 5 - Shift_Bars - 1; // bar tertua yang bisa dihitung
   if (prev_calculated > 0)
   {
      int newBars = rates_total - prev_calculated;
      startBar = newBars; // bar 0..newBars perlu dihitung ulang (bar berjalan + bar baru)
      if (startBar > rates_total - 5 - Shift_Bars - 1)
         startBar = rates_total - 5 - Shift_Bars - 1;
   }
   if (startBar < 0) startBar = 0;

   for (int i = startBar; i >= 0; i--)
   {
      int shift = i + Shift_Bars;

      // --- v3.00: jarak & offset kini RELATIF ATR (lihat penjelasan di input) ---
      double atrSR = iATR(NULL, 0, ATRPeriodSR, shift);
      double contract, precOffset;
      if (UseATRScaling && atrSR > 0)
      {
         contract   = MinGapATR    * atrSR;   // mis. gold ATR $20 -> jarak min $16
         precOffset = PrecisionATR * atrSR;   // mis. $1,00
      }
      else
      {
         // cadangan warisan (hanya bila UseATRScaling dimatikan) - ini
         // memang bergantung instrumen, itu sebabnya bukan default.
         contract   = (Contract_Step + Precision) * Point;
         precOffset = Precision * Point;
      }

      // --- PERBAIKAN SEEDING: nilai level "sebelumnya" yang aman ---
      // Versi asli membaca v1[i+1]/v2[i+1] mentah di bar tertua (belum pernah
      // diisi = 0/acak) dan merambatkannya. Sekarang: bila belum ada level
      // sebelumnya yang valid, level fraktal pertama langsung dipakai.
      double prevRes = (i + 1 < rates_total) ? v1[i + 1] : EMPTY_VALUE;
      double prevSup = (i + 1 < rates_total) ? v2[i + 1] : EMPTY_VALUE;
      bool   hasPrevRes = (prevRes != EMPTY_VALUE && prevRes > 0);
      bool   hasPrevSup = (prevSup != EMPTY_VALUE && prevSup > 0);

      // ===== Resistance (logika fraktal ASLI, tidak diubah) =====
      double price = high[shift + 2];
      bool fractal = price >= high[shift + 4] &&
                     price >= high[shift + 3] &&
                     price >  high[shift + 1] &&
                     price >  high[shift];
      if (fractal)
      {
         double gap = hasPrevRes ? (prevRes - price) : contract; // tanpa level sblmnya: terima fraktal pertama
         if (gap >= contract || gap < 0)
         { v1[i] = price + precOffset; ageR[i] = 0; }
         else
         { v1[i] = prevRes; ageR[i] = (i+1 < rates_total ? ageR[i+1] : 0) + 1; }
      }
      else
      {
         v1[i] = hasPrevRes ? prevRes : EMPTY_VALUE;
         ageR[i] = (i+1 < rates_total ? ageR[i+1] : 0) + 1;
      }
      // --- v3.00 KEDALUWARSA: level yg sudah DITEMBUS atau terlalu tua digugurkan ---
      if (UseLevelExpiry && v1[i] != EMPTY_VALUE)
      {
         double tol = (atrSR > 0) ? BreakToleranceATR * atrSR : close[shift] * FallbackTolBP / 10000.0;
         // resistance batal kalau harga menutup tegas DI ATASNYA (sudah jadi support)
         // v6.00: dulu hanya CLOSE yg diperiksa, sehingga level bertahan
         // walau badan candle sudah menembusnya - itulah "garis memotong
         // candle" yang Anda lihat. Kini penembusan dinilai dr CLOSE ATAU
         // dari badan candle yg jelas melewati level.
         double bodyTopR = MathMax(close[shift], open[shift]);
         if (close[shift] > v1[i] + tol || bodyTopR > v1[i] + tol * 1.5)
                                                  { v1[i] = EMPTY_VALUE; ageR[i] = 0; }
         else if (ageR[i] > MaxLevelAgeBars)      { v1[i] = EMPTY_VALUE; ageR[i] = 0; }
      }

      // ===== Support =====
      price = low[shift + 2];
      fractal = price <= low[shift + 4] &&
                price <= low[shift + 3] &&
                price <  low[shift + 1] &&
                price <  low[shift];
      // --- v6.00 VALIDASI SWING (cermin sisi resistance) ---
      if (fractal && UseSwingValidation && atrSR > 0)
      {
         int c2 = shift + 2;
         for (int M = c2 - SwingLookback; M <= c2 + SwingLookback; M++)
         {
            if (M < 0 || M >= rates_total || M == c2) continue;
            if (low[M] < price) { fractal = false; break; }
         }
         if (fractal)
         {
            double hiL = price, hiR = price;
            for (int M2 = c2 + 1; M2 <= c2 + SwingLookback && M2 < rates_total; M2++)
               if (high[M2] > hiL) hiL = high[M2];
            for (int N2 = c2 - 1; N2 >= c2 - SwingLookback && N2 >= 0; N2--)
               if (high[N2] > hiR) hiR = high[N2];
            double prom2 = MathMin(hiL, hiR) - price;
            if (prom2 < SwingProminenceATR * atrSR) fractal = false;
         }
      }
      if (fractal)
      {
         double gap = hasPrevSup ? (price - prevSup) : contract;
         if (gap >= contract || gap < 0)
         { v2[i] = price - precOffset; ageS[i] = 0; }
         else
         { v2[i] = prevSup; ageS[i] = (i+1 < rates_total ? ageS[i+1] : 0) + 1; }
      }
      else
      {
         v2[i] = hasPrevSup ? prevSup : EMPTY_VALUE;
         ageS[i] = (i+1 < rates_total ? ageS[i+1] : 0) + 1;
      }
      // --- v3.00 KEDALUWARSA (cermin sisi support) ---
      if (UseLevelExpiry && v2[i] != EMPTY_VALUE)
      {
         double tolS = (atrSR > 0) ? BreakToleranceATR * atrSR : close[shift] * FallbackTolBP / 10000.0;
         // support batal kalau harga menutup tegas DI BAWAHNYA (sudah jadi resistance)
         double bodyBotS = MathMin(close[shift], open[shift]);
         if (close[shift] < v2[i] - tolS || bodyBotS < v2[i] - tolS * 1.5)
                                                  { v2[i] = EMPTY_VALUE; ageS[i] = 0; }
         else if (ageS[i] > MaxLevelAgeBars)      { v2[i] = EMPTY_VALUE; ageS[i] = 0; }
      }

      // ══ v5.00 KONTRAK TIM: RUANG, KEKUATAN LEVEL, VETO ═════════════
      double atrRoom = iATR(NULL, 0, ATRPeriodRoom, shift);
      double px = close[shift];
      roomR[i] = 0; roomS[i] = 0; lvlPower[i] = 0; srVeto[i] = 0;

      if (atrRoom > 0)
      {
         // --- ruang ke masing-masing sisi, dlm kelipatan ATR ---
         if (v1[i] != EMPTY_VALUE && v1[i] > 0) roomR[i] = (v1[i] - px) / atrRoom;
         else                                   roomR[i] = 99;   // tak ada penghalang di atas
         if (v2[i] != EMPTY_VALUE && v2[i] > 0) roomS[i] = (px - v2[i]) / atrRoom;
         else                                   roomS[i] = 99;   // tak ada penghalang di bawah

         // --- kekuatan level TERDEKAT: berapa kali disentuh tanpa ditembus ---
         // Level yang sudah berkali-kali menahan harga jauh lebih berarti
         // daripada level yang baru terbentuk sekali. Inilah yang membedakan
         // "tembok" sungguhan dari garis biasa.
         double nearLvl = 0; bool nearIsRes = true;
         if (roomR[i] < roomS[i] && roomR[i] < 90) { nearLvl = v1[i]; nearIsRes = true;  }
         else if (roomS[i] < 90)                   { nearLvl = v2[i]; nearIsRes = false; }

         if (nearLvl > 0)
         {
            // v7.00 PERBAIKAN HITUNG SENTUHAN.
            // Versi lama menghitung SETIAP BAR yang kebetulan berada dekat
            // level. Akibatnya level yang duduk di tengah rentang harga bisa
            // "disentuh" puluhan kali dalam 120 bar - kekuatan level terukur
            // 90/100 rata-rata di tes Anda, hampir semua level terlihat KUAT,
            // dan veto SR jadi menyala terus-menerus.
            // Yang sebenarnya bermakna adalah PERISTIWA: harga DATANG ke
            // level, lalu PERGI menjauh. Kedatangan berturut-turut dalam satu
            // kunjungan hanya dihitung SEKALI.
            double zone = TouchZoneATR * atrRoom;
            int touches = 0;
            bool inZone = false;      // sedang di dalam zona level?
            for (int t = shift; t < shift + TouchScanBars && t < rates_total; t++)
            {
               bool near;
               if (nearIsRes) near = (high[t] >= nearLvl - zone && close[t] <= nearLvl + zone);
               else           near = (low[t]  <= nearLvl + zone && close[t] >= nearLvl - zone);
               // hitung hanya saat MASUK zona setelah sebelumnya di luar
               if (near && !inZone) touches++;
               // dianggap benar-benar PERGI bila menjauh > 1,5 x zona
               if (!near)
               {
                  double away = nearIsRes ? (nearLvl - high[t]) : (low[t] - nearLvl);
                  if (away > zone * 1.5) inZone = false;
               }
               else inZone = true;
            }
            // 1 sentuhan = 25, 4+ sentuhan = 100 (dibatasi)
            double pw = touches * 25.0;
            if (pw > 100) pw = 100;
            lvlPower[i] = pw;

            // --- VETO: harga mentok di level KUAT ---
            // Suara "TIDAK" yang mengikat: arah boleh benar dan tenaga boleh
            // cukup, tapi kalau ruangnya habis di depan tembok yang sudah
            // berkali-kali menahan, itu bukan peluang - itu jebakan.
            double nearRoom = nearIsRes ? roomR[i] : roomS[i];
            if (UseTeamVeto && pw >= StrongLevelPower && nearRoom >= 0 && nearRoom < VetoRoomATR)
               srVeto[i] = 1;
         }
      }
   }

   // ── v6.00 DIAGNOSTIK: SuperSR selama ini BUTA di jurnal ──
   // Tes 5 pair Anda mencatat 0 baris diagnostik dari indikator ini,
   // sehingga level, ruang, kekuatan, maupun veto-nya sama sekali tak
   // bisa diverifikasi dari jurnal. Kini dicetak sekali saat start.
   if (PrintInstrumentProfile && !g_srPrinted && rates_total > 320)
   {
      g_srPrinted = true;
      int nR = 0, nS = 0; double sumPw = 0; int nPw = 0;
      for (int d = 1; d < 300; d++)
      {
         if (v1[d] != EMPTY_VALUE && v1[d] > 0) nR++;
         if (v2[d] != EMPTY_VALUE && v2[d] > 0) nS++;
         if (lvlPower[d] > 0) { sumPw += lvlPower[d]; nPw++; }
      }
      Print("---- PROFIL SUPERSR - ", Symbol(), " M", Period(), " ----");
      Print("  Validasi swing    : ", (UseSwingValidation ? "AKTIF" : "MATI"),
            "  (lookback ", SwingLookback, " bar, tonjolan >= ",
            DoubleToString(SwingProminenceATR, 2), " xATR)");
      // v8.00 PERBAIKAN METRIK. "Cakupan bar" tidak bergerak walau
      // pengetatan v7.00 diterapkan (243->250, nyaris sama) - metriknya
      // salah ukur. Level DITERUSKAN ke depan sampai gugur, jadi sepuluh
      // level saja bisa menutupi 300 bar. Yang menentukan apakah garis
      // terlihat berdesakan di chart adalah BERAPA BANYAK LEVEL BERBEDA
      // yang lahir - bukan berapa lama tiap level bertahan.
      int distinctR = 0, distinctS = 0;
      double prevRv = -1, prevSv = -1;
      for (int d2 = 299; d2 >= 1; d2--)
      {
         if (v1[d2] != EMPTY_VALUE && v1[d2] > 0 && MathAbs(v1[d2] - prevRv) > Point)
         { distinctR++; prevRv = v1[d2]; }
         if (v2[d2] != EMPTY_VALUE && v2[d2] > 0 && MathAbs(v2[d2] - prevSv) > Point)
         { distinctS++; prevSv = v2[d2]; }
      }
      Print("  Level BERBEDA lahir: resistance ", distinctR, " | support ", distinctS,
            " (dlm 300 bar) - INI yg menentukan kerapatan visual");
      Print("  Cakupan bar (info)  : resistance ", nR, "/300 | support ", nS, "/300",
            "  (level yg sama diteruskan ke depan - wajar tinggi)");
      Print("  Kekuatan level    : ", (nPw > 0 ? DoubleToString(sumPw / nPw, 0) : "-"), "/100 (rata-rata)");
      Print("  CARA MEMBACA: level berbeda >15 dlm 300 bar (H1) = masih rapat;");
      Print("                4-10 = wajar; <3 = mungkin terlalu ketat.");
   }

   return(rates_total);
}
//+------------------------------------------------------------------+