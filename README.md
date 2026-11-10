# MacKey68 — biến Ziyoulang K68 thành bàn phím macOS

Trả lời ngắn cho câu hỏi "có app nào như Razer Synapse / G Hub cho K68 trên macOS không?":

**Không có.** Ziyoulang không phát hành phần mềm macOS cho K68, và cũng không có app
bên thứ ba nào nhận đúng board này (sharkfin hỗ trợ 1400+ board ROYUAN nhưng không có
Ziyoulang; VIA/QMK cũng không, vì đây không phải board QMK).

Nhưng **không cần app của hãng**. Board này (OnMicro BLE) chỉ gửi HID usage chuẩn, nên
có thể remap sạch ở tầng hệ điều hành. Repo này là app làm việc đó.

## Bàn phím đang cắm

```
$ mackey list
Bàn phím:
  0x9AEA:0x1029  OnMicro K68 BT5.0  [Bluetooth Low Energy]
```

Đọc HID report descriptor của nó cho thấy:

| Thông số | Giá trị |
|---|---|
| Chip | OnMicro (BLE) |
| VID:PID | `0x9AEA:0x1029` |
| Report interval | 8 ms (125 Hz) |
| Keyboard | boot protocol, 8 bit modifier + mảng 6 phím (6KRO, không NKRO) |
| Consumer page | có, usage `0x01…0x3FF` (media/volume) |
| Layout descriptor | ANSI, dải usage `0x00…0xFF` |

Hệ quả quan trọng: **Fn là xử lý trong firmware**, nên `Fn+...` sẽ phát ra một HID usage
bình thường (ví dụ `Fn+PgUp` → `Home`). Vì vậy remap ở macOS hoạt động được với cả
những phím chỉ bấm được qua Fn.

## Ba tầng để "ra layout Mac"

**1. Chế độ Mac phần cứng (thử trước, 5 giây).**
Họ firmware K68 thường có sẵn chế độ hệ điều hành:

| Tổ hợp | Chế độ |
|---|---|
| `Fn+S` | Windows |
| `Fn+A` | Android |
| `Fn+D` | **macOS** |
| `Fn+F` | iOS |

Bấm `Fn+D`, rồi thử lại phím Command/Option và hàng F. Nếu đúng thì xong, không cần
phần mềm. (Một số bản dùng `Fn+Z`/`Fn+X` cho Win/Mac — thử cả hai.)

> **Đã thử trên board này:** `Fn+D` chỉ gõ ra chữ `d`, `Fn+Esc` mới ra dấu `` ` ``.
> Firmware không có Mac mode, nên phải làm ở tầng macOS (mục 3).

**2. Sửa "Keyboard Type" của macOS.**
Nếu gõ ra sai ký tự (`@` thành `"`, không có dấu `` ` ``), đó không phải lỗi layout mà
là macOS đoán nhầm ANSI/ISO/JIS:
System Settings → Keyboard → *Change Keyboard Type…* → chọn ANSI.

**3. Remap bằng `mackey` (repo này).**
Dùng khi bạn muốn đổi chỗ cụ thể: Caps → Esc, Right Alt → Right Command, đổi
`Ctrl`/`Option`, biến `Fn+PgUp` (đang gửi `Home`) thành `Cmd+Left`, v.v.

## Cài đặt

Yêu cầu: macOS 13+, Command Line Tools (`xcode-select --install`). Không cần Xcode.

```bash
swift build -c release
ln -sf "$PWD/.build/release/mackey" /usr/local/bin/mackey
```

### App menu-bar (khuyến nghị)

```bash
./scripts/install-app.sh
```

Script đóng gói SwiftUI thành `~/Applications/MacKey68.app` (không cần Xcode), đăng ký
LaunchAgent `com.mackey68.app` để app tự chạy khi đăng nhập và giữ remap kể cả khi
rút/cắm bàn phím. Bình thường app chỉ sống ở menu bar; khi mở cửa sổ bàn phím, icon app
hiện tạm trên Dock và biến mất khi đóng cửa sổ.

Mở bàn phím vẽ ra — cách nào cũng được:

- Bấm **MacKey68** trong Launchpad / Finder (kể cả khi app đã chạy sẵn).
- Menu bar → icon bàn phím → **Mở bàn phím…**
- Terminal:

```bash
mackey board
# hoặc: open "mackey68://board"
```

> Đừng dùng `open MacKey68.app --args --board` khi app đã chạy: macOS coi đó là mở lại
> app đang chạy nên tham số bị bỏ qua. Dùng `mackey68://board` ở trên.

Trong cửa sổ đó:

- Bấm một phím trên hình để chọn, rồi chọn phím đích. Phím đã đổi hiện màu xanh và
  vẫn giữ nhãn gốc ở góc để không bị lẫn.
- **Tự đổi khi mở:** mỗi profile có danh sách app. Nút `+ TênApp` gắn profile đang chọn
  với app vừa dùng — bấm vào app đó (kể cả game chạy qua Wine/CrossOver) là profile tự
  bật. Nút `×` để bỏ gắn.
- Chọn profile ở ô trên cùng; `Bật` để tạm tắt toàn bộ remap.
- Góc phải có **VI / EN** để đổi ngôn ngữ giao diện; lựa chọn được nhớ cho lần sau.
  Menu bar cũng có mục **Ngôn ngữ / Language**.
- Menu bar có **Tự chạy khi đăng nhập / Launch at login** — bản cài bằng DMG tự bật mục
  này ở lần mở đầu tiên.

Mặc định có hai profile:

| Profile | Tự bật khi mở | Mapping |
|---|---|---|
| `macOS` | (mặc định) | LeftAlt↔LeftGUI — Caps vẫn là Caps |
| `League of Legends` | `com.riotgames.` | Caps→`` ` ``; không đảo Cmd/Alt |

Nghĩa là ngoài desktop, phím ngay trái Space là **⌘** như MacBook và **Caps Lock vẫn
dùng bình thường** để gõ chữ hoa. Vào game thì chỗ đó là **⌥**, còn Caps thành `` ` ``
một phím để khóa tướng — không cần `Fn+Esc`.

Gỡ app:

```bash
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.mackey68.app.plist
rm -rf ~/Applications/MacKey68.app
```

### Phát hành cho người khác (.dmg)

```bash
./scripts/package-dmg.sh
```

Tạo `dist/MacKey68-0.1.0.dmg`: mở ra có app và lối tắt Applications để kéo vào. App tự
đăng ký chạy khi đăng nhập ở lần mở đầu tiên, nên người dùng không cần Terminal.

Về Gatekeeper, có ba mức:

| Cách ký | Người dùng thấy gì |
|---|---|
| Không ký / ad-hoc (mặc định) | macOS chặn lần đầu: chuột phải app → **Open** → **Open** |
| Developer ID + notarize | Mở bình thường, không cảnh báo |
| Mac App Store | Cần sandbox và Apple duyệt; app này không phù hợp |

Để ký bằng Developer ID (cần tài khoản Apple Developer trả phí):

```bash
MACKEY_SIGN_IDENTITY="Developer ID Application: Tên (TEAMID)" ./scripts/package-dmg.sh
# sau đó notarize:
xcrun notarytool submit dist/MacKey68-0.1.0.dmg \
  --apple-id you@example.com --team-id TEAMID --password "$APP_PASSWORD" --wait
xcrun stapler staple dist/MacKey68-0.1.0.dmg
```

Icon app được vẽ bằng code, không cần file ảnh nguồn:

```bash
./scripts/make-icon.sh     # → Assets/AppIcon.icns
```

## Dùng

```bash
mackey list                 # xem bàn phím + VID:PID
mackey watch                # in ra usage thật khi bạn bấm (cần Input Monitoring)
mackey keys                 # tên phím dùng được trong config
mackey init                 # tạo ~/.config/mackey/keymap.json
mackey apply                # áp dụng
mackey dump                 # xem remap đang có hiệu lực
mackey reset                # xoá hết
mackey install-agent        # giữ remap kể cả khi rút/cắm lại bàn phím
mackey uninstall-agent
mackey board                # mở cửa sổ bàn phím của app
```

`mackey watch` cần quyền **Input Monitoring** (System Settings → Privacy & Security →
Input Monitoring → bật cho Terminal). Đây là công cụ để dò xem `Fn+...` thực sự gửi gì.

### Config

`~/.config/mackey/keymap.json` (hoặc `config/k68-mac.json` trong repo):

```json
{
  "name": "K68 on macOS",
  "device": { "vendorID": 39658, "productID": 4137 },
  "profiles": [
    {
      "id": "mac",
      "name": "macOS",
      "autoFor": [],
      "mappings": [
        { "from": "CapsLock", "to": "Grave" },
        { "from": "LeftAlt", "to": "LeftGUI" },
        { "from": "LeftGUI", "to": "LeftAlt" }
      ]
    },
    {
      "id": "league",
      "name": "League of Legends",
      "autoFor": ["com.riotgames."],
      "mappings": [
        { "from": "CapsLock", "to": "Grave" }
      ]
    }
  ]
}
```

- `autoFor`: bundle id của app mà profile tự bật. So khớp **chính xác hoặc theo tiền
  tố**, nên `com.riotgames.` bắt mọi bundle của Riot. Profile có `autoFor` rỗng là
  profile mặc định khi không app nào khớp.
- Dạng cũ chỉ có `mappings` vẫn đọc được và được nâng thành một profile `default`.
- App ghi config này mỗi khi bạn đổi phím hoặc gắn app, nên sửa tay xong chỉ cần mở lại
  app (hoặc bấm **Áp dụng lại** trên menu).

`vendorID`/`productID` là số thập phân (`0x9AEA` = 39658, `0x1029` = 4137). Để `null`
thì áp dụng cho mọi bàn phím.

Tên phím chấp nhận cả cách viết thường dùng: `Cmd`, `Command`, `Win`, `Opt`,
`Option`, `Alt`, `Ctrl`, `Esc`, `Enter`, `Backtick`, `Caps`… hoặc mã hex `0x39`.

### Giới hạn đã biết

- `UserKeyMapping` của `hidutil` chỉ map được **phím → phím**, không map được
  `modifier + phím` hay macro. Cần `Cmd+Left` thì phải dùng Karabiner-Elements.
- Phím media (Consumer page) không remap được bằng `hidutil`.
- Remap mất khi **rút bàn phím ra** (vì hidutil chỉ sửa những thiết bị đang tồn tại).
  `mackey install-agent` chạy nền và áp lại mỗi lần bàn phím được cắm vào.
- Không remap được phím `Fn` (firmware giữ nó).

### Nếu cần nhiều hơn

[Karabiner-Elements](https://karabiner-elements.pqrs.org) làm được mọi thứ trên
(combo, hyper key, layer, per-device). Dùng `mackey` khi bạn chỉ cần đổi vài phím và
không muốn thêm một kext/daemon của bên thứ ba.

## Cấu trúc

```
Sources/MacKeyKit/
  KeyCodes.swift     bảng tên phím ↔ HID usage
  Keymap.swift       model config + resolve + validate
  HIDDevices.swift   liệt kê thiết bị qua IORegistry (không cần quyền)
  HIDUtil.swift      gọi hidutil --matching --set
  DeviceWatcher.swift  theo dõi cắm/rút để áp lại mapping
  KeyWatcher.swift   dump usage realtime (Input Monitoring)
  LaunchAgent.swift  cài/gỡ agent chạy nền
Sources/mackey/main.swift   CLI
Sources/MacKey68App/        app menu-bar + bàn phím vẽ
  AppModel.swift     state, profile, gắn app, ghi hidutil
  Language.swift     enum VI/EN + helper dịch chuỗi
  LoginItem.swift    tự đăng ký chạy khi đăng nhập
  BoardView.swift    vẽ keycap
  BoardWindow.swift  cửa sổ bàn phím + inspector
  MacKey68App.swift  entry point + menu
Assets/              icon sinh ra bởi script (AppIcon.icns)
scripts/
  build-app.sh       đóng gói .app (không cần Xcode)
  install-app.sh     cài vào ~/Applications + LaunchAgent
  make-icon.swift    vẽ icon bằng AppKit
  make-icon.sh       xuất .icns
  package-dmg.sh     tạo DMG phát hành
```

Self-check: `swift run -c release mackey selftest` (XCTest chỉ có khi cài Xcode đầy đủ,
nên test nằm trong CLI).

## Giấy phép

Copyright (C) 2026 Vũ Thành Đạt.

MacKey68 là phần mềm tự do: bạn có thể phân phối lại và/hoặc sửa đổi theo điều khoản
**GNU General Public License phiên bản 3 hoặc mới hơn** (GPL-3.0-or-later) do Free
Software Foundation công bố. Xem toàn văn tại [LICENSE](LICENSE).

Phần mềm được cung cấp **KHÔNG CÓ BẢO HÀNH**, kể cả bảo hành về khả năng bán được hoặc
phù hợp cho một mục đích cụ thể.

### Dùng thương mại

GPL-3.0 **cho phép** sử dụng thương mại, nhưng nếu bạn phân phối bản sửa đổi hoặc sản
phẩm dẫn xuất từ MacKey68 thì phải công bố source theo GPL.

Nếu bạn muốn nhúng vào sản phẩm đóng hoặc không muốn tuân theo nghĩa vụ GPL, có thể mua
**giấy phép thương mại riêng** (dual licensing): mở issue tại
<https://github.com/thdat-vu/MacKey68/issues> để trao đổi.
