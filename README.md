# Receipt Fax

Send messages from your iPhone and have them print on a thermal receipt printer. Self-hosted, no cloud required.

![iOS compose screen sends a message → FastAPI backend → Raspberry Pi polls and prints on thermal printer]

## How it works

1. You type a message in the iOS app and tap Send
2. The FastAPI backend stores it in PostgreSQL
3. A Raspberry Pi Zero 2 W polls the backend and prints it on a USB thermal receipt printer

Messages support rich text: **bold** spans, three text sizes, left/center alignment, and four font styles (monospace, serif, sans-serif, handwriting).

---

## Hardware

- Raspberry Pi Zero 2 W (or any Pi with USB)
- USB thermal receipt printer (58mm, ESC/POS compatible)
- A server to run the backend (tested on a home Proxmox VM)

---

## Self-hosting the backend

### Prerequisites

- Docker and Docker Compose
- A domain or local IP your iPhone can reach

### Setup

```bash
git clone https://github.com/MarcosAOSperoni/receipt-fax.git
cd receipt-fax
```

Create `backend/.env`:

```env
DATABASE_URL=postgresql+asyncpg://receiptfax:receiptfax@db/receiptfax
SECRET_KEY=your-secret-key-here
MEDIA_DIR=/app/media
```

Start the stack:

```bash
docker compose up -d
docker compose exec api alembic upgrade head
```

The API is now running on port `8000`.

### Creating your account

Use the API directly to register:

```bash
curl -X POST http://your-server:8000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email": "you@example.com", "password": "yourpassword"}'
```

Then log in through the iOS app with those credentials.

---

## Setting up the printer client (Raspberry Pi)

### Install dependencies

```bash
sudo apt update
sudo apt install python3-venv fonts-dejavu fonts-humor-sans

cd ~/receipt-fax/printer
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

### Configure

```bash
cp config.ini.example config.ini
```

Edit `config.ini`:

```ini
[server]
url = http://your-server:8000
device_key = sk_your_device_key_here   # from the iOS app after adding a device

[printer]
usb_vendor_id = 0x04b8    # find with: lsusb
usb_product_id = 0x0e15
char_width = 42
print_width_px = 576      # 384 for 58mm printers, 576 for 80mm
```

To find your printer's USB IDs:

```bash
lsusb
# look for your printer, e.g. "04b8:0e15 Seiko Epson Corp."
```

### Run as a service

```bash
# edit receipt-fax.service and replace YOUR_USER with your username
sudo cp receipt-fax.service /etc/systemd/system/
sudo systemctl enable receipt-fax
sudo systemctl start receipt-fax
```

Check logs:

```bash
sudo journalctl -u receipt-fax -f
```

---

## iOS app

Open `ios/ReceiptFax.xcodeproj` in Xcode, build and run on your iPhone. On first launch, enter your server URL and log in.

The app requires iOS 16+.

---

## Features

- Rich text messages with bold, size, and alignment controls
- Four font styles: Monospace, Serif, Sans-serif, Handwriting
- Photo attachments (printed before the text)
- Message history with print status (pending / printed / failed)
- Multiple printers via device registration

---

## License

MIT
