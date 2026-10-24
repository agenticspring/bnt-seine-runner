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
