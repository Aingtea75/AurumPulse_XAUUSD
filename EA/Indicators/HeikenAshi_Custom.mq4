//+------------------------------------------------------------------+
//| HeikenAshi_Custom.mq4                                            |
//| Rekonstruksi indikator Heiken Ashi (rumus standar, publik)        |
//|                                                                    |
//| VERSI 6.00 - ANGGOTA TIM 4 INDIKATOR (FINAL)                       |
//+-------------------------------------------------------------------+
//| PERAN DALAM TIM  : LANTAI 2 - KONFIRMATOR MOMENTUM                 |
//| PERTANYAAN YG DIJAWAB : "Apakah dorongannya NYATA dan SEGAR?"      |
//|                                                                    |
//| === KONTRAK KELUARAN TIM (dibaca Supertrend_Promax & EA) ========= |
//|   buffer  6 : ARAH terkonfirmasi   +1 naik / -1 turun              |
//|   buffer  7 : KEKUATAN momentum    0-100                           |
//|   buffer 12 : UMUR sejak flip      dalam bar (kesegaran)           |
//|   buffer 13 : VETO                 1 = tolak sinyal, 0 = aman      |
//| Empat buffer ini WAJIB ada di setiap anggota tim pada indeks yg    |
//| sama artinya, supaya sidang konsensus bisa memanggil semuanya      |
//| dengan cara yang seragam.                                          |
//|                                                                    |
//| KAPAN INDIKATOR INI MEM-VETO:                                      |
//|   - rentetan candle bertubuh sangat tipis (pasar bimbang/doji)     |
//|   - arah baru saja flip DAN belum melewati masa konfirmasi         |
//| Veto = suara "TIDAK" yang mengikat; sekuat apa pun lantai lain,    |
//| sinyal tetap dibatalkan. Inilah cara satu anggota tim mencegah     |
//| anggota lain terjebak sinyal semu.                                 |
//|                                                                    |
//| PERAN DALAM KOLABORASI 4 INDIKATOR:                                |
//| KONFIRMATOR ARAH TREND. Indikator ini tidak menghasilkan panah     |
//| sinyal sendiri - tugasnya memberi tahu EA arah trend yang sudah    |
//| bersih dari zigzag (buffer 6), utk MENGUATKAN/MEMVETO sinyal dari  |
//| Entry_Signal_Pro & Supertrend_Promax: sinyal BUY hanya valid bila  |
//| HA Direction = 1 (hijau), SELL hanya bila = -1 (merah).            |
//|                                                                    |
//| 3 LAPIS ANTI-ZIGZAG (semua bisa diatur/dimatikan lewat input):     |
//|   1. Smoothed HA: O/H/L/C dihaluskan EMA(SmoothPeriod=6) sebelum   |
//|      rumus HA - koreksi dangkal multi-candle terserap              |
//|   2. Konfirmasi jumlah: arah baru wajib bertahan MinFlipBars=3     |
//|      candle berturut-turut sebelum warna/arah berganti             |
//|   3. Filter tubuh: candle konfirmasi wajib bertubuh >= 30% ATR(14) |
//|      - candle kecil/doji tidak dihitung                            |
//|                                                                    |
//| SINKRONISASI PARAMETER dgn indikator final lain:                   |
//|   BodyATRPeriod=14  (= ADXPeriod/RSIPeriod di Entry_Signal_Pro &   |
//|                        Supertrend_Promax)                          |
//|   SmoothPeriod=6, MinFlipBars=3 (keluarga konfirmasi '6/3' yg sama |
//|                        dgn ExhaustLookback=6 & ExhaustMinGapBars=6)|
//|                                                                    |
//| PETA BUFFER utk pemanggilan iCustom() dari EA:                    |
//|   0,1 = pasangan render wick (internal, saling bertukar)          |
//|   2 = HA OPEN  (smoothed bila SmoothPeriod>1) - HA_OpenBuffer=2   |
//|   3 = HA CLOSE (smoothed bila SmoothPeriod>1) - HA_CloseBuffer=3  |
//|   4,5 = pasangan render body (internal, saling bertukar)          |
//|   6 = HA DIRECTION TERKONFIRMASI: 1=bullish, -1=bearish           |
//|       (REKOMENDASI UTAMA: EA baca buffer ini utk arah HA -        |
//|       dijamin identik dgn warna chart, sudah 3-lapis anti-zigzag) |
//+------------------------------------------------------------------+
#property copyright "Custom rebuild - standard Heiken Ashi formula"
#property strict
#property indicator_chart_window
#property indicator_buffers 7

input color ColorUp        = clrWhiteSmoke;   // Warna candle naik (bullish)
input color ColorDown      = clrRed;    // Warna candle turun (bearish)
input int   BodyWidth      = 2;         // Ketebalan body candle (1-4; kecilkan bila terasa tebal)
input int   WickWidth      = 1;         // Ketebalan wick/sumbu candle
input bool  DrawCandles    = true;      // Gambar candle Heiken Ashi di chart

// === FILTER WARNA ANTI-ZIGZAG (BARU) ===
// HA standar berganti warna di SETIAP candle kontra kecil - berbahaya utk
// entri manual. Dengan filter ini, warna hanya berganti bila arah baru
// terkonfirmasi MinFlipBars candle BERTURUT-TURUT. Koreksi 1 candle di
// tengah trend tidak akan membalik warna.
input bool  UseConfirmedColor = true;   // Aktifkan filter konfirmasi warna
input int   MinFlipBars       = 3;      // Brp candle berturut-turut arah baru sblm warna ganti (dinaikkan ke 3)

// Candle koreksi/zigzag biasanya BERTUBUH KECIL (pergerakan lemah), sedangkan
// pembalikan trend asli bertubuh besar. Syarat ini membuat candle kecil/doji
// TIDAK DIHITUNG untuk pergantian warna - hanya candle bertubuh signifikan.
input bool   UseBodySizeFilter = true;  // Wajibkan candle konfirmasi bertubuh signifikan
input double MinBodyATRFactor  = 0.30;  // Tubuh minimal, relatif pembanding (lihat catatan v3.00)
input int    BodyATRPeriod     = 14;    // Periode ATR pembanding ukuran tubuh
// ══════════════════════════════════════════════════════════════════════
// === v3.00 PERBAIKAN KETIDAKCOCOKAN SKALA PEMBANDING TUBUH ===========
// ══════════════════════════════════════════════════════════════════════
// BUG NYATA di v2.20: tubuh candle HA yg SUDAH DIHALUSKAN dibandingkan
// dengan ATR HARGA MENTAH. Dua besaran ini beda skala jauh - EMA(6) pada
// O/H/L/C menekan rentang harga, sehingga tubuh HA hasil smoothing lazimnya
// hanya 20-40% dari ATR mentah. Akibatnya syarat "tubuh >= 30% ATR mentah"
// hampir selalu gagal, streak konfirmasi terus putus, dan arah HA nyaris
// tak pernah berganti.
// Itu cocok dgn bukti dari jurnal EA: "Ditolak - Heiken Ashi tidak flip"
// cuma 16-63 kali dlm ribuan bar - HA praktis tak menyaring apa pun, ia
// hanya ikut arah yg sudah lama berjalan. LANTAI 2 arsitektur ini
// sesungguhnya tidak bekerja.
// PERBAIKAN: pembanding kini tubuh HA RATA-RATA belakangan (skala yg sama),
// bukan ATR harga mentah. Ambang jadi bermakna: "candle konfirmasi harus
// lebih berisi dari kebiasaan candle HA belakangan".
input bool   UseHABodyReference = true; // AKTIF = bandingkan thd rata2 tubuh HA (skala benar)
input int    HABodyRefBars      = 20;   // brp bar utk menghitung rata2 tubuh HA
// === v3.00 KELUARAN KEKUATAN MOMENTUM (buffer 7) ======================
// HA lama hanya menjawab "arah apa". Buffer baru ini menjawab "seberapa
// bertenaga" - berguna utk EA membedakan dorongan sungguhan dari rembesan
// lemah, dan sinkron dgn Skor Kualitas Tren di Supertrend_Promax v4.00.
//   nilai 0..100 : rata2 tubuh HA belakangan relatif ATR, dinormalisasi
input bool   UseMomentumStrength = true;
// === v6.00 KONTRAK TIM: hak VETO ======================================
// Anggota tim ini berhak membatalkan sinyal apa pun bila melihat dua
// keadaan yang jelas berbahaya:
//  1. Pasar sedang BIMBANG - rentetan candle bertubuh sangat tipis.
//     Arah boleh terlihat rapi, tapi tanpa tubuh berarti tak ada tenaga.
//  2. Arah BARU SAJA berbalik dan belum teruji beberapa bar.
//     Flip yang masih bayi paling sering jadi sinyal semu.
input bool   UseTeamVeto        = true;  // aktifkan hak veto
input double VetoBodyRatio      = 0.45;  // tubuh rata2 < ini x acuan = pasar bimbang
input int    VetoFreshFlipBars  = 2;     // arah baru flip < ini bar = belum teruji
input bool   VetoOnFreshFlip    = false; // v9.00: DIMATIKAN - dulu memblokir momen konfluensi terbaik
// === v6.00: kalibrasi tak perlu menunggu 600 bar ======================
// Pelajaran dari tes Supertrend Anda: syarat 600 bar penuh membuat
// kalibrasi tertunda 5-7 minggu ke dalam backtest, sehingga bagian awal
// tes berjalan dgn setelan yang salah. Kini pakai data seadanya.
input int    MinCalibBars       = 250;   // bar MINIMUM utk mulai kalibrasi
// ══════════════════════════════════════════════════════════════════════
// === v4.00 ADAPTASI OTOMATIS MULTI-PAIR ===============================
// ══════════════════════════════════════════════════════════════════════
// MinFlipBars=3 mengatur berapa lama arah baru harus bertahan sebelum
// diakui. Angka yg pas sangat bergantung KARAKTER DERAU pasar:
//   - EURUSD/GBPUSD: banyak candle kontra kecil -> butuh konfirmasi lebih
//   - crypto/emas trending: dorongan panjang & bersih -> 3 bar terlalu
//     lambat, pembalikan sungguhan jadi terlewat berjam-jam
// Nilai tetap pasti salah di salah satu sisi. v4.00 MENGUKUR seberapa
// sering arah HA mentah berbalik pd pasar ini, lalu menyetel sendiri.
// Diukur sekali di bar tertutup, lalu DIKUNCI - tidak repaint.
input bool   AutoAdaptToInstrument = true;  // ukur derau pasar & setel MinFlipBars sendiri
input int    AutoCalibBars         = 600;   // brp bar riwayat utk mengukur
// v6.00 KALIBRASI ULANG BERBASIS PENGUKURAN NYATA.
// Nilai v5.00 (8.0) adalah TEBAKAN saya, dan MELESET 3x. Hasil tes Anda:
//     GBPUSD 26,7 pergantian per 100 bar | XAUUSD 26,0 per 100 bar
// Dengan target 8.0, rasionya jadi 3,3x -> MinFlipBars 3 x 3,3 = 10 ->
// DIPOTONG ke batas atas 6. KEDUA pair mentok di 6, sehingga adaptasinya
// menghasilkan NOL PEMBEDA - persis kebalikan dari tujuannya.
// Target kini disetel ke ~26 (rerata terukur), sehingga pasar berkarakter
// normal mendarat di MinFlipBars 3 (nilai wajar), dan hanya pasar yg
// benar-benar lebih bergerigi atau lebih mulus yg bergeser.
// CATATAN JUJUR: 26.0 berasal dari DUA pengamatan saja (GBPUSD & XAUUSD,
// H1, Jan-Feb 2025). Perlu ditinjau ulang setelah ada data dari crypto,
// indeks, atau timeframe lain - laju ini bisa berbeda di M15 atau H4.
input double TargetFlipsPer100Bars = 26.0;  // target kepadatan pergantian arah HA mentah
input int    AutoFlipBarsMin       = 2;     // batas bawah hasil auto
input int    AutoFlipBarsMax       = 6;     // batas atas hasil auto
input bool   PrintInstrumentProfile = true; // cetak hasil pengukuran ke jurnal

// === SMOOTHED HEIKEN ASHI (senjata utama anti-zigzag) ===
// Harga O/H/L/C dihaluskan EMA dulu SEBELUM masuk rumus HA (teknik klasik
// "Smoothed Heiken Ashi"). Koreksi dangkal beberapa candle terserap oleh
// penghalusan - tidak pernah sampai membalik arah/warna candle.
input int    SmoothPeriod      = 6;     // Periode EMA penghalus (1 = tanpa smoothing / HA standar)

//--- buffer:
//--- 0,1 = pasangan wick (render);  2,3 = HA Open/Close MURNI (data EA);
//--- 4,5 = pasangan body (render);  6 = arah TERKONFIRMASI (data EA)
//--- CATATAN PENTING: histogram MT4 di chart utama digambar berpasangan
//--- KAKU (0,1),(2,3),(4,5),(6,7) - pasangan render WAJIB di posisi itu.
double haWickA[];   // buffer 0 (render wick)
double haWickB[];   // buffer 1 (render wick)
double haOpen[];    // buffer 2  <- dibaca EA (murni, tak tersentuh filter)
double haClose[];   // buffer 3  <- dibaca EA (murni, tak tersentuh filter)
double haBodyA[];   // buffer 4 (render body)
double haBodyB[];   // buffer 5 (render body)
double haDir[];     // buffer 6  <- arah TERKONFIRMASI: 1 / -1 (dibaca EA)
double haStrength[];// buffer 7  <- KEKUATAN MOMENTUM 0-100 (kontrak tim)
double haAge[];     // buffer 12 <- UMUR sejak flip, dalam bar (kontrak tim)
double haVeto[];    // buffer 13 <- VETO 1/0 (kontrak tim)
//--- buffer kalkulasi EMA penghalus (8-11, tidak digambar)
double emaO[], emaH[], emaL[], emaC[];

string PFX = "HAC_"; // utk bersih-bersih objek sisa versi lama
//--- v4.00: hasil pengukuran karakter instrumen (dikunci setelah dihitung)
bool g_haCalibrated = false;
int  g_effMinFlipBars = 0;

int OnInit()
{
   SetIndexBuffer(0, haWickA);
   SetIndexBuffer(1, haWickB);
   SetIndexBuffer(2, haOpen);
   SetIndexBuffer(3, haClose);
   SetIndexBuffer(4, haBodyA);
   SetIndexBuffer(5, haBodyB);
   SetIndexBuffer(6, haDir);

   // buffer kalkulasi tambahan (EMA penghalus) - dikelola otomatis MT4,
   // aman dari masalah resize array manual
   IndicatorBuffers(14);
   SetIndexBuffer(7, haStrength);   // v3.00: kekuatan momentum (dibaca EA)
   SetIndexStyle(7, DRAW_NONE);
   SetIndexLabel(7, "HA Momentum Strength (0-100)");
   ArraySetAsSeries(haStrength, true);
   // --- v6.00 kontrak tim ---
   SetIndexBuffer(12, haAge);   SetIndexStyle(12, DRAW_NONE); SetIndexLabel(12, "HA Umur Flip (bar)");
   SetIndexBuffer(13, haVeto);  SetIndexStyle(13, DRAW_NONE); SetIndexLabel(13, "HA Veto (1/0)");
   ArraySetAsSeries(haAge,  true);
   ArraySetAsSeries(haVeto, true);
   SetIndexBuffer(8,  emaO);
   SetIndexBuffer(9,  emaH);
   SetIndexBuffer(10, emaL);
   SetIndexBuffer(11, emaC);
   ArraySetAsSeries(emaO, true);
   ArraySetAsSeries(emaH, true);
   ArraySetAsSeries(emaL, true);
   ArraySetAsSeries(emaC, true);

   if (DrawCandles)
   {
      // Histogram MT4 chart utama digambar berpasangan KAKU: (0,1),(2,3),(4,5).
      // - pasangan (0,1) = rentang High-Low (wick), tipis
      // - pasangan (4,5) = rentang Open-Close (body), lebih tebal
      // - warna segmen mengikuti buffer yang nilainya lebih tinggi,
      //   makanya isi pasangan buffer saling ditukar sesuai arah TERKONFIRMASI.
      // Pasangan (2,3) = data murni utk EA, sengaja TIDAK digambar.
      SetIndexStyle(0, DRAW_HISTOGRAM, STYLE_SOLID, WickWidth, ColorDown);
      SetIndexStyle(1, DRAW_HISTOGRAM, STYLE_SOLID, WickWidth, ColorUp);
      SetIndexStyle(4, DRAW_HISTOGRAM, STYLE_SOLID, BodyWidth, ColorDown);
      SetIndexStyle(5, DRAW_HISTOGRAM, STYLE_SOLID, BodyWidth, ColorUp);
   }
   else
   {
      SetIndexStyle(0, DRAW_NONE);
      SetIndexStyle(1, DRAW_NONE);
      SetIndexStyle(4, DRAW_NONE);
      SetIndexStyle(5, DRAW_NONE);
   }
   SetIndexStyle(2, DRAW_NONE);
   SetIndexStyle(3, DRAW_NONE);
   SetIndexStyle(6, DRAW_NONE);

   SetIndexLabel(0, "HA Wick A");
   SetIndexLabel(1, "HA Wick B");
   SetIndexLabel(2, "HA Open");
   SetIndexLabel(3, "HA Close");
   SetIndexLabel(4, "HA Body A");
   SetIndexLabel(5, "HA Body B");
   SetIndexLabel(6, "HA Direction (confirmed)");

   ArraySetAsSeries(haWickA, true);
   ArraySetAsSeries(haWickB, true);
   ArraySetAsSeries(haOpen, true);
   ArraySetAsSeries(haClose, true);
   ArraySetAsSeries(haBodyA, true);
   ArraySetAsSeries(haBodyB, true);
   ArraySetAsSeries(haDir, true);

   if (BodyWidth < 1 || WickWidth < 1 || MinFlipBars < 1 || BodyATRPeriod < 1 || SmoothPeriod < 1)
   {
      Print("HeikenAshi_Custom: ERROR - BodyWidth, WickWidth, MinFlipBars, BodyATRPeriod & SmoothPeriod harus >= 1.");
      return(INIT_PARAMETERS_INCORRECT);
   }

   IndicatorShortName("Heiken Ashi Custom");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   // bersih-bersih objek sisa dari versi lama (yg pakai chart object)
   ObjectsDeleteAll(0, PFX);
}

//+------------------------------------------------------------------+
//| v4.00 KALIBRASI KE KARAKTER DERAU PASAR                           |
//| Menghitung berapa sering ARAH MENTAH candle HA berbalik pd 600 bar |
//| tertutup terakhir, lalu menyetel MinFlipBars: pasar bergerigi dpt  |
//| konfirmasi lebih panjang, pasar mulus dpt konfirmasi lebih pendek. |
//| Hasilnya DIKUNCI - tidak repaint, backtest reproducible.           |
//+------------------------------------------------------------------+
void CalibrateHAToInstrument(int rates_total)
{
   int avail = rates_total - 20;
   if (avail < MinCalibBars) return;               // benar-benar belum cukup
   int scan = AutoCalibBars;
   if (scan > avail) scan = avail;                 // pakai seadanya, jangan menunggu

   // arah mentah HA sederhana (tanpa smoothing) utk mengukur derau dasar
   int flips = 0, prevD = 0;
   double pho = 0, phc = 0; bool first = true;
   for (int i = scan; i >= 1; i--)
   {
      double hc = (Open[i] + High[i] + Low[i] + Close[i]) / 4.0;
      double ho = first ? (Open[i] + Close[i]) / 2.0 : (pho + phc) / 2.0;
      first = false;
      int d = (hc >= ho) ? 1 : -1;
      if (prevD != 0 && d != prevD) flips++;
      prevD = d; pho = ho; phc = hc;
   }
   double per100 = (double)flips / scan * 100.0;

   // Pasar lebih bergerigi (per100 tinggi) butuh konfirmasi lebih panjang.
   double ratio = (TargetFlipsPer100Bars > 0) ? per100 / TargetFlipsPer100Bars : 1.0;
   int mfb = (int)MathRound(MinFlipBars * ratio);
   if (mfb < AutoFlipBarsMin) mfb = AutoFlipBarsMin;
   if (mfb > AutoFlipBarsMax) mfb = AutoFlipBarsMax;
   g_effMinFlipBars = mfb;
   g_haCalibrated = true;

   if (PrintInstrumentProfile)
   {
      Print("════ PROFIL DERAU HEIKEN ASHI - ", Symbol(), " M", Period(), " ════");
      Print("  Pergantian arah HA mentah : ", DoubleToString(per100,1), " per 100 bar (target ",
            DoubleToString(TargetFlipsPer100Bars,1), ")");
      Print("  MinFlipBars               : ", MinFlipBars, " (input) -> ", g_effMinFlipBars, " (hasil ukur)");
      Print("  CATATAN: dikunci utk sesi ini - tidak repaint.");
   }
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
   // --- v4.00: ukur derau pasar sekali, lalu kunci ---
   // WAJIB dijalankan SEBELUM 'limit' dihitung, karena hasil kalibrasi
   // menentukan apakah perlu hitung ulang penuh.
   bool haWasCal = g_haCalibrated;
   if (!g_haCalibrated && AutoAdaptToInstrument) CalibrateHAToInstrument(rates_total);
   int effFlipBars = (g_haCalibrated && AutoAdaptToInstrument) ? g_effMinFlipBars : MinFlipBars;
   // Begitu kalibrasi selesai, hitung ulang penuh SEKALI supaya arah
   // terkonfirmasi tidak jadi campuran dua setelan yang berbeda.
   int prev_calc_ha = (!haWasCal && g_haCalibrated) ? 0 : prev_calculated;

   int limit = rates_total - prev_calc_ha;
   if (limit > rates_total - 1) limit = rates_total - 1;
   if (limit < 1) limit = 1;

   // --- Rumus Heiken Ashi standar (TIDAK BERUBAH dari versi sebelumnya) ---
   // HA_Close = (O+H+L+C)/4
   // HA_Open  = (HA_Open sebelumnya + HA_Close sebelumnya) / 2   (bar pertama = (O+C)/2)
   // HA_High  = MAX(High asli, HA_Open, HA_Close)
   // HA_Low   = MIN(Low asli, HA_Open, HA_Close)
   double emaK = 2.0 / (MathMax(1, SmoothPeriod) + 1.0); // koefisien EMA

   for (int i = limit; i >= 0; i--)
   {
      // --- LANGKAH 1: haluskan O/H/L/C dgn EMA (Smoothed Heiken Ashi) ---
      double o, h, l, c;
      if (SmoothPeriod <= 1)
      {
         o = open[i]; h = high[i]; l = low[i]; c = close[i];
         emaO[i] = o; emaH[i] = h; emaL[i] = l; emaC[i] = c;
      }
      else if (i == rates_total - 1)
      {
         // seed di bar tertua
         emaO[i] = open[i]; emaH[i] = high[i]; emaL[i] = low[i]; emaC[i] = close[i];
         o = emaO[i]; h = emaH[i]; l = emaL[i]; c = emaC[i];
      }
      else
      {
         emaO[i] = open[i]  * emaK + emaO[i + 1] * (1.0 - emaK);
         emaH[i] = high[i]  * emaK + emaH[i + 1] * (1.0 - emaK);
         emaL[i] = low[i]   * emaK + emaL[i + 1] * (1.0 - emaK);
         emaC[i] = close[i] * emaK + emaC[i + 1] * (1.0 - emaK);
         o = emaO[i]; h = emaH[i]; l = emaL[i]; c = emaC[i];
      }

      // --- LANGKAH 2: rumus Heiken Ashi standar (di atas data yg sudah halus) ---
      double hc = (o + h + l + c) / 4.0;
      double ho;
      if (i == rates_total - 1)
         ho = (o + c) / 2.0;
      else
         ho = (haOpen[i + 1] + haClose[i + 1]) / 2.0;

      double hh = MathMax(h, MathMax(ho, hc));
      double hl = MathMin(l, MathMin(ho, hc));

      haOpen[i]  = ho;   // data MURNI utk EA - tidak tersentuh filter warna
      haClose[i] = hc;   // data MURNI utk EA

      // --- Arah mentah candle ini ---
      int rawDir = (hc >= ho) ? 1 : -1;

      // --- Arah TERKONFIRMASI (filter anti-zigzag) ---
      // Warna hanya berganti bila arah baru bertahan MinFlipBars candle
      // berturut-turut. Koreksi singkat tidak membalik warna.
      int confDir;
      if (!UseConfirmedColor || i >= rates_total - 2)
      {
         confDir = rawDir; // tanpa filter, atau bar tertua (belum ada riwayat)
      }
      else
      {
         int prevConf = (int)haDir[i + 1];
         if (rawDir == prevConf)
            confDir = prevConf; // searah, tidak ada perubahan
         else
         {
            // arah mentah berlawanan: cek apakah sudah MinFlipBars berturut-turut
            // DAN (bila filter tubuh aktif) tiap candle konfirmasi bertubuh signifikan
            int streak = 0;
            for (int k = i; k < i + effFlipBars && k < rates_total - 1; k++)
            {
               int rawAtK = (haClose[k] >= haOpen[k]) ? 1 : -1;
               if (rawAtK != rawDir) break;
               if (UseBodySizeFilter)
               {
                  double bodyK = MathAbs(haClose[k] - haOpen[k]);
                  double refK;
                  if (UseHABodyReference)
                  {
                     // v3.00: pembanding SKALA-SAMA - rata2 tubuh HA belakangan
                     double sum = 0; int cnt = 0;
                     for (int m = k + 1; m <= k + HABodyRefBars && m < rates_total; m++)
                     { sum += MathAbs(haClose[m] - haOpen[m]); cnt++; }
                     refK = (cnt > 0) ? sum / cnt : 0;
                  }
                  else refK = iATR(NULL, 0, BodyATRPeriod, k);   // perilaku lama
                  if (refK > 0 && bodyK < refK * MinBodyATRFactor) break; // candle lemah: streak putus
               }
               streak++;
            }
            confDir = (streak >= effFlipBars) ? rawDir : prevConf;
         }
      }
      haDir[i] = confDir;

      // --- v3.00 KEKUATAN MOMENTUM (0-100) ---
      // Rata-rata tubuh HA belakangan dibagi ATR harga, dinormalisasi.
      // Menjawab "seberapa bertenaga dorongan ini", bukan sekadar arahnya.
      if (UseMomentumStrength)
      {
         double sumB = 0; int cntB = 0;
         for (int m = i; m < i + HABodyRefBars && m < rates_total; m++)
         { sumB += MathAbs(haClose[m] - haOpen[m]); cntB++; }
         double avgB = (cntB > 0) ? sumB / cntB : 0;
         double atrRef = iATR(NULL, 0, BodyATRPeriod, i);
         double st = (atrRef > 0) ? (avgB / atrRef) / 0.5 * 100.0 : 0;
         if (st < 0) st = 0; if (st > 100) st = 100;
         haStrength[i] = st;
      }
      else haStrength[i] = 0;

      // ── v6.00 KONTRAK TIM: umur flip & veto ────────────────────────
      // UMUR: berapa bar sejak arah terkonfirmasi berubah. Flip segar
      // punya makna berbeda dari tren yang sudah lama berjalan - lantai
      // lain memakai angka ini untuk menilai kesegaran momentum.
      if (i + 1 < rates_total && haDir[i + 1] != EMPTY_VALUE && haDir[i] == haDir[i + 1])
         haAge[i] = haAge[i + 1] + 1;
      else
         haAge[i] = 0;

      // VETO: suara "TIDAK" yang mengikat bagi seluruh tim.
      double vt = 0;
      if (UseTeamVeto)
      {
         // (a) pasar BIMBANG - tubuh candle terlalu tipis dibanding kebiasaan
         double sumV = 0; int cntV = 0;
         for (int q = i; q < i + HABodyRefBars && q < rates_total; q++)
         { sumV += MathAbs(haClose[q] - haOpen[q]); cntV++; }
         double avgV = (cntV > 0) ? sumV / cntV : 0;
         double refV = 0; int cntR = 0; double sumR = 0;
         for (int q2 = i; q2 < i + HABodyRefBars * 3 && q2 < rates_total; q2++)
         { sumR += MathAbs(haClose[q2] - haOpen[q2]); cntR++; }
         refV = (cntR > 0) ? sumR / cntR : 0;
         if (refV > 0 && avgV < refV * VetoBodyRatio) vt = 1;

         // ══ v9.00 VETO FLIP-SEGAR DIHAPUS ══════════════════════════
         // BUKTI dari tes Anda (image 1): "VETO: HA" muncul justru di
         // momen yang paling ingin ditangkap. Sebabnya veto ini menyala
         // ketika arah HA BARU SAJA berganti (<2 bar).
         //
         // Tapi di momen konfluensi yang jadi inti strategi - panah ESP
         // bertemu flip garis Supertrend - HeikenAshi memang SEDANG
         // berganti arah juga. Itu bagian dari sinyalnya, bukan cacatnya.
         // Jadi veto ini memblokir persis peluang terbaik yang kita cari.
         //
         // Peran HA yang benar sbg wakil komandan-2 adalah menjawab
         // "apakah momentum SEARAH dan bertenaga?" - dan itu sudah
         // dijawab lewat buffer arah (6) & kekuatan (7) yang masuk
         // sebagai BOBOT di Lantai-2 sidang konsensus. Menghukum flip
         // segar adalah tugas yang bertentangan dgn peran itu.
         // Veto tubuh-tipis (a) DIPERTAHANKAN - pasar bimbang tetap
         // bahaya nyata, dan itu tak ada kaitannya dgn kesegaran flip.
         if (VetoFreshFlipBars > 0 && haAge[i] < VetoFreshFlipBars &&
             VetoOnFreshFlip) vt = 1;
      }
      haVeto[i] = vt;

      // --- Render: pasangan wick (0,1) & body (5,6), warna ikut arah TERKONFIRMASI ---
      // (warna segmen histogram = warna buffer yg nilainya lebih tinggi)
      double bodyTop = MathMax(ho, hc);
      double bodyBot = MathMin(ho, hc);
      if (confDir == 1)
      {
         haWickA[i] = hl;      haWickB[i] = hh;      // buffer1 lebih tinggi -> ColorUp
         haBodyA[i] = bodyBot; haBodyB[i] = bodyTop; // buffer6 lebih tinggi -> ColorUp
      }
      else
      {
         haWickA[i] = hh;      haWickB[i] = hl;      // buffer0 lebih tinggi -> ColorDown
         haBodyA[i] = bodyTop; haBodyB[i] = bodyBot; // buffer5 lebih tinggi -> ColorDown
      }
   }

   return(rates_total);
}