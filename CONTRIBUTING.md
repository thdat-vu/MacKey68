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
- Thay đổi hành vi remap/profile phải cập nhật `README.md`.
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
