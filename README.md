# bnt-seine-runner

Skrip untuk menjalankan [Seine](https://github.com/zpalmtree/seine) — miner
Blocknet (BNT), Argon2id, 1 CPU worker, mode HugePages strict — dari nol
sampai terverifikasi jalan dan diterima pool.

## Pool yang dipakai sekarang

**Pool utama: kc.txedu.social (Blocknet 矿池 · NTMminer Pools)**
https://kc.txedu.social/#/

- Endpoint untuk Seine (plaintext): `stratum+tcp://103.54.127.250:3333`
- Endpoint terenkripsi (hanya untuk NTMminer-BNT, **bukan** Seine, karena
  Seine tidak mendukung stratum+ssl): `stratum+ssl://103.54.127.250:3443`
- Fee pool 0% (hanya dipotong ongkos transfer on-chain), payout otomatis
  tiap 3 jam, minimum 0,1 BNT, 60 konfirmasi, PPLNS 6 jam.
- Seine sendiri membawa dev fee (di pool ini 2,5% menurut FAQ pool).
- Status pool saat terakhir dicek (25 Okt 2026): online, node synced,
  50 miner online, pangsa sekitar 57% network.

**Pool lama (cadangan): bntpool.com**
`stratum+tcp://bntpool.com:3333`, fee pool 2,5%, PPLNS 6 jam, minimum
payout 0,1 BNT. Pool ini masih hidup, tapi ada catatan penting: dari
sebagian jalur ArkClaw, koneksi stratum langsung ke bntpool.com
**ditutup ~0,22 detik setelah connect** (bare RST/EOF, tanpa pesan
error, bahkan untuk koneksi idle tanpa data) sehingga miner tidak
pernah login. Kalau itu terjadi, solusinya bukan ganti alamat atau
worker — solusinya pindah pool (kc di atas) atau pakai relay (lihat
bagian Relay di bawah). Jangan buang waktu mengulang install kalau
gejalanya persis itu.

## Isi repo

- `run-seine.sh` — download + verifikasi SHA-256 + install + jalan.
  Dipakai kalau binary `./seine` belum ada di mesin.
- `bakekok.sh` — hanya menyiapkan HugePages lalu menjalankan binary
  `./seine` yang **sudah ada**. Skrip ini tidak men-download apa pun.
- `seine/` — tarball Seine resmi yang di-vendor (dipakai
  `run-seine.sh` lewat `raw.githubusercontent.com`, karena `github.com`
  diblokir dari sebagian VPS sementara raw-nya bisa diakses).

**ADDRESS sudah diisi** di kedua skrip dengan alamat wallet BNT
produksi:
`PLMGsifmTC9Zn5pHqcMkbayvzSG3SBX6vAwJts3KQCwfGRsznpv2qdyCFyRpnh46TwcQu8mLEu1CVdHdQzsx7Ty637GQc`

Jadi tinggal download dan jalan — tidak perlu edit apa-apa lagi.
**Kalau skrip ini dipakai orang lain, ganti dulu `ADDRESS` di skrip
dengan alamat walletnya sendiri, kalau tidak hasil miningnya masuk
ke alamat di atas.** Jangan ganti `ADDRESS` kalau kamu memang mau
mining ke wallet produksi ini.

Catatan penting: miner yang sudah jalan memakai **salinan lokal**
skrip di mesinnya. Update repo ini tidak mengubah miner yang sedang
jalan. Untuk memindahkan miner yang sedang jalan ke pool baru, edit
`POOL_URL` di salinan lokalnya lalu restart minernya (lihat
"Memindahkan miner yang sudah jalan ke pool baru" di bawah).

## Syarat

- Linux x86_64, akses root (atau sudo)
- `curl` atau `wget`, plus `tar sha256sum awk grep`
- RAM bebas ±2 GB untuk 1 worker (1024 HugePages × 2 MB)
- Seine v0.2.21 (versi yang dipakai dan terverifikasi di tutorial ini)

## Mulai cepat (copy-paste, dari nol)

Semua perintah di bawah dijalankan sebagai root, berurutan. Jangan
loncati baris download tarball — `bakekok.sh` tidak men-download
binary, jadi tanpa langkah ini miner tidak akan jalan.

```bash
mkdir -p /root/bnt-seine-runner
cd /root/bnt-seine-runner
curl -L https://github.com/zpalmtree/seine/releases/download/v0.2.21/seine-linux-x86_64.tar.gz -o seine.tar.gz
tar -xzf seine.tar.gz
chmod +x ./seine
./seine --version
curl -fsSL https://raw.githubusercontent.com/agenticspring/bnt-seine-runner/main/bakekok.sh -o bakekok.sh
chmod +x bakekok.sh
bash -n bakekok.sh
ls -lh
nohup ./bakekok.sh > bakekok.log 2>&1 &
disown
sleep 15
tail -n 50 bakekok.log
```

Harus muncul `seine v0.2.21`, lalu `bash -n` lolos tanpa error, lalu
log menunjukkan `login accepted` + share `accepted`. Kalau salah
satu tidak muncul, jangan lanjut — lihat bagian troubleshooting
yang sesuai. Penjelasan tiap langkah ada di "Tutorial dari awal"
di bawah.

## Tutorial dari awal

### Langkah 0 — masuk ke terminal

- **VPS biasa:** SSH sebagai root.
- **BohrClaw / ArkClaw:** login Bohrium → daftar Claw → buka Claw →
  terminal. Jalurnya bisa dua macam, tergantung tampilan:
  kartu Claw di halaman Bohrium → gear "更多配置" → "查看终端",
  **atau** menu pojok kanan atas ArkClaw → "查看终端".
  Kalau ikon gear tidak terlihat di kartu, pakai jalur menu ArkClaw.
  Terminal berjalan sebagai `root@arkclaw`, Ubuntu 24.04.

Pastikan kamu benar-benar root sebelum lanjut:

```bash
whoami
pwd
```

### Langkah 1 — siapkan folder dan binary Seine v0.2.21 (WAJIB)

Langkah ini wajib dan tidak boleh dilewati: file `seine.tar.gz`
**harus** di-download dan diekstrak dulu, karena `bakekok.sh` di
langkah 2 tidak men-download binary apa pun. Tanpa binary ini,
langkah 3 akan gagal.

Penting soal lokasi: download dan ekstrak harus dilakukan di
**folder yang sama dengan `bakekok.sh` nanti**
(`/root/bnt-seine-runner`), bukan di home root polos (`/root/`).
`bakekok.sh` mencari binary di foldernya sendiri (`./seine`) —
kalau binary jatuh di `/root/seine` sementara `bakekok.sh` ada di
`/root/bnt-seine-runner/`, skrip akan gagal dengan
`Cannot find the existing Seine binary`.

```bash
mkdir -p /root/bnt-seine-runner
cd /root/bnt-seine-runner
curl -L https://github.com/zpalmtree/seine/releases/download/v0.2.21/seine-linux-x86_64.tar.gz -o seine.tar.gz
tar -xzf seine.tar.gz
chmod +x ./seine
./seine --version
```

Harus muncul `seine v0.2.21`.

Kalau download macet di tengah (pernah terjadi: macet 0 byte, lalu
timeout di 1,2 MB dari 3,6 MB), lanjutkan dengan resume — jangan
hapus dan mulai dari nol:

```bash
curl -L -C - https://github.com/zpalmtree/seine/releases/download/v0.2.21/seine-linux-x86_64.tar.gz -o seine.tar.gz
```

Kalau `github.com` diblokir total dari mesin itu, download
`seine.tar.gz` di HP/laptop lalu upload via scp/SFTP:

```bash
scp seine.tar.gz root@IP-MESIN:/root/bnt-seine-runner/
```

lalu `tar -xzf` dan `chmod +x` seperti di atas.

### Langkah 2 — download `bakekok.sh` ke folder yang sama

Perintah ini dijalankan dari folder yang sama
(`/root/bnt-seine-runner`), tempat binary `./seine` dari langkah 1
sudah berada. Jangan pindah folder di antara langkah 1 dan 2.

```bash
curl -fsSL https://raw.githubusercontent.com/agenticspring/bnt-seine-runner/main/bakekok.sh -o bakekok.sh
chmod +x bakekok.sh
bash -n bakekok.sh
ls -lh
```

`bash -n` harus lolos tanpa error, dan `ls` harus menunjukkan
`bakekok.sh` berdampingan dengan `./seine`. Kalau file hasil
download punya akhir baris Windows (CRLF), `bash -n` bisa gagal —
bersihkan dulu akhir barisnya sebelum dijalankan.

Jangan loncat ke langkah 3 sebelum `bakekok.sh` benar-benar ada:
kalau file-nya belum ada, `nohup` akan gagal dengan
`No such file or directory` dan miner tidak jalan sama sekali.

### Langkah 3 — jalankan miner di background

Dari folder `/root/bnt-seine-runner`, sebagai root:

```bash
nohup ./bakekok.sh > bakekok.log 2>&1 &
disown
sleep 15
tail -n 50 bakekok.log
```

Skrip akan: menulis setting persisten
`/etc/sysctl.d/99-seine-hugepages.conf`, melakukan memory compaction
+ 3x percobaan alokasi HugePages, lalu menjalankan `./seine` ke pool
`stratum+tcp://103.54.127.250:3333` (1 thread).

### Langkah 4 — verifikasi miner benar-benar jalan

```bash
ps aux | grep -E '[s]eine'
tail -n 50 bakekok.log
grep HugePages /proc/meminfo
```

Yang harus terlihat, urut:

1. Proses `./seine` aktif dengan `--pool-url
   stratum+tcp://103.54.127.250:3333` dan alamat wallet produksi.
2. Log HugePages: `HugePages_Total=1024`, dan `HugePages_Free`
   mendekati 0 setelah miner jalan (artinya 1024 pages dipakai miner,
   bukan gagal).
3. Log koneksi (ini yang tidak pernah terjadi di jalur bntpool yang
   bermasalah): `connected`, lalu `login accepted (protocol v2)`,
   lalu `new job` dengan difficulty awal (di pool kc: 600).
4. Share pertama `accepted` dalam puluhan detik pertama, lalu
   `VARDIFF` menyesuaikan difficulty (misalnya 600 → 900).
5. Baris STATS: `hashes` bertambah, `rate` sekitar 1,7–1,8 H/s untuk
   1 thread di Claw (angka ini tergantung CPU mesin), `submitted`
   dan `accepted` bertambah, `stale` mendekati 0.
6. Tutup lalu buka lagi terminal: proses `./seine` harus masih ada
   (tanda `nohup` + `disown` bekerja).
7. Cek di dashboard pool https://kc.txedu.social/ (cari berdasarkan
   alamat wallet): worker muncul dan share accepted bertambah.
   Payout pool ini tiap 3 jam, minimum 0,1 BNT — jadi share accepted
   di log belum berarti saldo langsung masuk wallet; tunggu siklus
   payout + 60 konfirmasi.

Kalau semua poin 1–5 terpenuhi, miner **sudah jalan dan diterima
pool**. Kalau poin 3 tidak pernah muncul, lihat bagian troubleshooting.

## Cara pertama (alternatif): `run-seine.sh`

Kalau mau satu skrip yang mengurus download + verifikasi + install
+ jalan sekaligus, pakai `run-seine.sh` sebagai ganti langkah 1–2
di atas. Skrip ini men-download tarball dari folder `seine/` repo
ini lewat `raw.githubusercontent.com`, memverifikasi SHA-256
**sebelum** ekstrak (hash tarball yang di-vendor:
`a94248aac209e9a18195adb21ef1dab996a6fe2bde0090bd7eaf65e03c91da77`),
membackup binary lama jadi `./seine.backup.<tanggal-jam>`,
menyiapkan HugePages 1024, lalu menjalankan `./seine` di foreground
ke pool yang sama.

```bash
curl -fsSL https://raw.githubusercontent.com/agenticspring/bnt-seine-runner/main/run-seine.sh -o run-seine.sh
chmod +x run-seine.sh
sudo ./run-seine.sh
```

Skrip jalan di foreground — tekan `Ctrl+C` untuk berhenti. Supaya
tetap jalan setelah terminal ditutup, jalankan lewat `nohup`:

```bash
nohup sudo ./run-seine.sh > seine.log 2>&1 &
disown
```

atau pakai `screen`/`tmux`, atau daftarkan sendiri sebagai service
systemd kalau mau jalan permanen + auto-restart.

Kalau tidak bisa download file mentah sama sekali: buka halaman Raw
skrip di GitHub, copy seluruh isinya, di mesin jalankan
`cat > run-seine.sh`, paste, tekan `Ctrl+D`, pastikan tidak ada
baris terpotong, lalu lanjut. Alternatif lain kalau git tidak
diblokir:

```bash
git clone https://github.com/agenticspring/bnt-seine-runner.git
cd bnt-seine-runner
chmod +x run-seine.sh
sudo ./run-seine.sh
```

## Memindahkan miner yang sudah jalan ke pool baru

Miner yang sedang jalan tidak ikut berubah saat repo di-update.
Untuk memindahkannya (misalnya dari bntpool/relay ke kc, atau
sebaliknya):

```bash
cd /root/bnt-seine-runner
ps aux | grep -E '[s]eine'
kill <PID-miner-lama>
sleep 2
ps aux | grep -E '[s]eine'
cp bakekok.sh bakekok.sh.<nama-pool-lama>
sed -i 's|stratum+tcp://<pool-lama>|stratum+tcp://103.54.127.250:3333|' bakekok.sh
grep POOL_URL bakekok.sh
bash -n bakekok.sh
nohup ./bakekok.sh > bakekok.log 2>&1 &
disown
sleep 15
tail -n 50 bakekok.log
```

Aturan yang selalu berlaku di langkah ini: **hanya `POOL_URL`
yang diubah, `ADDRESS` tidak pernah diubah**, dan file versi lama
selalu dibackup dulu (misalnya `bakekok.sh.direct`,
`bakekok.sh.relay`) supaya revert tinggal restore file backup itu
dan restart. Kalau setelah 120–150 detik tidak ada `login
accepted` + share accepted, revert ke versi backup yang terakhir
terbukti earning, jangan biarkan miner mati.

## Troubleshooting

### HugePages tidak mencapai 1024

Gejala: log berhenti di
`Only N HugeTLB pages are free; Seine needs at least 1024. Not
starting the miner.` — miner tidak ke-start sama sekali.

Yang terbukti bekerja, urut dari yang paling ringan:

1. Bebaskan RAM: tutup aplikasi berat lain di mesin itu, lalu
   jalankan lagi. Alokasi sebelumnya bertahan sehingga angka free
   cenderung naik tiap percobaan (pernah: 420 → 976 → 1024).
2. Buang cache + compact, lalu jalankan lagi:
   ```bash
   echo 3 > /proc/sys/vm/drop_caches
   echo 1 > /proc/sys/vm/compact_memory
   nohup ./bakekok.sh > bakekok.log 2>&1 &
   disown
   ```
3. Reboot mesin lalu jalankan lagi secepatnya setelah boot, selagi
   RAM masih kosong.
4. Di BohrClaw/ArkClaw: tombol Restart di dashboard hanya
   me-restart aplikasi Claw, **bukan** OS-nya — jadi restart itu
   belum tentu membebaskan RAM seperti reboot beneran.
   **Jangan pernah tekan Factory Reset** — itu menghapus semua
   file, beda jauh dengan Restart.

### Pool offline / connection reset berulang (khusus bntpool)

Gejala: `pool offline at stratum+tcp://bntpool.com:3333
(Connection reset by peer)` berulang tiap ~2 detik, STATS terus
`hashes=0, rate=0.000, accepted=0`, dan tidak pernah ada baris
`login accepted`.

Diagnosis yang sudah terbukti (25 Okt 2026, Claw ArkClaw
124.174.3.209): TCP connect selalu berhasil, tapi koneksi ditutup
~0,22 detik kemudian — bahkan koneksi idle tanpa data pun ditutup.
`mining.authorize` tidak pernah terkirim, jadi penyebabnya bukan
wallet, bukan worker, bukan versi Seine. Ini masalah jalur egress
ke bntpool, bukan masalah install.

Solusinya: pindah ke pool kc di atas (direct), atau pakai relay
(lihat di bawah). Mengulang install, ganti worker, atau ganti
bntpool.com dengan IP-nya langsung (`69.164.251.242:3333`) sudah
dicoba dan **tidak mengubah apa-apa** — polanya identik.

### Probe generik ditolak pool kc — bukan berarti pool tidak cocok

Kalau kamu mengetes pool kc dengan probe `mining.subscribe`
generik, server menjawab `{"error":"unknown method"}` dan koneksi
tetap terbuka. Itu **bukan** bukti pool tidak cocok: Seine memakai
protokol stratum Blocknet v2 (terlihat di log sebagai `login
accepted (protocol v2, required=submit_claimed_hash)`), bukan
`mining.subscribe` generik. Satu-satunya tes kompatibilitas yang
valid adalah menjalankan Seine itu sendiri ke endpoint itu dan
melihat `login accepted` + share accepted.

### Relay (kalau direct ke suatu pool tidak bisa)

Relay adalah TCP forwarder mentah (bukan HTTP proxy) yang
dipasang di droplet DigitalOcean `139.59.115.14:443` dan meneruskan
ke pool. Relay dipakai dalam dua kasus yang sudah terbukti:

- Mesin yang egress-nya hanya membuka port 80/443 (contoh: VPS
  UpCloud) — direct ke port 3333 tidak bisa sama sekali.
- Jalur ArkClaw ke bntpool yang kena RST 0,22 detik — lewat relay
  port 443, Seine mendapat `login accepted` dan share accepted
  normal (terverifikasi: ~1,79 H/s, 0 stale).

Cara pakai relay: ganti `POOL_URL` di salinan lokal `bakekok.sh`
menjadi `stratum+tcp://139.59.115.14:443`, restart miner, dan
pastikan firewall relay mengizinkan IP egress mesin itu di port
443 (relay ini memakai allowlist IP — kalau IP mesin belum
diizinkan, connect akan timeout, bukan refused). Catatan: lewat
relay, dev fee Seine kembali ke 2,5% (pool tidak terdeteksi
langsung), dan telemetri HTTP pool lewat IP relay akan gagal
(`GET https://139.59.115.14/api/stats failed`) — itu tidak
menghentikan share, karena relay hanya meneruskan stratum, bukan
API web pool.

Relay adalah cadangan, bukan tujuan: kalau pool kc direct sudah
jalan di suatu mesin, tidak perlu relay di mesin itu.

### Masalah lain

- `curl` gagal / github tidak bisa dibuka — pakai metode upload
  scp/SFTP dari HP/laptop (lihat langkah 1).
- `SHA-256 mismatch` — arsip tidak diekstrak; ulangi download
  (download corrupt atau manifest berubah).
- `Expected 2 MiB huge pages` — kernel mesin tidak mendukung
  HugePages 2 MB (misalnya container tanpa akses host); skrip ini
  butuh VM beneran, bukan container terbatas.
- Peringatan `pool telemetry ... rate limited` di log boleh
  diabaikan: itu batas API telemetri pool, mining tetap jalan
  selama `login accepted` dan share accepted bertambah.
- `No such file or directory` saat `nohup ./bakekok.sh` — file
  `bakekok.sh` belum ada di folder itu; kembali ke langkah 2, dan
  pastikan kamu masih di `/root/bnt-seine-runner` saat download.
- `Cannot find the existing Seine binary` — binary `./seine`
  tidak ada di folder yang sama dengan `bakekok.sh`. Ini sering
  terjadi kalau tarball di-download/diekstrak di `/root/` polos
  sementara `bakekok.sh` ada di `/root/bnt-seine-runner/`.
  Solusinya: ulangi langkah 1 dari dalam folder
  `/root/bnt-seine-runner` (atau pindahkan binary `./seine` ke
  folder itu), lalu jalankan lagi.

## Riwayat perubahan pool

- Sampai 24 Okt 2026: pool utama `bntpool.com:3333`.
- 25 Okt 2026: direct ke bntpool dari jalur ArkClaw terbukti kena
  RST 0,22 detik; relay DO terbukti jalan sebagai jalan keluar.
- 25 Okt 2026: pool kc.txedu.social
  (`stratum+tcp://103.54.127.250:3333`) terbukti jalan direct dari
  Claw yang sama — `login accepted` protocol v2, share accepted,
  ~1,82 H/s, 0 stale — dan dijadikan pool utama di kedua skrip.
  bntpool tetap didokumentasikan sebagai cadangan.
