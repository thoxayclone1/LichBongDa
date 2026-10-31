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
    
    // Khóa cứng hướng dọc (Portrait) 100% trên mọi màn hình
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        return .portrait
    }
    
    // Cho phép hiện Banner + Âm thanh nhắc lịch ngay cả khi đang mở app
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

// MARK: - 1. Models
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
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: matchDate)
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
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM"
        return "\(thu), \(formatter.string(from: matchDate))"
    }
    
    var timeSlotHeader: String {
        "\(timeString) • \(dayDateString)"
    }
    
    // Đang diễn ra hoặc còn dưới 15 phút là bóng lăn
    var isLiveOrStartingSoon: Bool {
        let now = Date()
        let startWindow = matchDate.addingTimeInterval(-15 * 60)
        let endWindow = matchDate.addingTimeInterval(125 * 60)
        return now >= startWindow && now <= endWindow
    }
    
    // Phút thứ mấy của trận đấu (nếu đang đá)
    var statusBadgeText: String? {
        let now = Date()
        let diffMinutes = Int(now.timeIntervalSince(matchDate) / 60.0)
        if diffMinutes >= -15 && diffMinutes < 0 {
            return "CÒN \(-diffMinutes)P"
        } else if diffMinutes >= 0 && diffMinutes <= 125 {
            return "ĐANG ĐÁ"
        }
        return nil
    }
    
    var isFinished: Bool {
        Date() > matchDate.addingTimeInterval(125 * 60)
    }
}

// MARK: - 2. Hệ thống Màu Sắc & Nhãn Giải Đấu
struct LeagueTheme {
    static func color(for league: String) -> Color {
        let upper = league.uppercased()
        if upper.contains("NGOẠI HẠNG ANH") || upper.contains("PREMIER") || upper.contains("EPL") || upper.contains("ANH") {
            return Color(red: 0.00, green: 0.96, blue: 0.64) // Xanh Mint EPL
        } else if upper.contains("CHAMPIONS") || upper.contains("C1") || upper.contains("EUROPA") || upper.contains("C2") {
            return Color(red: 0.25, green: 0.65, blue: 1.00) // Xanh Dương C1
        } else if upper.contains("LALIGA") || upper.contains("TÂY BAN NHA") || upper.contains("SPA") {
            return Color(red: 1.00, green: 0.48, blue: 0.20) // Cam Đỏ LaLiga
        } else if upper.contains("SERIE A") || upper.contains("Ý") || upper.contains("ITA") {
            return Color(red: 0.15, green: 0.82, blue: 1.00) // Xanh Lam Ý
        } else if upper.contains("BUNDESLIGA") || upper.contains("ĐỨC") || upper.contains("GER") {
            return Color(red: 1.00, green: 0.28, blue: 0.40) // Đỏ Đức
        } else if upper.contains("LIGUE") || upper.contains("PHÁP") || upper.contains("FRA") {
            return Color(red: 0.72, green: 0.48, blue: 1.00) // Tím Pháp
        } else if upper.contains("V-LEAGUE") || upper.contains("VIỆT NAM") || upper.contains("V.LEAGUE") {
            return Color(red: 1.00, green: 0.84, blue: 0.10) // Vàng VN
        } else if upper.contains("NHẬT") || upper.contains("J-LEAGUE") || upper.contains("J1") || upper.contains("HÀN") || upper.contains("K-LEAGUE") {
            return Color(red: 0.98, green: 0.45, blue: 0.78) // Hồng Đông Á
        }
        
        // Bảng 8 màu Neon độ tương phản cao trên nền OLED tối
        let palette: [Color] = [
            Color(red: 0.35, green: 0.88, blue: 0.88),
            Color(red: 0.68, green: 0.92, blue: 0.32),
            Color(red: 1.00, green: 0.68, blue: 0.28),
            Color(red: 0.60, green: 0.68, blue: 1.00),
            Color(red: 0.95, green: 0.52, blue: 0.65),
            Color(red: 0.45, green: 0.95, blue: 0.55),
            Color(red: 0.90, green: 0.75, blue: 0.40),
            Color(red: 0.80, green: 0.55, blue: 0.95)
        ]
        let hash = abs(league.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) })
        return palette[hash % palette.count]
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
        
        // Xóa thông báo cũ của trận này trước
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        
        // Nếu bỏ ghim (state == 0) thì dừng
        guard state > 0 else { return }
        
        // Tính thời điểm trước khi đá 15 phút
        let triggerDate = match.matchDate.addingTimeInterval(-15 * 60)
        guard triggerDate > Date() else { return }
        
        requestAuthorizationIfNeeded()
        
        let content = UNMutableNotificationContent()
        if state == 2 {
            content.title = "🔥 Sắp đá (Phải xem): \(match.homeTeam) vs \(match.awayTeam)"
        } else {
            content.title = "📌 Nhắc lịch: \(match.homeTeam) vs \(match.awayTeam)"
        }
        content.body = "Giải \(match.leagueName) • Khởi tranh lúc \(match.timeString) (còn 15 phút)."
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
    
    // Bộ lọc
    @Published var selectedDayOffset: Int = 0 // -1: Mọi ngày, 0: Hôm nay, 1: Ngày mai, 2: Ngày kia
    @Published var selectedLeague: String = "Tất cả"
    @Published var filterMode: FilterMode = .all
    @Published var groupByLeague: Bool = false // false: Chia theo Khung giờ, true: Chia theo Giải đấu
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
        case scheduled = "Lịch Đã Ghim"
    }
    
    init() {
        if let saved = UserDefaults.standard.dictionary(forKey: "saved_match_states_v2") as? [String: Int] {
            // Dọn dẹp các trận cũ hơn 2 ngày trước để bộ nhớ luôn sạch
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
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    func state(for match: FootballMatch) -> Int {
        savedStates[match.id] ?? 0
    }
    
    // Tìm trận đã ghim khác bị trùng khung giờ (cách nhau dưới 105 phút)
    func conflictingMatchInfo(for match: FootballMatch) -> String? {
        let myState = state(for: match)
        guard myState > 0 else { return nil }
        
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
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        
        // Quét từ Hôm qua (-1) để không sót các trận rạng sáng nay, tới Ngày kia (+2)
        await withTaskGroup(of: [FootballMatch].self) { group in
            for offset in -1...2 {
                if let targetDate = Calendar.current.date(byAdding: .day, value: offset, to: Date()) {
                    let dateStr = formatter.string(from: targetDate)
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
        let nowCutoff = Date().addingTimeInterval(-6 * 3600) // Bỏ qua trận đã xong từ hơn 6 tiếng trước
        
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
            // 1. Ẩn trận đã kết thúc (trừ khi trận đó đang được ghim)
            if hideFinished && m.isFinished && state(for: m) == 0 {
                return false
            }
            // 2. Lọc theo ngày thực tế trên lịch
            if selectedDayOffset >= 0 {
                guard let targetDay = Calendar.current.date(byAdding: .day, value: selectedDayOffset, to: Date()) else { return true }
                if !Calendar.current.isDate(m.matchDate, inSameDayAs: targetDay) {
                    return false
                }
            }
            // 3. Lọc theo chế độ xem
            switch filterMode {
            case .all:
                break
            case .hot:
                if !(m.isHot || m.blvCount >= 3) { return false }
            case .scheduled:
                if state(for: m) == 0 { return false }
            }
            // 4. Lọc theo từ khóa tìm kiếm
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
        for m in baseFilteredMatches {
            counts[m.leagueName, default: 0] += 1
        }
        let sorted = counts.map { (name: $0.key, count: $0.value) }
            .sorted {
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
    
    // Gom nhóm theo Khung giờ để dễ xếp lịch xem
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

// MARK: - 5. Giao diện Chính
struct ContentView: View {
    @StateObject private var vm = ScheduleViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Nền tối sâu chuẩn màn hình OLED iPhone XS Max
                Color(red: 0.05, green: 0.06, blue: 0.09).ignoresSafeArea()
                
                VStack(spacing: 10) {
                    daySelectorBar
                    modePickerBar
                    leagueFilterStrip
                    
                    if vm.isLoading && vm.matches.isEmpty {
                        Spacer()
                        ProgressView("Đang tải lịch thi đấu...")
                            .tint(.cyan)
                        Spacer()
                    } else if vm.displayedMatches.isEmpty {
                        emptyStateView
                    } else {
                        matchScheduleList
                    }
                }
            }
            .navigationTitle("Lịch Thi Đấu")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $vm.searchText, prompt: "Tìm đội bóng, giải đấu...")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(.snappy) {
                            vm.hideFinished.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: vm.hideFinished ? "eye.slash.fill" : "eye.fill")
                            Text(vm.hideFinished ? "Ẩn trận cũ" : "Hiện tất cả")
                                .font(.caption2.bold())
                        }
                        .foregroundStyle(vm.hideFinished ? .cyan : .gray)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        // Chuyển đổi giữa Xem theo Khung Giờ và Xem theo Giải Đấu
                        Button {
                            withAnimation(.snappy) {
                                vm.groupByLeague.toggle()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: vm.groupByLeague ? "trophy.fill" : "clock.fill")
                                Text(vm.groupByLeague ? "Theo giải" : "Theo giờ")
                                    .font(.caption2.bold())
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                            .foregroundStyle(vm.groupByLeague ? .yellow : .cyan)
                        }
                        
                        Button {
                            Task { await vm.fetchMatches() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                }
            }
            .task {
                NotificationManager.shared.requestAuthorizationIfNeeded()
                await vm.fetchMatches()
            }
        }
    }
    
    // MARK: Subviews
    private var daySelectorBar: some View {
        HStack(spacing: 6) {
            dayButton(title: "Tất cả", offset: -1)
            dayButton(title: "Hôm nay", offset: 0)
            dayButton(title: "Ngày mai", offset: 1)
            dayButton(title: "Ngày kia", offset: 2)
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }
    
    private func dayButton(title: String, offset: Int) -> some View {
        let isSelected = (vm.selectedDayOffset == offset)
        return Button {
            withAnimation(.snappy) {
                vm.selectedDayOffset = offset
                vm.selectedLeague = "Tất cả"
            }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(isSelected ? Color.cyan.opacity(0.22) : Color.white.opacity(0.05))
                .foregroundStyle(isSelected ? .cyan : .gray)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.cyan.opacity(0.65) : Color.clear, lineWidth: 1)
                )
        }
    }
    
    private var modePickerBar: some View {
        Picker("Chế độ", selection: $vm.filterMode) {
            ForEach(ScheduleViewModel.FilterMode.allCases, id: \.self) { mode in
                if mode == .scheduled {
                    let count = vm.savedStates.values.filter { $0 > 0 }.count
                    Text(count > 0 ? "Đã Ghim (\(count))" : "Đã Ghim").tag(mode)
                } else {
                    Text(mode.rawValue).tag(mode)
                }
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 12)
        .onChange(of: vm.filterMode) { _, _ in
            vm.selectedLeague = "Tất cả"
        }
    }
    
    private var leagueFilterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(vm.availableLeagues, id: \.name) { item in
                    let isSelected = (vm.selectedLeague == item.name)
                    let themeColor = item.name == "Tất cả" ? Color.cyan : LeagueTheme.color(for: item.name)
                    
                    Button {
                        withAnimation(.snappy) {
                            vm.selectedLeague = item.name
                        }
                    } label: {
                        HStack(spacing: 5) {
                            if item.name != "Tất cả" {
                                Circle()
                                    .fill(themeColor)
                                    .frame(width: 7, height: 7)
                            }
                            Text(item.name)
                                .font(.system(size: 12, weight: .semibold))
                            Text("\(item.count)")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isSelected ? themeColor.opacity(0.24) : Color.white.opacity(0.05))
                        .foregroundStyle(isSelected ? themeColor : .white.opacity(0.85))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? themeColor : Color.white.opacity(0.1), lineWidth: 1)
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
            Image(systemName: vm.filterMode == .scheduled ? "bookmark.slash" : "calendar.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(vm.filterMode == .scheduled
                 ? "Bạn chưa ghim trận đấu nào.\nChạm vào bất kỳ trận nào để ghim & nhận thông báo trước 15 phút."
                 : "Không có trận đấu nào trong khung lọc này.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }
    
    private var matchScheduleList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if vm.groupByLeague {
                    // CHẾ ĐỘ 1: GOM THEO GIẢI ĐẤU
                    let grouped = Dictionary(grouping: vm.displayedMatches, by: { $0.leagueName })
                    let sortedLeagues = grouped.keys.sorted()
                    
                    ForEach(sortedLeagues, id: \.self) { league in
                        let leagueColor = LeagueTheme.color(for: league)
                        let leagueMatches = grouped[league] ?? []
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(leagueColor)
                                    .frame(width: 4, height: 16)
                                Text(league.uppercased())
                                    .font(.system(size: 13, weight: .heavy))
                                    .foregroundStyle(leagueColor)
                                Spacer()
                                Text("\(leagueMatches.count) trận")
                                    .font(.caption2.bold())
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
                    // CHẾ ĐỘ 2: GOM THEO KHUNG GIỜ (Mặc định - Tối ưu xếp lịch xem)
                    ForEach(vm.matchesGroupedByTimeSlot, id: \.slot) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "clock.badge.checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.cyan)
                                Text(group.slot)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(.cyan)
                                
                                if group.items.count > 1 {
                                    Text("\(group.items.count) trận cùng giờ")
                                        .font(.system(size: 10, weight: .semibold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.white.opacity(0.08))
                                        .foregroundStyle(.secondary)
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
            .padding(.horizontal, 12)
            .padding(.bottom, 28)
        }
        .refreshable {
            await vm.fetchMatches()
        }
    }
}

// MARK: - 6. Thẻ Trận Đấu (Match Card)
struct MatchRowCard: View {
    let match: FootballMatch
    let markState: Int // 0: Không, 1: Theo dõi (Xanh), 2: Phải xem (Cam)
    let conflictInfo: String?
    let onTap: () -> Void
    
    var body: some View {
        let leagueColor = LeagueTheme.color(for: match.leagueName)
        
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Thanh màu đặc trưng của Giải Đấu (hoặc màu Ghim) bên trái
                Rectangle()
                    .fill(accentBarColor(defaultColor: leagueColor))
                    .frame(width: 5)
                
                // Cột Giờ Thi Đấu
                VStack(spacing: 3) {
                    Text(match.timeString)
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(match.isLiveOrStartingSoon ? .white : .primary)
                    
                    Text(match.dayDateString)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(match.isLiveOrStartingSoon ? .white.opacity(0.9) : .secondary)
                    
                    if let statusText = match.statusBadgeText {
                        Text(statusText)
                            .font(.system(size: 8, weight: .black))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.35))
                            .clipShape(Capsule())
                            .foregroundStyle(.white)
                            .padding(.top, 1)
                    }
                }
                .frame(width: 76)
                .padding(.vertical, 10)
                .background(
                    match.isLiveOrStartingSoon
                    ? Color(red: 0.95, green: 0.10, blue: 0.52) // Hồng đậm báo hiệu đang/sắp đá
                    : Color.white.opacity(0.025)
                )
                
                // Cột Thông tin Giải đấu & 2 Đội
                VStack(alignment: .leading, spacing: 6) {
                    // Hàng Nhãn Giải Đấu + HOT + Số BLV
                    HStack(spacing: 6) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(leagueColor)
                                .frame(width: 6, height: 6)
                            Text(match.leagueName)
                                .font(.system(size: 11, weight: .bold))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(leagueColor.opacity(0.18))
                        .foregroundStyle(leagueColor)
                        .clipShape(Capsule())
                        
                        if match.isHot {
                            Text("HOT")
                                .font(.system(size: 9, weight: .black))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.yellow.opacity(0.22))
                                .foregroundStyle(.yellow)
                                .clipShape(Capsule())
                        }
                        
                        Spacer()
                        
                        if match.blvCount > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 8))
                                Text("\(match.blvCount)")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(blvBadgeColor.opacity(0.2))
                            .foregroundStyle(blvBadgeColor)
                            .clipShape(Capsule())
                        }
                    }
                    
                    // Tên Đội Chủ Nhà & Đội Khách
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(leagueColor)
                                .frame(width: 3, height: 13)
                            Text(match.homeTeam)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Color.gray.opacity(0.5))
                                .frame(width: 3, height: 13)
                            Text(match.awayTeam)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.85))
                                .lineLimit(1)
                        }
                    }
                    
                    // Cảnh báo nếu trùng khung giờ với trận đã ghim khác
                    if let conflict = conflictInfo {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                            Text("Trùng giờ: \(conflict)")
                                .font(.system(size: 10, weight: .semibold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(.orange)
                        .padding(.top, 1)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                
                // Cột Trạng Thái Ghim & Báo Thức (Bên phải)
                VStack(spacing: 3) {
                    if markState == 2 {
                        Image(systemName: "bell.and.waves.left.and.right.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.orange)
                        Text("Phải xem")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.orange)
                    } else if markState == 1 {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(.green)
                        Text("Theo dõi")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: "bell")
                            .font(.system(size: 15))
                            .foregroundStyle(.gray.opacity(0.35))
                    }
                }
                .frame(width: 54)
            }
            .background(cardBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor(defaultColor: leagueColor), lineWidth: markState > 0 ? 1.5 : 0.7)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var blvBadgeColor: Color {
        if match.blvCount >= 5 { return Color(red: 1.0, green: 0.38, blue: 0.38) }
        if match.blvCount >= 3 { return Color.orange }
        return Color.gray
    }
    
    private var cardBackgroundColor: Color {
        if markState == 2 { return Color.orange.opacity(0.13) }
        if markState == 1 { return Color.green.opacity(0.10) }
        if match.blvCount >= 5 { return Color(red: 0.15, green: 0.11, blue: 0.21) }
        if match.blvCount >= 3 { return Color(red: 0.11, green: 0.14, blue: 0.21) }
        return Color(red: 0.10, green: 0.11, blue: 0.15)
    }
    
    private func accentBarColor(defaultColor: Color) -> Color {
        if markState == 2 { return .orange }
        if markState == 1 { return .green }
        return defaultColor
    }
    
    private func borderColor(defaultColor: Color) -> Color {
        if markState == 2 { return .orange.opacity(0.85) }
        if markState == 1 { return .green.opacity(0.75) }
        return defaultColor.opacity(0.25)
    }
}
