import SwiftUI
import UserNotifications
import UIKit

// MARK: - 0. AppDelegate (Khóa cứng màn hình dọc & Xử lý Notification)
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        return .portrait
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }
}

@main
struct MatchScheduleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - 1. Models & Formatters
enum AppDateFormatters {
    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
    
    static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM"
        return f
    }()
    
    static let apiDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        return f
    }()
}

struct ApiResponse: Decodable {
    let code: Int?
    let msg: String?
    let data: [FootballMatch]?
}

struct DummyAnchor: Decodable {}

struct FootballMatch: Identifiable, Decodable, Equatable {
    var id: String { "\(matchTimestamp)_\(homeTeam)_\(awayTeam)" }
    
    let categoryName: String
    let leagueName: String
    let homeTeam: String
    let awayTeam: String
    let matchTimestamp: Int64
    let isHot: Bool
    let blvCount: Int
    
    enum CodingKeys: String, CodingKey {
        case categoryName
        case leagueName = "subCateName"
        case homeTeam = "hostName"
        case awayTeam = "guestName"
        case matchTimestamp = "matchTime"
        case hot
        case anchors
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        categoryName = (try? container.decode(String.self, forKey: .categoryName)) ?? ""
        leagueName = (try? container.decode(String.self, forKey: .leagueName))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Giải Khác"
        homeTeam = (try? container.decode(String.self, forKey: .homeTeam))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        awayTeam = (try? container.decode(String.self, forKey: .awayTeam))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        matchTimestamp = (try? container.decode(Int64.self, forKey: .matchTimestamp)) ?? 0
        
        if let hotStr = try? container.decode(String.self, forKey: .hot) {
            isHot = (hotStr == "1")
        } else if let hotInt = try? container.decode(Int.self, forKey: .hot) {
            isHot = (hotInt == 1)
        } else {
            isHot = false
        }
        
        if let anchorsArray = try? container.decode([DummyAnchor].self, forKey: .anchors) {
            blvCount = anchorsArray.count
        } else {
            blvCount = 0
        }
    }
    
    var matchDate: Date {
        Date(timeIntervalSince1970: TimeInterval(matchTimestamp) / 1000.0)
    }
    
    var timeString: String {
        AppDateFormatters.timeFormatter.string(from: matchDate)
    }
    
    var dayDateString: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(matchDate) {
            return "Hôm nay"
        } else if calendar.isDateInTomorrow(matchDate) {
            return "Ngày mai"
        }
        let weekday = calendar.component(.weekday, from: matchDate)
        let thu = ["", "CN", "T2", "T3", "T4", "T5", "T6", "T7"][weekday]
        return "\(thu) \(AppDateFormatters.shortDateFormatter.string(from: matchDate))"
    }
    
    var timeSlotHeader: String {
        "\(timeString) • \(dayDateString)"
    }
    
    // Trận cầu tâm điểm: được đánh dấu Hot từ nguồn hoặc có từ 3 BLV trở lên
    var isSpotlight: Bool {
        isHot || blvCount >= 3
    }
    
    var isLiveOrStartingSoon: Bool {
        let now = Date()
        let startWindow = matchDate.addingTimeInterval(-15 * 60)
        let endWindow = matchDate.addingTimeInterval(125 * 60)
        return now >= startWindow && now <= endWindow
    }
    
    var statusBadgeText: String? {
        let now = Date()
        let diffMinutes = Int(now.timeIntervalSince(matchDate) / 60.0)
        if diffMinutes >= -15 && diffMinutes < 0 {
            return "-\(-diffMinutes)P"
        } else if diffMinutes >= 0 && diffMinutes <= 125 {
            return "LIVE"
        }
        return nil
    }
    
    var isFinished: Bool {
        Date() > matchDate.addingTimeInterval(125 * 60)
    }
}

// MARK: - 2. Hệ thống Màu Sắc & Độ Ưu Tiên Giải Đấu
struct LeagueTheme {
    static func color(for league: String) -> Color {
        let upper = league.uppercased()
        if upper.contains("NGOẠI HẠNG ANH") || upper.contains("PREMIER") || upper.contains("EPL") || upper.contains("ANH") {
            return Color(red: 0.00, green: 0.96, blue: 0.68) // Xanh Mint EPL
        } else if upper.contains("CHAMPIONS") || upper.contains("C1") || upper.contains("EUROPA") || upper.contains("C2") {
            return Color(red: 0.30, green: 0.68, blue: 1.00) // Xanh Dương C1
        } else if upper.contains("LALIGA") || upper.contains("TÂY BAN NHA") || upper.contains("SPA") {
            return Color(red: 1.00, green: 0.52, blue: 0.22) // Cam LaLiga
        } else if upper.contains("SERIE A") || upper.contains("Ý") || upper.contains("ITA") {
            return Color(red: 0.20, green: 0.84, blue: 1.00) // Xanh Ý
        } else if upper.contains("BUNDESLIGA") || upper.contains("ĐỨC") || upper.contains("GER") {
            return Color(red: 1.00, green: 0.34, blue: 0.44) // Đỏ Đức
        } else if upper.contains("LIGUE") || upper.contains("PHÁP") || upper.contains("FRA") {
            return Color(red: 0.75, green: 0.52, blue: 1.00) // Tím Pháp
        } else if upper.contains("V-LEAGUE") || upper.contains("VIỆT NAM") || upper.contains("V.LEAGUE") {
            return Color(red: 1.00, green: 0.85, blue: 0.15) // Vàng VN
        } else if upper.contains("NHẬT") || upper.contains("J-LEAGUE") || upper.contains("J1") || upper.contains("HÀN") || upper.contains("K-LEAGUE") {
            return Color(red: 0.98, green: 0.48, blue: 0.80) // Hồng Đông Á
        }
        
        let palette: [Color] = [
            Color(red: 0.38, green: 0.90, blue: 0.90),
            Color(red: 0.70, green: 0.92, blue: 0.35),
            Color(red: 1.00, green: 0.70, blue: 0.30),
            Color(red: 0.62, green: 0.70, blue: 1.00),
            Color(red: 0.96, green: 0.54, blue: 0.68),
            Color(red: 0.48, green: 0.95, blue: 0.58),
            Color(red: 0.92, green: 0.78, blue: 0.42),
            Color(red: 0.82, green: 0.58, blue: 0.96)
        ]
        let hash = abs(league.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) })
        return palette[hash % palette.count]
    }
    
    // Đẩy các giải đấu tâm điểm lên đầu thanh lọc để chọn 1 chạm
    static func priorityWeight(for league: String) -> Int {
        let upper = league.uppercased()
        if upper.contains("CHAMPIONS") || upper.contains("C1") { return 100 }
        if upper.contains("NGOẠI HẠNG ANH") || upper.contains("PREMIER") || upper.contains("EPL") { return 95 }
        if upper.contains("LALIGA") || upper.contains("TÂY BAN NHA") { return 90 }
        if upper.contains("SERIE A") || upper.contains("VĐQG Ý") { return 88 }
        if upper.contains("BUNDESLIGA") || upper.contains("ĐỨC") { return 86 }
        if upper.contains("LIGUE 1") || upper.contains("PHÁP") { return 84 }
        if upper.contains("EUROPA") || upper.contains("C2") || upper.contains("C3") { return 82 }
        if upper.contains("HẠNG NHẤT ANH") || upper.contains("CHAMPIONSHIP") { return 78 }
        if upper.contains("V-LEAGUE") || upper.contains("VIỆT NAM") { return 75 }
        if upper.contains("J-LEAGUE") || upper.contains("K-LEAGUE") || upper.contains("SAUDI") { return 70 }
        return 10
    }
    
    // Tạo chữ viết tắt 2 ký tự cho Huy hiệu đội bóng
    static func teamInitials(_ name: String) -> String {
        let words = name
            .replacingOccurrences(of: "FC", with: "")
            .replacingOccurrences(of: "CF", with: "")
            .split(separator: " ")
            .map { String($0) }
            .filter { !$0.isEmpty }
        
        if words.count >= 2 {
            let first = words[0].prefix(1)
            let second = words[1].prefix(1)
            return "\(first)\(second)".uppercased()
        } else if let firstWord = words.first {
            return String(firstWord.prefix(2)).uppercased()
        }
        return "FC"
    }
}

// MARK: - 3. Quản lý Thông Báo Nhắc Lịch (15 phút trước giờ bóng lăn)
class NotificationManager {
    static let shared = NotificationManager()
    
    func requestAuthorizationIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
            }
        }
    }
    
    func syncNotification(for match: FootballMatch, state: Int) {
        let center = UNUserNotificationCenter.current()
        let identifier = "match_remind_\(match.id)"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        
        guard state > 0 else { return }
        let triggerDate = match.matchDate.addingTimeInterval(-15 * 60)
        guard triggerDate > Date() else { return }
        
        requestAuthorizationIfNeeded()
        
        let content = UNMutableNotificationContent()
        if state == 2 {
            content.title = "🔥 Sắp vào ca (Ưu tiên): \(match.homeTeam) vs \(match.awayTeam)"
        } else {
            content.title = "📌 Nhắc lịch: \(match.homeTeam) vs \(match.awayTeam)"
        }
        content.body = "\(match.leagueName) • Khởi tranh lúc \(match.timeString) (còn 15 phút)."
        content.sound = .default
        
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: triggerDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }
}

// MARK: - 4. ViewModel
@MainActor
class ScheduleViewModel: ObservableObject {
    @Published var matches: [FootballMatch] = []
    @Published var isLoading = false
    
    // Bộ lọc thông minh
    @Published var selectedDayOffset: Int = 0 // -1: Mọi ngày, 0: Hôm nay, 1: Ngày mai, 2: Ngày kia
    @Published var selectedLeague: String = "Tất cả"
    @Published var filterMode: FilterMode = .all
    @Published var groupByLeague: Bool = false
    @Published var hideFinished: Bool = true
    @Published var searchText: String = ""
    
    // Trạng thái ghim (0: Trống, 1: Theo dõi - Xanh, 2: Phải xem - Cam)
    @Published var savedStates: [String: Int] = [:] {
        didSet {
            UserDefaults.standard.set(savedStates, forKey: "saved_match_states_v2")
        }
    }
    
    enum FilterMode: String, CaseIterable {
        case all = "Tất cả"
        case hot = "Trận Hot"
        case scheduled = "Đã Ghim"
    }
    
    init() {
        if let saved = UserDefaults.standard.dictionary(forKey: "saved_match_states_v2") as? [String: Int] {
            let cutoff = Int64(Date().addingTimeInterval(-48 * 3600).timeIntervalSince1970 * 1000)
            self.savedStates = saved.filter { key, _ in
                if let tsStr = key.split(separator: "_").first, let ts = Int64(tsStr) {
                    return ts >= cutoff
                }
                return true
            }
        }
    }
    
    func toggleState(for match: FootballMatch) {
        let current = savedStates[match.id] ?? 0
        let next = (current + 1) % 3
        if next == 0 {
            savedStates.removeValue(forKey: match.id)
        } else {
            savedStates[match.id] = next
        }
        NotificationManager.shared.syncNotification(for: match, state: next)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }
    
    func state(for match: FootballMatch) -> Int {
        savedStates[match.id] ?? 0
    }
    
    var pinnedCount: Int {
        savedStates.values.filter { $0 > 0 }.count
    }
    
    func conflictingMatchInfo(for match: FootballMatch) -> String? {
        guard state(for: match) > 0 else { return nil }
        let pinnedOthers = matches.filter { state(for: $0) > 0 && $0.id != match.id }
        for other in pinnedOthers {
            if abs(other.matchDate.timeIntervalSince(match.matchDate)) < 105 * 60 {
                return "\(other.homeTeam) vs \(other.awayTeam) (\(other.timeString))"
            }
        }
        return nil
    }
    
    func fetchMatches() async {
        isLoading = true
        var allFetched: [FootballMatch] = []
        
        await withTaskGroup(of: [FootballMatch].self) { group in
            for offset in -1...2 {
                if let targetDate = Calendar.current.date(byAdding: .day, value: offset, to: Date()) {
                    let dateStr = AppDateFormatters.apiDateFormatter.string(from: targetDate)
                    group.addTask {
                        await self.fetchForDateString(dateStr)
                    }
                }
            }
            for await dayMatches in group {
                allFetched.append(contentsOf: dayMatches)
            }
        }
        
        var seen = Set<String>()
        let nowCutoff = Date().addingTimeInterval(-6 * 3600)
        
        let filtered = allFetched
            .filter { $0.categoryName == "Bóng đá" }
            .filter { $0.matchDate >= nowCutoff }
            .filter { seen.insert($0.id).inserted }
            .sorted { $0.matchTimestamp < $1.matchTimestamp }
        
        self.matches = filtered
        self.isLoading = false
    }
    
    private func fetchForDateString(_ dateString: String) async -> [FootballMatch] {
        guard let url = URL(string: "https://json.vnres.co/match/matches_\(dateString).json") else {
            return []
        }
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 12
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let jsonp = String(data: data, encoding: .utf8),
                  let start = jsonp.firstIndex(of: "("),
                  let end = jsonp.lastIndex(of: ")"),
                  start < end else {
                return []
            }
            
            let jsonSub = String(jsonp[jsonp.index(after: start)..<end])
            guard let cleanData = jsonSub.data(using: .utf8) else { return [] }
            
            let decoded = try JSONDecoder().decode(ApiResponse.self, from: cleanData)
            return decoded.data ?? []
        } catch {
            return []
        }
    }
    
    var baseFilteredMatches: [FootballMatch] {
        matches.filter { m in
            if hideFinished && m.isFinished && state(for: m) == 0 {
                return false
            }
            if selectedDayOffset >= 0 {
                guard let targetDay = Calendar.current.date(byAdding: .day, value: selectedDayOffset, to: Date()) else { return true }
                if !Calendar.current.isDate(m.matchDate, inSameDayAs: targetDay) {
                    return false
                }
            }
            switch filterMode {
            case .all:
                break
            case .hot:
                if !m.isSpotlight { return false }
            case .scheduled:
                if state(for: m) == 0 { return false }
            }
            if !searchText.isEmpty {
                let q = searchText.lowercased()
                let combined = "\(m.homeTeam) \(m.awayTeam) \(m.leagueName)".lowercased()
                if !combined.contains(q) { return false }
            }
            return true
        }
    }
    
    var availableLeagues: [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        var hotCountInLeague: [String: Int] = [:]
        for m in baseFilteredMatches {
            counts[m.leagueName, default: 0] += 1
            if m.isSpotlight {
                hotCountInLeague[m.leagueName, default: 0] += 1
            }
        }
        let sorted = counts.map { (name: $0.key, count: $0.value) }
            .sorted {
                let p1 = LeagueTheme.priorityWeight(for: $0.name)
                let p2 = LeagueTheme.priorityWeight(for: $1.name)
                if p1 != p2 { return p1 > p2 }
                let h1 = hotCountInLeague[$0.name, default: 0]
                let h2 = hotCountInLeague[$1.name, default: 0]
                if h1 != h2 { return h1 > h2 }
                if $0.count != $1.count { return $0.count > $1.count }
                return $0.name < $1.name
            }
        return [("Tất cả", baseFilteredMatches.count)] + sorted
    }
    
    var displayedMatches: [FootballMatch] {
        if selectedLeague == "Tất cả" {
            return baseFilteredMatches
        }
        return baseFilteredMatches.filter { $0.leagueName == selectedLeague }
    }
    
    var matchesGroupedByTimeSlot: [(slot: String, items: [FootballMatch])] {
        var groups: [(slot: String, items: [FootballMatch])] = []
        for match in displayedMatches {
            let slot = match.timeSlotHeader
            if let lastIndex = groups.indices.last, groups[lastIndex].slot == slot {
                groups[lastIndex].items.append(match)
            } else {
                groups.append((slot: slot, items: [match]))
            }
        }
        return groups
    }
}

// MARK: - 5. Giao diện Chính (Ultra-Compact Top Bar & High-Contrast Feed)
struct ContentView: View {
    @StateObject private var vm = ScheduleViewModel()
    @State private var isSearchExpanded = false
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        ZStack {
            // Nền chuẩn OLED Dark
            Color(red: 0.04, green: 0.05, blue: 0.08).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // TẦNG 1: Thanh Tiêu Đề Siêu Gọn + Công Cụ
                compactTopHeader
                
                // Thanh tìm kiếm thu/mở linh hoạt (Chỉ hiện khi cần tìm)
                if isSearchExpanded {
                    collapsibleSearchBar
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // TẦNG 2: Thanh Gộp (Ngày + Hot + Đã Ghim) trên cùng 1 dòng
                unifiedPrimaryFilterBar
                
                // TẦNG 3: Dải Pill Giải Đấu ưu tiên giải lớn
                compactLeagueStrip
                
                Divider()
                    .background(Color.white.opacity(0.08))
                    .padding(.top, 6)
                
                // DANH SÁCH TRẬN ĐẤU (Chiếm tối đa diện tích màn hình)
                if vm.isLoading && vm.matches.isEmpty {
                    Spacer()
                    ProgressView("Đang đồng bộ lịch làm việc...")
                        .font(.footnote)
                        .tint(.cyan)
                    Spacer()
                } else if vm.displayedMatches.isEmpty {
                    emptyStateView
                } else {
                    matchScheduleList
                }
            }
        }
        .task {
            NotificationManager.shared.requestAuthorizationIfNeeded()
            await vm.fetchMatches()
        }
    }
    
    // MARK: - Cụm Header Siêu Gọn
    private var compactTopHeader: some View {
        HStack(spacing: 10) {
            // Logo mini + Tên ứng dụng "Giờ làm việc"
            HStack(spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(
                            LinearGradient(
                                colors: [Color.cyan, Color.blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 24, height: 24)
                    Image(systemName: "clock.badge.checkmark.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.black)
                }
                
                Text("Giờ làm việc")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                
                Text("\(vm.displayedMatches.count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.cyan.opacity(0.18))
                    .foregroundStyle(.cyan)
                    .clipShape(Capsule())
            }
            
            Spacer()
            
            // Cụm nút điều khiển 1 chạm
            HStack(spacing: 6) {
                // Nút Tìm kiếm
                Button {
                    withAnimation(.snappy(duration: 0.22)) {
                        isSearchExpanded.toggle()
                        if isSearchExpanded {
                            isSearchFocused = true
                        } else {
                            vm.searchText = ""
                            isSearchFocused = false
                        }
                    }
                } label: {
                    Image(systemName: isSearchExpanded || !vm.searchText.isEmpty ? "magnifyingglass.circle.fill" : "magnifyingglass")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 30, height: 28)
                        .background(isSearchExpanded || !vm.searchText.isEmpty ? Color.cyan.opacity(0.25) : Color.white.opacity(0.07))
                        .foregroundStyle(isSearchExpanded || !vm.searchText.isEmpty ? .cyan : .white.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                // Nút Đổi chế độ gom nhóm (Theo Giờ / Theo Giải)
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        vm.groupByLeague.toggle()
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: vm.groupByLeague ? "trophy.fill" : "clock.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text(vm.groupByLeague ? "Giải" : "Giờ")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 28)
                    .background(Color.white.opacity(0.07))
                    .foregroundStyle(vm.groupByLeague ? .yellow : .cyan)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                // Nút Ẩn/Hiện trận đã xong
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        vm.hideFinished.toggle()
                    }
                } label: {
                    Image(systemName: vm.hideFinished ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 30, height: 28)
                        .background(Color.white.opacity(0.07))
                        .foregroundStyle(vm.hideFinished ? .cyan : .gray)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                // Nút Làm mới
                Button {
                    Task { await vm.fetchMatches() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 30, height: 28)
                        .background(Color.white.opacity(0.07))
                        .foregroundStyle(.white.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 6)
    }
    
    private var collapsibleSearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            
            TextField("Tìm nhanh tên đội, giải đấu...", text: $vm.searchText)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .focused($isSearchFocused)
                .submitLabel(.search)
            
            if !vm.searchText.isEmpty {
                Button {
                    vm.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }
    
    // MARK: - Thanh Lọc Gộp: Chế độ (Hot/Ghim) + Ngày trên 1 hàng ngang
    private var unifiedPrimaryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // Nhóm 1: Chọn Ngày
                compactDayPill(title: "Hôm nay", offset: 0)
                compactDayPill(title: "Ngày mai", offset: 1)
                compactDayPill(title: "Ngày kia", offset: 2)
                compactDayPill(title: "Mọi ngày", offset: -1)
                
                // Vạch ngăn cách mảnh
                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 1, height: 18)
                    .padding(.horizontal, 2)
                
                // Nhóm 2: Lọc nhanh Trận Hot & Đã Ghim
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        vm.filterMode = (vm.filterMode == .hot) ? .all : .hot
                        vm.selectedLeague = "Tất cả"
                    }
                } label: {
                    let isHotActive = (vm.filterMode == .hot)
                    HStack(spacing: 4) {
                        Text("🔥")
                            .font(.system(size: 11))
                        Text("Trận Hot")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        isHotActive
                        ? LinearGradient(colors: [Color.orange, Color.red], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [Color.orange.opacity(0.14), Color.red.opacity(0.10)], startPoint: .leading, endPoint: .trailing)
                    )
                    .foregroundStyle(isHotActive ? .white : .orange)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(isHotActive ? Color.yellow : Color.orange.opacity(0.4), lineWidth: 1)
                    )
                }
                
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        vm.filterMode = (vm.filterMode == .scheduled) ? .all : .scheduled
                        vm.selectedLeague = "Tất cả"
                    }
                } label: {
                    let isPinActive = (vm.filterMode == .scheduled)
                    let count = vm.pinnedCount
                    HStack(spacing: 4) {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text(count > 0 ? "Đã Ghim (\(count))" : "Đã Ghim")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(isPinActive ? Color.green.opacity(0.28) : Color.white.opacity(0.06))
                    .foregroundStyle(isPinActive ? .green : .white.opacity(0.8))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(isPinActive ? Color.green : Color.white.opacity(0.12), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.bottom, 6)
    }
    
    private func compactDayPill(title: String, offset: Int) -> some View {
        let isSelected = (vm.selectedDayOffset == offset)
        return Button {
            withAnimation(.snappy(duration: 0.2)) {
                vm.selectedDayOffset = offset
                vm.selectedLeague = "Tất cả"
            }
        } label: {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? Color.cyan.opacity(0.22) : Color.white.opacity(0.05))
                .foregroundStyle(isSelected ? .cyan : .gray)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.cyan.opacity(0.75) : Color.clear, lineWidth: 1)
                )
        }
    }
    
    // MARK: - Dải Giải Đấu Gọn Nhẹ
    private var compactLeagueStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(vm.availableLeagues, id: \.name) { item in
                    let isSelected = (vm.selectedLeague == item.name)
                    let themeColor = item.name == "Tất cả" ? Color.cyan : LeagueTheme.color(for: item.name)
                    
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            vm.selectedLeague = item.name
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if item.name != "Tất cả" {
                                Circle()
                                    .fill(themeColor)
                                    .frame(width: 6, height: 6)
                            }
                            Text(item.name)
                                .font(.system(size: 11.5, weight: isSelected ? .bold : .semibold))
                                .lineLimit(1)
                            Text("\(item.count)")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .padding(.horizontal, 4.5)
                                .padding(.vertical, 1)
                                .background(Color.black.opacity(0.45))
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4.5)
                        .background(isSelected ? themeColor.opacity(0.24) : Color.white.opacity(0.04))
                        .foregroundStyle(isSelected ? themeColor : .white.opacity(0.85))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? themeColor : Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.horizontal, 12)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: vm.filterMode == .scheduled ? "pin.slash" : "calendar.badge.exclamationmark")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(vm.filterMode == .scheduled
                 ? "Chưa có ca làm việc nào được ghim.\nChạm vào bất kỳ trận nào để ghim & nhận báo thức trước 15 phút."
                 : "Không có trận đấu nào khớp với bộ lọc hiện tại.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }
    
    // MARK: - Danh Sách Lịch Thi Đấu
    private var matchScheduleList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if vm.groupByLeague {
                    // CHẾ ĐỘ 1: GOM THEO GIẢI ĐẤU (Ưu tiên giải lớn lên đầu)
                    let grouped = Dictionary(grouping: vm.displayedMatches, by: { $0.leagueName })
                    let sortedLeagues = grouped.keys.sorted {
                        let p1 = LeagueTheme.priorityWeight(for: $0)
                        let p2 = LeagueTheme.priorityWeight(for: $1)
                        if p1 != p2 { return p1 > p2 }
                        return $0 < $1
                    }
                    
                    ForEach(sortedLeagues, id: \.self) { league in
                        let leagueColor = LeagueTheme.color(for: league)
                        let leagueMatches = grouped[league] ?? []
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 7) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(leagueColor)
                                    .frame(width: 4, height: 14)
                                Text(league.uppercased())
                                    .font(.system(size: 12, weight: .heavy))
                                    .tracking(0.4)
                                    .foregroundStyle(leagueColor)
                                Spacer()
                                Text("\(leagueMatches.count) trận")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(leagueColor.opacity(0.15))
                                    .foregroundStyle(leagueColor)
                                    .clipShape(Capsule())
                            }
                            .padding(.horizontal, 4)
                            .padding(.top, 4)
                            
                            ForEach(leagueMatches) { match in
                                MatchRowCard(
                                    match: match,
                                    markState: vm.state(for: match),
                                    conflictInfo: vm.conflictingMatchInfo(for: match)
                                ) {
                                    vm.toggleState(for: match)
                                }
                            }
                        }
                    }
                } else {
                    // CHẾ ĐỘ 2: GOM THEO KHUNG GIỜ (Mặc định - Dễ lướt chọn kèo)
                    ForEach(vm.matchesGroupedByTimeSlot, id: \.slot) { group in
                        VStack(alignment: .leading, spacing: 6) {
                            let hotInSlot = group.items.filter { $0.isSpotlight }.count
                            
                            HStack(spacing: 6) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.cyan)
                                Text(group.slot)
                                    .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.cyan)
                                
                                if group.items.count > 1 {
                                    Text("\(group.items.count) trận")
                                        .font(.system(size: 10, weight: .semibold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 1.5)
                                        .background(Color.white.opacity(0.08))
                                        .foregroundStyle(.secondary)
                                        .clipShape(Capsule())
                                }
                                
                                if hotInSlot > 0 {
                                    Text("🔥 \(hotInSlot) Hot")
                                        .font(.system(size: 10, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 1.5)
                                        .background(Color.orange.opacity(0.18))
                                        .foregroundStyle(.orange)
                                        .clipShape(Capsule())
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 4)
                            .padding(.top, 4)
                            
                            ForEach(group.items) { match in
                                MatchRowCard(
                                    match: match,
                                    markState: vm.state(for: match),
                                    conflictInfo: vm.conflictingMatchInfo(for: match)
                                ) {
                                    vm.toggleState(for: match)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 28)
        }
        .refreshable {
            await vm.fetchMatches()
        }
    }
}

// MARK: - 6. Thẻ Trận Đấu Chuẩn Quốc Tế (Dễ Đọc Tên Đội & Nổi Bật Trận Hot)
struct MatchRowCard: View {
    let match: FootballMatch
    let markState: Int // 0: Không, 1: Theo dõi (Xanh), 2: Phải xem (Cam)
    let conflictInfo: String?
    let onTap: () -> Void
    
    var body: some View {
        let leagueColor = LeagueTheme.color(for: match.leagueName)
        let isHotMatch = match.isSpotlight
        
        Button(action: onTap) {
            HStack(spacing: 0) {
                // 1. Thanh Điểm Nhấn Bên Trái (Gradient Rực Rỡ cho Trận HOT)
                Rectangle()
                    .fill(leftAccentGradient(leagueColor: leagueColor, isHot: isHotMatch))
                    .frame(width: isHotMatch || markState > 0 ? 4.5 : 3.5)
                
                // 2. Cột Giờ Thi Đấu (Đã thu gọn kích thước tinh tế 56pt)
                VStack(spacing: 2) {
                    Text(match.timeString)
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(match.isLiveOrStartingSoon ? .white : .white.opacity(0.92))
                    
                    Text(match.dayDateString)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(match.isLiveOrStartingSoon ? .white.opacity(0.9) : .secondary)
                        .lineLimit(1)
                    
                    if let statusText = match.statusBadgeText {
                        Text(statusText)
                            .font(.system(size: 8.5, weight: .black, design: .rounded))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.black.opacity(0.4))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .padding(.top, 2)
                    }
                }
                .frame(width: 56)
                .frame(maxHeight: .infinity)
                .padding(.vertical, 8)
                .background(
                    match.isLiveOrStartingSoon
                    ? Color(red: 0.90, green: 0.12, blue: 0.45)
                    : Color.white.opacity(0.02)
                )
                
                // Vạch ngăn dọc mảnh
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 1)
                
                // 3. Cột Trung Tâm: Giải đấu + Tên 2 Đội Bóng (Rộng rãi, tương phản cao)
                VStack(alignment: .leading, spacing: 6) {
                    // Dòng Header: Tên giải đấu rõ nét + Nhãn HOT nổi bật + Số BLV
                    HStack(spacing: 5) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(leagueColor)
                                .frame(width: 6, height: 6)
                            Text(match.leagueName.uppercased())
                                .font(.system(size: 11, weight: .heavy))
                                .tracking(0.2)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(leagueColor.opacity(0.16))
                        .foregroundStyle(leagueColor)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        
                        if isHotMatch {
                            HStack(spacing: 2) {
                                Text("🔥")
                                    .font(.system(size: 9))
                                Text("HOT")
                                    .font(.system(size: 9.5, weight: .black, design: .rounded))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(
                                LinearGradient(
                                    colors: [Color.orange, Color.red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .shadow(color: .orange.opacity(0.4), radius: 3, x: 0, y: 1)
                        }
                        
                        Spacer(minLength: 4)
                        
                        if match.blvCount > 0 {
                            HStack(spacing: 2.5) {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 8.5))
                                Text("\(match.blvCount)")
                                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(blvBadgeColor.opacity(0.18))
                            .foregroundStyle(blvBadgeColor)
                            .clipShape(Capsule())
                        }
                    }
                    
                    // Khu vực Tên 2 Đội Bóng: Cỡ chữ 15.5pt sắc nét + Monogram Badge
                    VStack(alignment: .leading, spacing: 5) {
                        // Đội Chủ Nhà
                        HStack(spacing: 7) {
                            teamBadge(name: match.homeTeam, tint: leagueColor, isHome: true)
                            
                            Text(match.homeTeam)
                                .font(.system(size: 15.5, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                            
                            Spacer(minLength: 0)
                        }
                        
                        // Đội Khách
                        HStack(spacing: 7) {
                            teamBadge(name: match.awayTeam, tint: Color.cyan, isHome: false)
                            
                            Text(match.awayTeam)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color(red: 0.90, green: 0.93, blue: 0.98))
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                            
                            Spacer(minLength: 0)
                        }
                    }
                    
                    // Cảnh báo nếu trùng giờ với trận đã ghim khác
                    if let conflict = conflictInfo {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 9.5))
                            Text("Trùng ca: \(conflict)")
                                .font(.system(size: 10, weight: .semibold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(.orange)
                        .padding(.top, 1)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                
                // 4. Cột Trạng Thái Ghim (Thu gọn 44pt)
                VStack(spacing: 2) {
                    if markState == 2 {
                        Image(systemName: "bell.and.waves.left.and.right.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.orange)
                        Text("Ưu tiên")
                            .font(.system(size: 8.5, weight: .heavy))
                            .foregroundStyle(.orange)
                    } else if markState == 1 {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.green)
                        Text("Đã ghim")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: isHotMatch ? "flame.fill" : "bell")
                            .font(.system(size: 14))
                            .foregroundStyle(isHotMatch ? .orange.opacity(0.65) : .gray.opacity(0.30))
                    }
                }
                .frame(width: 44)
            }
            .background(cardBackground(isHot: isHotMatch))
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .overlay(
                RoundedRectangle(cornerRadius: 11)
                    .stroke(cardBorderColor(leagueColor: leagueColor, isHot: isHotMatch), lineWidth: (markState > 0 || isHotMatch) ? 1.2 : 0.6)
            )
        }
        .buttonStyle(.plain)
    }
    
    // Huy hiệu Monogram giúp mắt định vị nhanh 2 dòng Đội Chủ Nhà & Đội Khách
    private func teamBadge(name: String, tint: Color, isHome: Bool) -> some View {
        Text(LeagueTheme.teamInitials(name))
            .font(.system(size: 8.5, weight: .heavy, design: .rounded))
            .frame(width: 20, height: 20)
            .background(isHome ? tint.opacity(0.24) : Color.white.opacity(0.09))
            .foregroundStyle(isHome ? tint : Color.white.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(isHome ? tint.opacity(0.5) : Color.white.opacity(0.15), lineWidth: 0.7)
            )
    }
    
    private var blvBadgeColor: Color {
        if match.blvCount >= 5 { return Color(red: 1.0, green: 0.38, blue: 0.38) }
        if match.blvCount >= 3 { return Color.orange }
        return Color.gray
    }
    
    @ViewBuilder
    private func cardBackground(isHot: Bool) -> some View {
        if markState == 2 {
            LinearGradient(
                colors: [Color.orange.opacity(0.20), Color(red: 0.12, green: 0.10, blue: 0.14)],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else if markState == 1 {
            LinearGradient(
                colors: [Color.green.opacity(0.15), Color(red: 0.09, green: 0.12, blue: 0.14)],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else if isHot {
            // Nền thẻ Trận HOT có ánh Hổ Phách nổi bật ngay khi lướt qua
            LinearGradient(
                colors: [
                    Color(red: 0.21, green: 0.12, blue: 0.10),
                    Color(red: 0.11, green: 0.11, blue: 0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            Color(red: 0.09, green: 0.10, blue: 0.14)
        }
    }
    
    private func leftAccentGradient(leagueColor: Color, isHot: Bool) -> LinearGradient {
        if markState == 2 {
            return LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)
        }
        if markState == 1 {
            return LinearGradient(colors: [.green, .mint], startPoint: .top, endPoint: .bottom)
        }
        if isHot {
            return LinearGradient(colors: [.yellow, .orange, .red], startPoint: .top, endPoint: .bottom)
        }
        return LinearGradient(colors: [leagueColor, leagueColor.opacity(0.65)], startPoint: .top, endPoint: .bottom)
    }
    
    private func cardBorderColor(leagueColor: Color, isHot: Bool) -> Color {
        if markState == 2 { return .orange.opacity(0.9) }
        if markState == 1 { return .green.opacity(0.8) }
        if isHot { return .orange.opacity(0.55) }
        return leagueColor.opacity(0.20)
    }
}
