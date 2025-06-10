# speedtest

Giới thiệu ngắn gọn `benchmark.bibica.net` là 1 bash script kiểm tra tốc độ và các thông tin cấu hình của VPS, được viết ra bởi [teddysun](https://teddysun.com/444.html). sử dụng đơn giản thì chạy lệnh bên dưới

```
wget -qO- https://benchmark.bibica.net | bash
```

Tác giả viết từ 2015, sau này dùng cho trang `bench.sh`, mà ảnh xài check toàn mấy location China, ở Việt Nam check thì hơi thừa, nên mình sửa thành location Việt Nam thêm vào, còn lại như bản gốc

Cá nhân, mình nghĩ nên thêm vào kết quả `Geekbench` như `yabs.sh` đang dùng để xem hiệu năng CPU, thêm cả phần kernel `TCP/IP` stack nữa thì bài benchmark sẽ tương đối đầy đủ số liệu

Có điều nếu thêm hết vào, chạy 1 bài test, có khi mất 15-20 phút, quá dài so với nhu cầu thông thường

# Tự động thay đổi locaiton

- Dùng cũng 2-3 năm nay, mà thi thoảng location Việt Nam, các cụ VNPT, FPT, Viettel đổi ID xoành xoạch, vào check cứ thấy sập, sửa thủ công thì mệt như bò đá, nên bổ xung thêm tính năng tự cập nhập lại ID, tránh các tình huống này

Logic xử lý khá là củ chuối 😅 nôm na speedtest có hỗ trợ API qua đường link:
```
https://www.speedtest.net/api/js/servers?engine=js&https_functional=true&limit=1000&search=Tokyo
```
- Cứ tìm kiếm 1 thành phố cụ thể, rồi lấy 1 ID nào đó trong danh sách hiện tại là được, lý thuyết cụm đó sẽ live, đỡ phải xử lý check xem cụm đó ra làm sao
- Để lấy cụ thể 1 nhà cung cấp nào đó, bổ xung thêm hình thức ưu tiên, thêm thẳng tên nhà cung cấp đó vào, sẽ ưu tiên lấy theo ID của họ

Cách thức khá là thủ công, mà chạy thấy cũng ổn, check tầm 10-12s là xong
  
```
Run python scripts/check_speedtest.py
Fetching ID for Los Angeles, US...
  → Found sponsor 'Frontier' in BIG_SPONSORS, using ID 14236
[No Change] Los Angeles, US (kept 14236)
Fetching ID for Paris, FR...
  → Found sponsor 'Scaleway' in BIG_SPONSORS, using ID 61933
[No Change] Paris, FR (kept 61933)
Fetching ID for Berlin, DE...
  → Found sponsor 'Internetnord GmbH' in BIG_SPONSORS, using ID 49516
[No Change] Berlin, DE (kept 49516)
Fetching ID for Hong Kong, HK...
  → Found sponsor 'Netvigator' in BIG_SPONSORS, using ID 63143
[No Change] Hong Kong, HK (kept 63143)
Fetching ID for Singapore, SG...
  → Found sponsor 'Singtel' in BIG_SPONSORS, using ID 13623
[No Change] Singapore, SG (kept 13623)
Fetching ID for Tokyo, JP...
  → Found sponsor 'IPA CyberLab 400G' in BIG_SPONSORS, using ID 48463
[No Change] Tokyo, JP (kept 48463)
Fetching ID for FPT Telecom, VN...
  → Found sponsor 'FPT Telecom' in BIG_SPONSORS, using ID 67826
[No Change] FPT Telecom, VN (kept 67826)
Fetching ID for VNPT-NET, VN...
  → Found sponsor 'VNPT-NET' in BIG_SPONSORS, using ID 17757
[No Change] VNPT-NET, VN (kept 17757)
Fetching ID for Viettel, VN...
  → Found sponsor 'Viettel Network' in BIG_SPONSORS, using ID 9903
[No Change] Viettel, VN (kept 9903)
✅ bench.sh updated successfully.
```
Cách này được thêm 1 cái khá tiện, chỉ cần giữ phần `speed_test` như bên dưới, sau teddysun có nâng cấp phiên bản thì chỉ cần chép hết về, copy lại phần speed là xong
```
speed() {
    speed_test '' 'Speedtest.net'
    speed_test '14236' 'Los Angeles, US'; speed_test '61933' 'Paris, FR'; speed_test '49516' 'Berlin, DE'
    speed_test '63143' 'Hong Kong, HK'; speed_test '13623' 'Singapore, SG'; speed_test '48463' 'Tokyo, JP'
    speed_test '67826' 'FPT Telecom, VN'; speed_test '45493' 'VNPT-NET, VN'; speed_test '9903' 'Viettel, VN'
}
```
# Lưu kết quả lên Cloudflae Page

Y tưởng ban đầu là decode base64 data từ URL hash, tạo ra 1 URL không cần database, gần như sống mãi theo hệ thống của Cloudflare, vì Cloudflare Page miễn phi 100%

Vấn đề phát sinh là cái URL này nó quá là dài, ít cũng hơn 1000 kí tự, dài thì gần 4000 kí tự, khi chia sẽ URL khá phiền

Tính toán 1 hồi thì vẫn thấy chạy qua database D1, 1 bài test, chỉ tạo ra 1 dòng, cho ghi miễn phí 100.000 dòng mỗi 24h, gần như dùng không hết hạn ngạch này

### Cài đặt

Tạo 1 databse D1 với tên tùy ý, sang tab `Console` chạy tuần tự 3 dòng code bên dưới
```
-- schema.sql
CREATE TABLE IF NOT EXISTS benchmarks (
    slug TEXT PRIMARY KEY,
    data TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    accessed_count INTEGER DEFAULT 0,
    last_accessed TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Index cho performance
CREATE INDEX IF NOT EXISTS idx_created_at ON benchmarks(created_at);
CREATE INDEX IF NOT EXISTS idx_last_accessed ON benchmarks(last_accessed);
```
Đẩy dự án sang Cloudflare Page

Settings -> Bindings -> Add -> D1 database
```
| **Type**    | **Name** | **Value**            |
| ----------- | -------- | -------------------- |
| D1 database | DB       | benchmark-bibica-net |
```
Chú ý duy nhất giá trị Variable name là `DB`, database thì nãy tạo ra là gì thì giờ chọn nó là được

Bước cài đặt tổng thể là như thế, nếu bạn nào fork dự án về thì sửa `benchmark.bibica.net` thành tên trang Cloudflare Page bạn dùng là được

Link sau khi chạy benchmark sẽ có dạng [slug 8 kí tự](https://benchmark.bibica.net/6676f187), như sau `https://benchmark.bibica.net/6676f187`

- Công đoạn xử lý dữ liệu thô gửi lên Cloudflae Page khá be bét, không rõ có cách nào xử lý tốt hơn không, trước khi gửi dữ liệu lên, phải làm sạch 1 lần, nhận được dữ liệu, phải phải thêm màu sắc vào cho giống khi chạy ở màn hình ban đầu 

# Kết luận

Phần README này ghi lại với mục đích nhớ là chính, trừ bạn nào fork dự án cần đọc qua, còn lại không có ý nghĩa gì với người đọc hé 😇
