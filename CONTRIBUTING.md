# Contributing to MacKey68

<a id="english"></a>
**English** · [Tiếng Việt](#tiếng-việt)

Thanks for wanting to contribute! This is a small tool: keep changes focused, clear,
and tested against real hardware when possible.

## Before you start

- Open an issue first for larger changes (new features, config format changes, remap
  behavior changes).
- For small fixes, feel free to open a pull request directly.

## Build and test

Requirements: macOS 13+, Command Line Tools (`xcode-select --install`). Xcode is not
needed.

```bash
swift build -c release
./.build/release/mackey selftest
./scripts/build-app.sh          # make sure the app still packages
```

If you change the UI, run the app:

```bash
open build/MacKey68.app
./.build/release/mackey board   # open the keyboard window
```

If you change key reading/writing, verify on a real keyboard:

```bash
./.build/release/mackey dump --device 0x9AEA:0x1029
```

## Conventions

- Match the existing Swift style; prefer clarity over brevity.
- Every UI string must exist in both Vietnamese and English (`model.t("VI", "EN")`).
- Changes to remap/profile behavior must update `README.md` (both language sections).
- Don't commit `.build/`, `build/`, `dist/`, generated icons, or personal config from
  `~/.config/mackey/`.

## Pull requests

- One PR per change; describe the problem and the fix briefly.
- Mention which keyboard you tested with (for example `0x9AEA:0x1029`) when relevant.
- Fill in the checklist in the PR template.

## CLA is required

Before a PR can be merged, you must agree to the
[Individual Contributor License Agreement](CLA.md).

How to sign: comment on your PR with exactly this sentence (plus your full name and
date):

```
I have read the CLA Document and I hereby sign the CLA
Vu Thanh Dat, 2026-11-10
```

This electronic signature lets the Project Owner use your contribution in the project
under GPL-3.0-or-later **and** relicense it under commercial terms (dual licensing).
You keep the copyright in your contribution and may use it for any other purpose.

If you contribute on behalf of a company, open an issue to arrange a corporate CLA
first.

> Note: if the project grows enough, we can enable
> [CLA Assistant](https://github.com/cla-assistant/cla-assistant) to check signatures
> automatically. For now, signatures are checked manually during review.

## License of contributions

Contributions are distributed in the project under
[GPL-3.0-or-later](LICENSE). The CLA above is an additional agreement between you and
the Project Owner; it does not change the rights of end users under the GPL.

---

<a id="tiếng-việt"></a>
**Tiếng Việt** · [English](#english)

# Đóng góp cho MacKey68

Cảm ơn bạn muốn đóng góp! Repo này là công cụ nhỏ, ưu tiên thay đổi gọn, rõ và có
kiểm tra trên bàn phím thật khi có thể.

## Trước khi bắt đầu

- Mở issue để trao đổi trước với thay đổi lớn (thêm feature, đổi format config,
  đổi cách remap).
- Với lỗi nhỏ, cứ mở pull request trực tiếp.

## Build và kiểm tra

Yêu cầu: macOS 13+, Command Line Tools (`xcode-select --install`). Không cần Xcode.

```bash
swift build -c release
./.build/release/mackey selftest
./scripts/build-app.sh          # kiểm tra app vẫn đóng gói được
```

Nếu sửa phần giao diện, chạy thử app:

```bash
open build/MacKey68.app
./.build/release/mackey board   # mở cửa sổ bàn phím
```

Nếu sửa phần đọc/ghi phím, kiểm tra trên bàn phím thật:

```bash
./.build/release/mackey dump --device 0x9AEA:0x1029
```

## Quy ước

- Swift theo style hiện có; ưu tiên rõ ràng hơn ngắn.
- Chuỗi giao diện phải có cả tiếng Việt và tiếng Anh (`model.t("VI", "EN")`).
- Thay đổi hành vi remap/profile phải cập nhật `README.md` (cả hai phần ngôn ngữ).
- Không commit `.build/`, `build/`, `dist/`, icon sinh tự động, hay config cá nhân
  trong `~/.config/mackey/`.

## Pull request

- Một PR cho một việc; mô tả ngắn gọn vấn đề và cách sửa.
- Ghi rõ đã thử trên bàn phím nào (ví dụ `0x9AEA:0x1029`) nếu có.
- Điền checklist trong PR template.

## CLA bắt buộc

Trước khi PR được merge, bạn cần đồng ý với
[Individual Contributor License Agreement](CLA.md).

Cách ký: bình luận trên PR của bạn đúng câu sau (kèm họ tên và ngày):

```
I have read the CLA Document and I hereby sign the CLA
Vũ Thành Đạt, 2026-11-10
```

Chữ ký điện tử này cho phép Project Owner dùng đóng góp của bạn trong dự án theo
GPL-3.0-or-later **và** cấp phép lại theo điều khoản thương mại (dual licensing).
Bạn vẫn giữ bản quyền cho đóng góp của mình và có thể dùng nó cho mục đích khác.

Nếu bạn đóng góp thay mặt công ty, hãy mở issue để trao đổi corporate CLA trước.

> Ghi chú: nếu repo phát triển đủ đông, có thể bật
> [CLA Assistant](https://github.com/cla-assistant/cla-assistant) để tự động kiểm
> tra chữ ký. Hiện tại việc ký được kiểm tra thủ công khi review PR.

## Giấy phép của đóng góp

Đóng góp được phân phối trong dự án theo
[GPL-3.0-or-later](LICENSE). CLA ở trên là thỏa thuận bổ sung giữa bạn và Project
Owner, không thay đổi quyền của người dùng cuối theo GPL.
