# Nhật ký thay đổi trong quá trình phát triển

> Mục đích: Ghi lại thay đổi file theo từng yêu cầu phát triển để hỗ trợ truy vết và review.  
> Múi giờ: `Asia/Saigon` (`UTC+07:00`)  
> Phạm vi: Source code, contract, schema, test, cấu hình, infrastructure, tài liệu và agent rule  
> Lưu ý: Đây là development change log, không thay thế product release notes hoặc Git history.

## Quy ước

- Cột ngày nằm ngoài cùng bên trái và dùng định dạng `YYYY-MM-DD`.
- Các bản ghi cùng ngày dùng chung một ô ngày được gộp theo chiều dọc bằng `rowspan` trong bảng HTML.
- Cột thời gian nằm ngay bên phải cột ngày và chỉ dùng giờ Việt Nam dạng `HH:mm:ss`.
- Mỗi bản ghi mô tả một mục đích thay đổi thống nhất, gồm **Mục đích chung** và **Tác dụng của file/thay đổi**.
- Mục đích chung phải nêu kết quả cần đạt, lý do thực hiện và giá trị của nhóm thay đổi; không chỉ lặp lại yêu cầu hoặc tên file.
- Tác dụng của file/thay đổi phải giải thích file được tạo, sửa, di chuyển, xóa hoặc ngừng theo dõi để làm gì. Có thể nhóm các file cùng vai trò nhưng không được chỉ liệt kê đường dẫn.
- File được ghi bằng đường dẫn tương đối từ repository root và kèm hành động.
- Bản ghi hồi tố phải được đánh dấu rõ khi thời gian ghi nhận khác thời gian thực hiện ban đầu.
- Không ghi thông tin xác thực hoặc dữ liệu nhạy cảm.

<table>
  <thead>
    <tr>
      <th>Ngày</th>
      <th>Thời gian</th>
      <th>Mục đích</th>
      <th>File tạo/sửa/xóa</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td rowspan="6"><strong>2026-07-16</strong></td>
      <td>23:02:54</td>
      <td><strong>Bản ghi hồi tố — Mục đích chung:</strong> Thiết lập baseline nghiệp vụ và kỹ thuật có thể triển khai cho vertical slice học tập đầu tiên, đồng thời chuẩn hóa quy trình phát triển dùng chung để sản phẩm, kiến trúc và contract có cùng nguồn tham chiếu.<br><strong>Tác dụng của file/thay đổi:</strong> <code>README.md</code> giải thích phạm vi và cách dùng schema; các schema <code>common</code>, <code>language</code>, <code>course</code>, <code>lesson</code> định nghĩa cấu trúc dữ liệu và ràng buộc; file example cung cấp dữ liệu mẫu; OpenAPI mô tả endpoint và payload; ADR lưu quyết định contract baseline; tài liệu workflow quy định các giai đoạn phát triển; <code>Project.md</code> ghi nhận phạm vi sản phẩm; <code>Tech_Stack_And_Architecture.md</code> liên kết contract với kiến trúc mục tiêu.</td>
      <td><strong>Tạo:</strong> <code>contracts/content-schema/README.md</code><br><strong>Tạo:</strong> <code>contracts/content-schema/common.schema.json</code><br><strong>Tạo:</strong> <code>contracts/content-schema/language.schema.json</code><br><strong>Tạo:</strong> <code>contracts/content-schema/course.schema.json</code><br><strong>Tạo:</strong> <code>contracts/content-schema/lesson.schema.json</code><br><strong>Tạo:</strong> <code>contracts/content-schema/lesson.example.json</code><br><strong>Tạo:</strong> <code>contracts/openapi/esquilospeak-learning-v1.yaml</code><br><strong>Tạo:</strong> <code>docs/Adr_001_Contract_Specification_Baseline.md</code><br><strong>Tạo:</strong> <code>docs/General_Software_Development_Workflow.md</code><br><strong>Sửa:</strong> <code>docs/Project.md</code><br><strong>Sửa:</strong> <code>docs/Tech_Stack_And_Architecture.md</code></td>
    </tr>
    <tr>
      <td>23:02:54</td>
      <td><strong>Mục đích chung:</strong> Tạo cơ chế truy vết thay đổi thống nhất để developer biết thay đổi được thực hiện khi nào, nhằm giải quyết vấn đề gì và tác động đến file nào.<br><strong>Tác dụng của file/thay đổi:</strong> <code>.agent/AGENTS.md</code> buộc agent cập nhật nhật ký sau mọi thao tác làm thay đổi workspace; <code>Development_Change_Log.md</code> lưu các bản ghi phục vụ review, đối chiếu và bàn giao.</td>
      <td><strong>Sửa:</strong> <code>.agent/AGENTS.md</code><br><strong>Tạo:</strong> <code>docs/Development_Change_Log.md</code></td>
    </tr>
    <tr>
      <td>23:14:59</td>
      <td><strong>Mục đích chung:</strong> Chuẩn hóa cách đặt tên và ghi nhận tài liệu để repository nhất quán, dễ tìm kiếm trên nhiều hệ điều hành và không còn placeholder ở thư mục đã có nội dung.<br><strong>Tác dụng của file/thay đổi:</strong> Hai <code>.gitkeep</code> được xóa vì thư mục contract không còn rỗng; các file Markdown được đổi sang <code>Pascal_Case_With_Underscores</code>; hai file agent lưu quy tắc tên file và thời gian Việt Nam; hai sơ đồ được cập nhật để hiển thị đúng tên mới.</td>
      <td><strong>Xóa:</strong> <code>contracts/content-schema/.gitkeep</code><br><strong>Xóa:</strong> <code>contracts/openapi/.gitkeep</code><br><strong>Di chuyển:</strong> <code>docs/ADR-001-CONTRACT-SPECIFICATION-BASELINE.md</code> → <code>docs/Adr_001_Contract_Specification_Baseline.md</code><br><strong>Di chuyển:</strong> <code>docs/DEVELOPMENT_CHANGE_LOG.md</code> → <code>docs/Development_Change_Log.md</code><br><strong>Di chuyển:</strong> <code>docs/EsquiloSpeak.md</code> → <code>docs/Esquilo_Speak.md</code><br><strong>Di chuyển:</strong> <code>docs/GENERAL_SOFTWARE_DEVELOPMENT_WORKFLOW.md</code> → <code>docs/General_Software_Development_Workflow.md</code><br><strong>Di chuyển:</strong> <code>docs/NHUNG_DIEM_CHUA_PHU_HOP_CAU_TRUC_REPOSITORY.md</code> → <code>docs/Nhung_Diem_Chua_Phu_Hop_Cau_Truc_Repository.md</code><br><strong>Di chuyển:</strong> <code>docs/PROJECT.md</code> → <code>docs/Project.md</code><br><strong>Di chuyển:</strong> <code>docs/REPOSITORY_STRUCTURE.md</code> → <code>docs/Repository_Structure.md</code><br><strong>Di chuyển:</strong> <code>docs/TECH_STACK_AND_ARCHITECTURE.md</code> → <code>docs/Tech_Stack_And_Architecture.md</code><br><strong>Sửa:</strong> <code>.agent/AGENTS.md</code><br><strong>Sửa:</strong> <code>.agent/SKILL.md</code><br><strong>Sửa:</strong> <code>docs/assets/esquilospeak-repository-structure.svg</code><br><strong>Sửa:</strong> <code>docs/assets/esquilospeak-repository-structure.png</code></td>
    </tr>
    <tr>
      <td>23:30:56</td>
      <td><strong>Mục đích chung:</strong> Đổi nơi lưu schema sang tên tổng quát để có thể chứa nhiều nhóm contract khi sản phẩm mở rộng, đồng thời chuẩn hóa quy trình đề xuất nhánh và commit.<br><strong>Tác dụng của file/thay đổi:</strong> <code>contracts/content-schema/</code> được chuyển thành <code>contracts/schema/</code>; OpenAPI, tài liệu nguồn và sơ đồ được sửa để không còn trỏ đến tên cũ; hai file agent quy định cách đề xuất feature branch, Conventional Commit và phạm vi commit bằng tiếng Anh.</td>
      <td><strong>Di chuyển:</strong> <code>contracts/content-schema/</code> → <code>contracts/schema/</code><br><strong>Sửa:</strong> <code>contracts/openapi/esquilospeak-learning-v1.yaml</code><br><strong>Sửa:</strong> <code>docs/Project.md</code><br><strong>Sửa:</strong> <code>docs/Repository_Structure.md</code><br><strong>Sửa:</strong> <code>docs/Adr_001_Contract_Specification_Baseline.md</code><br><strong>Sửa:</strong> <code>docs/assets/esquilospeak-repository-structure.svg</code><br><strong>Sửa:</strong> <code>docs/assets/esquilospeak-repository-structure.png</code><br><strong>Sửa:</strong> <code>.agent/AGENTS.md</code><br><strong>Sửa:</strong> <code>.agent/SKILL.md</code></td>
    </tr>
    <tr>
      <td>23:38:07</td>
      <td><strong>Mục đích chung:</strong> Xây dựng mô tả nghiệp vụ mục tiêu đầy đủ của EsquiloSpeak để định hướng backlog, domain boundary và các vertical slice tiếp theo.<br><strong>Tác dụng của file/thay đổi:</strong> <code>Nghiep_Vu.md</code> mô tả actor, luồng học tập và các nhóm nghiệp vụ của ứng dụng hoàn thiện; <code>Project.md</code> được bổ sung liên kết để tài liệu nghiệp vụ có thể được tìm thấy từ product source-of-truth.</td>
      <td><strong>Tạo:</strong> <code>docs/Nghiep_Vu.md</code><br><strong>Sửa:</strong> <code>docs/Project.md</code></td>
    </tr>
    <tr>
      <td>23:52:49</td>
      <td><strong>Mục đích chung:</strong> Tách tài liệu làm việc nội bộ khỏi repository GitHub nhưng vẫn giữ bản local để tránh tiếp tục công khai hoặc đồng bộ thư mục <code>docs</code> trong các commit sau.<br><strong>Tác dụng của file/thay đổi:</strong> <code>.gitignore</code> bỏ qua toàn bộ <code>/docs/</code>; hai file sơ đồ bị ngừng theo dõi để biến mất khỏi GitHub sau khi PR được merge nhưng vẫn có thể tồn tại tại local; change log ghi lại thao tác và trạng thái phục vụ truy vết.</td>
      <td><strong>Sửa:</strong> <code>.gitignore</code><br><strong>Ngừng theo dõi trên Git:</strong> <code>docs/assets/esquilospeak-repository-structure.png</code><br><strong>Ngừng theo dõi trên Git:</strong> <code>docs/assets/esquilospeak-repository-structure.svg</code><br><strong>Sửa local:</strong> <code>docs/Development_Change_Log.md</code></td>
    </tr>
    <tr>
      <td rowspan="4"><strong>2026-07-17</strong></td>
      <td>00:01:16</td>
      <td><strong>Mục đích chung:</strong> Nâng mức chi tiết của development change log để người review hiểu lý do, kết quả mong muốn và vai trò của từng file.<br><strong>Tác dụng của file/thay đổi:</strong> <code>.agent/AGENTS.md</code> quy định cột ngày và cấu trúc nội dung mục đích; <code>Development_Change_Log.md</code> bổ sung cột ngày, cập nhật quy ước và viết lại bản ghi cũ theo cấu trúc chi tiết.</td>
      <td><strong>Sửa:</strong> <code>.agent/AGENTS.md</code><br><strong>Sửa:</strong> <code>docs/Development_Change_Log.md</code></td>
    </tr>
    <tr>
      <td>00:05:18</td>
      <td><strong>Mục đích chung:</strong> Gộp ngày của các thay đổi diễn ra trong cùng một ngày để nhật ký ngắn gọn, dễ quét theo ngày rồi đối chiếu từng thời điểm.<br><strong>Tác dụng của file/thay đổi:</strong> <code>.agent/AGENTS.md</code> chuyển cột ngày sang bên trái cột thời gian và bắt buộc dùng một ô ngày chung cho nhiều bản ghi; <code>Development_Change_Log.md</code> chuyển từ bảng Markdown sang bảng HTML để dùng <code>rowspan</code> gộp ô ngày theo đúng yêu cầu hiển thị.</td>
      <td><strong>Sửa:</strong> <code>.agent/AGENTS.md</code><br><strong>Sửa:</strong> <code>docs/Development_Change_Log.md</code></td>
    </tr>
    <tr>
      <td>00:47:53</td>
      <td><strong>Mục đích chung:</strong> Thiết lập quality gate tự động cho contract và cơ chế cập nhật dependency hằng ngày, đồng thời chuẩn hóa nội dung commit để có đủ thông tin tạo Pull Request rõ ràng.<br><strong>Tác dụng của file/thay đổi:</strong> <code>.github/workflows/ci.yml</code> chạy khi push hoặc mở PR vào <code>develop</code>/<code>main</code>, kiểm tra cú pháp JSON schema và lint OpenAPI; <code>.github/dependabot.yml</code> kiểm tra phiên bản GitHub Actions mỗi ngày và mở PR vào <code>develop</code>; <code>.github/workflows/.gitkeep</code> được xóa vì thư mục workflow đã có file thực; <code>.agent/AGENTS.md</code> bắt buộc commit có title cùng body tiếng Anh mô tả thay đổi, lý do, tác động và validation để dùng làm nội dung PR; change log ghi lại mục đích và tác dụng của cấu hình mới.</td>
      <td><strong>Tạo:</strong> <code>.github/workflows/ci.yml</code><br><strong>Tạo:</strong> <code>.github/dependabot.yml</code><br><strong>Xóa:</strong> <code>.github/workflows/.gitkeep</code><br><strong>Sửa:</strong> <code>.agent/AGENTS.md</code><br><strong>Sửa:</strong> <code>docs/Development_Change_Log.md</code></td>
    </tr>
    <tr>
      <td>00:53:22</td>
      <td><strong>Mục đích chung:</strong> Tách rõ bước soạn đề xuất commit khỏi bước thực thi Git để developer luôn có cơ hội kiểm tra branch, nội dung, phạm vi file và mô tả PR trước khi lịch sử repository bị thay đổi.<br><strong>Tác dụng của file/thay đổi:</strong> <code>.agent/AGENTS.md</code> quy định từ khóa “commit” chỉ kích hoạt chế độ preview, cấm tự động chạy <code>git add</code>, tạo/switch nhánh, commit, push hoặc tạo PR và yêu cầu một xác nhận thực thi riêng; <code>Development_Change_Log.md</code> lưu lại thay đổi quy trình để hỗ trợ truy vết.</td>
      <td><strong>Sửa:</strong> <code>.agent/AGENTS.md</code><br><strong>Sửa:</strong> <code>docs/Development_Change_Log.md</code></td>
    </tr>
    <tr>
      <td rowspan="2"><strong>2026-07-28</strong></td>
      <td>23:15:06</td>
      <td><strong>Mục đích chung:</strong> Hoàn thiện Foundation Sprint có thể build, test và chạy cho Flutter mobile cùng Spring Boot backend, sau đó hiện thực user journey học tập đầu tiên từ catalog đến progress trên PostgreSQL; đồng thời loại bỏ việc tự động tạo Pull Request dependency theo yêu cầu nhưng vẫn giữ quality gate của repository.<br><strong>Tác dụng của file/thay đổi:</strong> Các file root chuẩn hóa ignore, editor, cấu hình mẫu và hướng dẫn vận hành; contract bổ sung learner delivery schema để không lộ đáp án trước attempt; Spring Boot/Gradle, module <code>curriculumcontent</code>/<code>learning</code>, security local/production, Flyway migration và test tạo backend idempotent có boundary được kiểm chứng; Flutter Android/iOS, localization, API service, repository, ViewModel, accessible UI và widget tests tạo luồng học chạy được; Compose cung cấp PostgreSQL local; CI build và test contract/backend/mobile/infrastructure; cấu hình Dependabot bị xóa để dừng bot tạo PR; ADR và tài liệu trạng thái ghi nhận quyết định cùng giới hạn còn lại.</td>
      <td><strong>Tạo:</strong> <code>.editorconfig</code>, <code>.env.example</code><br><strong>Sửa:</strong> <code>.gitignore</code>, <code>README.md</code>, <code>.github/workflows/ci.yml</code><br><strong>Xóa:</strong> <code>.github/dependabot.yml</code><br><strong>Tạo/Sửa:</strong> <code>contracts/schema/lesson-delivery.schema.json</code>, <code>contracts/schema/README.md</code>, <code>contracts/openapi/esquilospeak-learning-v1.yaml</code><br><strong>Tạo:</strong> <code>backend/core-platform/**</code> gồm Gradle Wrapper, application code, configuration, Flyway migration và tests; <strong>Xóa placeholder:</strong> các <code>.gitkeep</code> trong source/resource đã có nội dung<br><strong>Tạo:</strong> <code>apps/mobile/**</code> gồm Android/iOS skeleton, Dart source, l10n và tests; <strong>Xóa placeholder:</strong> các <code>.gitkeep</code> trong mobile đã có nội dung<br><strong>Tạo:</strong> <code>infrastructure/local/compose/compose.yml</code><br><strong>Tạo:</strong> <code>docs/Adr_002_Foundation_And_First_Learning_Slice.md</code><br><strong>Sửa:</strong> <code>docs/Project.md</code>, <code>docs/Tech_Stack_And_Architecture.md</code>, <code>docs/Development_Change_Log.md</code></td>
    </tr>
    <tr>
      <td>23:53:00</td>
      <td><strong>Mục đích chung:</strong> Thiết lập một roadmap thực thi bám sát trạng thái thật của repository, ưu tiên hoàn thiện backend trước Android frontend và loại native iOS khỏi phạm vi hiện tại; đồng thời buộc các lần phát triển sau chỉ cập nhật trạng thái khi có artifact cùng bằng chứng validation, giúp kế hoạch không sai lệch so với code và quyết định đã chấp nhận.<br><strong>Tác dụng của file/thay đổi:</strong> <code>Ke_Hoach.md</code> tách rõ các giai đoạn đã làm, phần còn thiếu, backend completion track, Android frontend track, quality gate và thứ tự sprint; <code>Adr_002_Foundation_And_First_Learning_Slice.md</code> bỏ phụ thuộc diễn giải vào ADR-001 đã được developer chủ động xóa và ghi đúng quyết định Android-first; <code>.agent/AGENTS.md</code> quy định agent phải đọc, thực hiện và cập nhật roadmap có bằng chứng; <code>.agent/SKILL.md</code> đưa kế hoạch vào thứ tự source of truth, đồng bộ architecture boundary và workflow kiểm tra trạng thái.</td>
      <td><strong>Tạo:</strong> <code>docs/Ke_Hoach.md</code><br><strong>Sửa:</strong> <code>docs/Adr_002_Foundation_And_First_Learning_Slice.md</code><br><strong>Sửa:</strong> <code>.agent/AGENTS.md</code><br><strong>Sửa:</strong> <code>.agent/SKILL.md</code></td>
    </tr>
    <tr>
      <td rowspan="3"><strong>2026-07-30</strong></td>
      <td>00:16:17</td>
      <td><strong>Mục đích chung:</strong> Khôi phục khả năng chạy backend quality gate trên GitHub Actions Linux để CI có thể thực sự thực thi Gradle tests và tạo Spring Boot JAR thay vì dừng trước khi Gradle khởi động với exit code 126.<br><strong>Tác dụng của file/thay đổi:</strong> <code>backend/core-platform/gradlew</code> được đổi Git executable mode từ <code>100644</code> sang <code>100755</code>; nội dung script không thay đổi. Quyền thực thi này cho phép step <code>./gradlew test bootJar</code> chạy trên Ubuntu runner. Backend regression suite và <code>bootJar</code> đã được chạy lại thành công bằng JDK 21 ở local.</td>
      <td><strong>Sửa metadata Git:</strong> <code>backend/core-platform/gradlew</code> (<code>100644</code> → <code>100755</code>)</td>
    </tr>
    <tr>
      <td>01:26:15</td>
      <td><strong>Mục đích chung:</strong> Chuẩn hóa bước thu thập thông tin trước khi lập kế hoạch hoặc thay đổi dự án để các quyết định kỹ thuật quan trọng có đủ dữ kiện, đồng thời cung cấp sẵn phương án mặc định thực tế giúp developer đánh giá và triển khai nhanh hơn.<br><strong>Tác dụng của file/thay đổi:</strong> <code>.agent/AGENTS.md</code> yêu cầu agent chỉ đặt các câu hỏi làm rõ cần thiết, đưa đề xuất tốt nhất ngay dưới từng câu hỏi, phân biệt nội dung chặn và không chặn triển khai, đồng thời tiếp tục công việc khi ngữ cảnh đã đầy đủ; nhật ký này ghi nhận thay đổi agent rule để phục vụ truy vết và review.</td>
      <td><strong>Sửa:</strong> <code>.agent/AGENTS.md</code></td>
    </tr>
    <tr>
      <td>01:40:01</td>
      <td><strong>Mục đích chung:</strong> Đồng bộ các nguyên tắc làm việc dùng chung từ cấu hình Codex toàn cục vào phạm vi EsquiloSpeak để agent có cùng baseline về giao tiếp, an toàn, coding, lập kế hoạch, validation và quyết định công nghệ mà không làm mất các quy tắc đặc thù nghiêm ngặt hơn của dự án.<br><strong>Tác dụng của file/thay đổi:</strong> <code>.agent/AGENTS.md</code> bổ sung các nhóm rule dùng chung còn thiếu, giữ nguyên quy trình Git ba tầng, phê duyệt code, roadmap và regression test hiện có, đồng thời chuẩn hóa nhãn <code>Recommended approach / Đề xuất tốt nhất</code>; nhật ký này lưu dấu thay đổi phục vụ truy vết và review.</td>
      <td><strong>Sửa:</strong> <code>.agent/AGENTS.md</code></td>
    </tr>
  </tbody>
</table>
