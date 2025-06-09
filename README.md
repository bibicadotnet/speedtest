# speedtest

Giới thiệu ngắn gọn thì nó là 1 bash script kiểm tra tốc độ và các thông tin cấu hình của VPS, được viết ra bởi [teddysun](https://teddysun.com/444.html)

Tác giả viết cho trang bench.sh, mình chỉ bổ xung các location Việt Nam thêm vào, còn lại như bản gốc

```
wget -qO- https://go.bibica.net/speedtest | bash
```
Dùng cũng 2-3 năm nay, mà thi thoảng location Việt Nam, các cụ VNPT, FPT, Viettel đổi ID xoành xoạch, vào check cứ thấy sập, sửa thủ công thì mệt như bò đá, nên bổ xung thêm tính năng tự cập nhập lại ID

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
    speed_test '14236' 'Los Angeles, US'
    speed_test '61933' 'Paris, FR'
    speed_test '49516' 'Berlin, DE'
    speed_test '63143' 'Hong Kong, HK'
    speed_test '13623' 'Singapore, SG'
    speed_test '48463' 'Tokyo, JP'
    speed_test '67826' 'FPT Telecom, VN'
    speed_test '17757' 'VNPT-NET, VN'
    speed_test '9903' 'Viettel, VN'
}
```
Phần README này ghi lại với mục đích nhớ là chính, không có ý nghĩa gì với người đọc hé 😇
