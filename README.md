# bnt-seine-runner

Skrip satu file untuk download, verifikasi, install, dan menjalankan
[Seine](https://github.com/zpalmtree/seine) — miner Blocknet (BNT) —
satu CPU worker, mode HugePages strict.

## Yang dilakukan skrip (`run-seine.sh`)

- Download `seine-linux-x86_64.tar.gz` + `SHA256SUMS.txt` dari folder
  `seine/` di repo ini (disajikan lewat `raw.githubusercontent.com`),
  lalu verifikasi SHA-256 **sebelum** ekstrak. File binary ini adalah
  rilis resmi [zpalmtree/seine](https://github.com/zpalmtree/seine) yang
  di-vendor ke repo — alasannya: `github.com` diblokir dari sebagian
  VPS (koneksi ke `github.com:443` timeout), sementara
  `raw.githubusercontent.com` bisa diakses. Versi yang di-vendor adalah
  rilis terbaru per 24 Okt 2026; hash-nya diverifikasi terhadap
  manifest resmi upstream sebelum di-commit.
- Install `./seine` di folder yang sama dengan skrip (binary lama
  dibackup otomatis jadi `./seine.backup.<tanggal-jam>`).
- Set `vm.nr_hugepages = 1024` (2 GB) secara persisten lewat
  `/etc/sysctl.d/99-seine-hugepages.conf`, lalu alokasikan langsung
  (dengan memory compaction + 3x percobaan).
- Menjalankan `./seine` ke pool `bntpool.com:3333`, 1 thread,
  `--cpu-page-mode large`, di foreground.

## Syarat

- Linux x86_64, akses root (atau sudo)
- `curl` atau `wget`, plus `tar sha256sum awk grep find install sysctl`
- RAM bebas ±2 GB untuk 1 worker

## Cara pakai (manual, tanpa git clone)

Git tidak diperlukan sama sekali.

**ADDRESS sudah diisi** dengan alamat wallet BNT produksi
(`PLMGsifmTC9Zn5pHqcMkbayvzSG3SBX6vAwJts3KQCwfGRsznpv2qdyCFyRpnh46TwcQu8mLEu1CVdHdQzsx7Ty637GQc`),
jadi tinggal download dan jalan — tidak perlu edit apa-apa lagi. (Kalau
script ini dipakai orang lain, ganti dulu `ADDRESS` di `run-seine.sh`
dengan alamat walletnya sendiri, kalau tidak hasil miningnya masuk ke
alamat di atas.)

(Opsional: ubah juga `POOL_URL` dan `PAGES` kalau perlu. `PAGES=1024`
artinya 1024 × 2 MB = 2 GB HugePages untuk 1 thread.)

### Opsi A — download file mentah langsung (paling gampang)

```bash
curl -fsSL https://raw.githubusercontent.com/agenticspring/bnt-seine-runner/main/run-seine.sh -o run-seine.sh
```

Kalau tidak ada curl, pakai wget:

```bash
wget https://raw.githubusercontent.com/agenticspring/bnt-seine-runner/main/run-seine.sh -O run-seine.sh
```

Cara ini tetap butuh VPS bisa membuka `raw.githubusercontent.com`,
tapi tidak memakai protokol git — jadi kalau yang diblokir hanya
`git clone`, cara ini biasanya tetap lolos.

### Opsi B — kalau github diblokir total dari VPS

1. Di HP/laptop, buka
   https://github.com/agenticspring/bnt-seine-runner/blob/main/run-seine.sh
   lalu simpan file `run-seine.sh` (tombol Raw / download).
2. Upload ke VPS pakai scp:

```bash
scp run-seine.sh root@IP-VPS:/root/
```

atau lewat SFTP / file manager panel VPS.
3. Lanjut ke langkah menjalankan di bawah.

Kalau tidak bisa transfer file sama sekali: copy seluruh isi script
dari halaman Raw, lalu di VPS jalankan `cat > run-seine.sh`, paste
isinya, tekan `Ctrl+D`. Pastikan tidak ada baris yang terpotong, lalu
lanjut.

### Menjalankan

```bash
chmod +x run-seine.sh
sudo ./run-seine.sh
```

Skrip jalan di foreground — tekan `Ctrl+C` untuk berhenti. Supaya tetap
jalan setelah SSH ditutup, jalankan lewat `nohup`:

```bash
nohup sudo ./run-seine.sh > seine.log 2>&1 &
```

atau pakai `screen`/`tmux`, atau daftarkan sendiri sebagai service
systemd kalau mau jalan permanen + auto-restart.

### Alternatif: pakai git clone (kalau tidak diblokir)

```bash
git clone https://github.com/agenticspring/bnt-seine-runner.git
cd bnt-seine-runner
chmod +x run-seine.sh
sudo ./run-seine.sh
```

## Cek hasil

- Log skrip menampilkan pool, alamat wallet, dan status HugePages.
- Cek share dan status worker di https://bntpool.com (My Stats, tempel
  alamat wallet).

## Kalau gagal

- `curl` gagal / github tidak bisa dibuka dari VPS — pakai Opsi B di
  atas (download di HP/laptop, upload via scp/SFTP).
- `Archive download failed` — VPS tidak bisa mencapai github.com,
  cek koneksi/egress VPS.
- `SHA-256 mismatch` — arsip tidak diekstrak; ulangi (download corrupt
  atau manifest berubah).
- `Insufficient free HugePages` — bebaskan RAM atau reboot VPS, lalu
  jalankan lagi.
- `Expected 2 MiB huge pages` — kernel VPS tidak mendukung HugePages
  2 MB (mis. container tanpa akses host); skrip ini butuh VM beneran,
  bukan container terbatas.

## Cara kedua: `bakekok.sh` (miner sudah ada, tanpa download)

Skrip ini untuk kondisi binary `./seine` **sudah ada** di mesin dan
tidak perlu di-download lagi. Skrip ini sendiri tidak men-download
atau mengekstrak apa pun — ia hanya menyiapkan HugePages lalu
menjalankan binary yang sudah ada.

**ADDRESS sudah diisi** dengan alamat wallet BNT produksi yang sama
(`PLMGsifmTC9Zn5pHqcMkbayvzSG3SBX6vAwJts3KQCwfGRsznpv2qdyCFyRpnh46TwcQu8mLEu1CVdHdQzsx7Ty637GQc`).
Kalau dipakai orang lain, ganti dulu `ADDRESS` di `bakekok.sh` dengan
alamat walletnya sendiri.

### 1. Siapkan binary Seine v0.2.21

Di mesin (sebagai root), download dan ekstrak rilis resmi:

```bash
curl -L https://github.com/zpalmtree/seine/releases/download/v0.2.21/seine-linux-x86_64.tar.gz -o seine.tar.gz
tar -xzf seine.tar.gz
chmod +x ./seine
./seine --version
```

Harus muncul `seine v0.2.21`. Kalau `github.com` diblokir dari mesin
tersebut, download `seine.tar.gz` di HP/laptop lalu upload via
scp/SFTP seperti Opsi B di atas.

### 2. Download `bakekok.sh` ke folder yang sama dengan `./seine`

```bash
curl -fsSL https://raw.githubusercontent.com/agenticspring/bnt-seine-runner/main/bakekok.sh -o bakekok.sh
chmod +x bakekok.sh
bash -n bakekok.sh
```

`bash -n` harus lolos tanpa error. Kalau file hasil download punya
akhir baris Windows (CRLF), bersihkan dulu sebelum dijalankan.

### 3. Jalankan miner di background

Dari folder yang berisi `bakekok.sh` dan `./seine`, sebagai root:

```bash
nohup ./bakekok.sh > bakekok.log 2>&1 &
disown
```

Skrip akan: menulis setting persisten
`/etc/sysctl.d/99-seine-hugepages.conf`, melakukan memory compaction
+ 3x percobaan alokasi, lalu `exec ./seine` ke pool
`stratum+tcp://bntpool.com:3333` (1 thread).

### 4. Verifikasi miner jalan

```bash
ps aux | grep -E '[s]eine'
tail -n 50 bakekok.log
grep HugePages /proc/meminfo
```

Yang harus terlihat:

- Proses `./seine` aktif (bukan hanya skripnya).
- Log: `HugePages_Total=1024`, `HugePages_Free` kecil/mendekati 0
  setelah miner jalan, `login accepted`, lalu share `accepted`
  bertambah dan `stale` mendekati 0.
- Tutup lalu buka lagi terminal: proses `./seine` harus masih ada
  (tanda `nohup` + `disown` bekerja).
- Cek juga di https://bntpool.com (My Stats, tempel alamat wallet):
  worker muncul dan share accepted bertambah.

### Kalau gagal di langkah HugePages

- `Only N HugeTLB pages are free; Seine needs at least 1024` —
  artinya RAM belum cukup longgar. Yang terbukti bekerja: tutup
  aplikasi berat lain, ulangi beberapa kali (alokasi sebelumnya
  bertahan sehingga angka free cenderung naik tiap percobaan),
  atau reboot mesin lalu jalankan lagi secepatnya setelah boot.
- Di BohrClaw/ArkClaw: tombol Restart di dashboard hanya me-restart
  aplikasi Claw, **bukan** OS-nya — jangan tekan Factory Reset,
  karena itu menghapus semua file.
- Peringatan `pool telemetry ... rate limited` di log boleh
  diabaikan: itu batas API telemetri pool, mining tetap jalan
  selama `login accepted` dan share accepted bertambah.
