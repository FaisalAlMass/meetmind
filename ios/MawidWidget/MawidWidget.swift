//
//  MawidWidget.swift
//  MawidWidget
//

import WidgetKit
import SwiftUI

// مرآة لنفس الشكل اللي يُكتب من Dart (providers.dart) — كل النصوص هنا
// توصل جاهزة ومترجمة من فلَتر، فما فيه أي منطق عربي/إنجليزي أو RTL
// خاص بسويفت غير اتجاه التخطيط نفسه.
struct MawidEventEntryData: Codable {
    let title: String
    let timeText: String
    let isFocus: Bool
}

struct WidgetPayload: Codable {
    let events: [MawidEventEntryData]
    let upcomingLabel: String
    let emptyLabel: String
    let isRTL: Bool
}

struct MawidWidgetEntry: TimelineEntry {
    let date: Date
    let events: [MawidEventEntryData]
    let hasEvents: Bool
    let upcomingLabel: String
    let emptyLabel: String
    let isRTL: Bool
}

struct MawidTimelineProvider: TimelineProvider {
    private let appGroupId = "group.com.faisalalmass.mawid"

    func placeholder(in context: Context) -> MawidWidgetEntry {
        MawidWidgetEntry(
            date: Date(),
            events: [MawidEventEntryData(title: "اجتماع الفريق", timeText: "3:00 م", isFocus: false)],
            hasEvents: true,
            upcomingLabel: "المواعيد القادمة",
            emptyLabel: "لا توجد مواعيد",
            isRTL: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (MawidWidgetEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MawidWidgetEntry>) -> Void) {
        let entry = loadEntry()
        // سقف تحديث احتياطي — التحديث الحقيقي يصير فورًا لما التطبيق نفسه
        // يستدعي reloadTimelines بعد أي تغيير بالمواعيد؛ هذا بس يمنع
        // الودجت يصير قديم لو التطبيق ما انفتح لفترة طويلة.
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func loadEntry() -> MawidWidgetEntry {
        guard let defaults = UserDefaults(suiteName: appGroupId),
              let json = defaults.string(forKey: "widget_agenda"),
              let data = json.data(using: .utf8),
              let payload = try? JSONDecoder().decode(WidgetPayload.self, from: data)
        else {
            return MawidWidgetEntry(date: Date(), events: [], hasEvents: false,
                upcomingLabel: "", emptyLabel: "", isRTL: false)
        }
        return MawidWidgetEntry(
            date: Date(),
            events: payload.events,
            hasEvents: !payload.events.isEmpty,
            upcomingLabel: payload.upcomingLabel,
            emptyLabel: payload.emptyLabel,
            isRTL: payload.isRTL
        )
    }
}

private let brandGreen = Color(red: 0x28 / 255, green: 0x92 / 255, blue: 0x4F / 255)    // #28924F
private let brandGold = Color(red: 0xCC / 255, green: 0xA5 / 255, blue: 0x3B / 255)     // #CCA53B
private let brandEmerald = Color(red: 0x00 / 255, green: 0xB4 / 255, blue: 0x8C / 255)  // #00B48C

extension View {
    @ViewBuilder
    func widgetBackground<S: ShapeStyle>(_ style: S) -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(style, for: .widget)
        } else {
            self.background(style)
        }
    }
}

/// نفس علامة "موعد" اللي بالتطبيق (lib/shared/theme/mawid_mark.dart) —
/// حرف الميم داخل حلقة خضراء مع نقطة إبراز، معاد رسمها بسويفت لنفس
/// الاتساق البصري بين التطبيق والودجت.
private struct MawidLogoMark: View {
    var size: CGFloat = 26

    var body: some View {
        ZStack {
            Circle()
                .stroke(brandGreen.opacity(0.5), lineWidth: size * 0.07)
            Text("م")
                .font(.system(size: size * 0.58, weight: .heavy))
                .foregroundStyle(.primary)
            Circle()
                .fill(brandEmerald)
                .frame(width: size * 0.14, height: size * 0.14)
                .offset(x: size * 0.30, y: -size * 0.22)
        }
        .frame(width: size, height: size)
    }
}

private struct EventRow: View {
    let event: MawidEventEntryData
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(event.isFocus ? brandGreen : brandGold)
                .frame(width: 6, height: 6)
            Text(event.title).font(.caption).lineLimit(1)
            Spacer()
            Text(event.timeText).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private struct EmptyRow: View {
    let label: String
    var body: some View {
        Text(label).font(.caption).foregroundStyle(.secondary)
    }
}

private struct SmallLayout: View {
    let entry: MawidWidgetEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MawidLogoMark(size: 22)
            if entry.hasEvents {
                ForEach(entry.events.prefix(2), id: \.title) { EventRow(event: $0) }
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)
                EmptyRow(label: entry.emptyLabel)
                Spacer(minLength: 0)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct MediumLayout: View {
    let entry: MawidWidgetEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                MawidLogoMark(size: 22)
                Text(entry.upcomingLabel).font(.caption.bold()).foregroundStyle(.secondary)
            }
            if entry.hasEvents {
                ForEach(entry.events.prefix(3), id: \.title) { EventRow(event: $0) }
            } else {
                EmptyRow(label: entry.emptyLabel)
            }
            Spacer(minLength: 0)
        }
        .padding()
    }
}

private struct LargeLayout: View {
    let entry: MawidWidgetEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                MawidLogoMark(size: 26)
                Text(entry.upcomingLabel).font(.caption.bold()).foregroundStyle(.secondary)
            }
            if entry.hasEvents {
                ForEach(entry.events.prefix(6), id: \.title) { EventRow(event: $0) }
            } else {
                EmptyRow(label: entry.emptyLabel)
            }
            Spacer(minLength: 0)
        }
        .padding()
    }
}

struct MawidWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: MawidWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall: SmallLayout(entry: entry)
            case .systemMedium: MediumLayout(entry: entry)
            default: LargeLayout(entry: entry)
            }
        }
        .environment(\.layoutDirection, entry.isRTL ? .rightToLeft : .leftToRight)
        .widgetBackground(Color(.systemBackground))
        // الودجت كله لمسة وحدة — الضغط بأي مكان يفتح شاشة الكتابة بالتطبيق
        // (زي الاختصار). معامل homeWidget إلزامي — home_widget يتجاهل أي
        // رابط بدونه (HomeWidgetPlugin.isWidgetUrl يفحص وجود هذا الاسم).
        .widgetURL(URL(string: "mawid://capture?homeWidget=true"))
    }
}

struct MawidWidget: Widget {
    let kind: String = "MawidWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MawidTimelineProvider()) { entry in
            MawidWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("موعد")
        .description("استعرض مواعيدك القادمة — اضغط لفتح التطبيق")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemMedium) {
    MawidWidget()
} timeline: {
    MawidWidgetEntry(
        date: .now,
        events: [
            MawidEventEntryData(title: "اجتماع الفريق", timeText: "3:00 م", isFocus: false),
            MawidEventEntryData(title: "وقت تركيز", timeText: "5:00 م", isFocus: true),
        ],
        hasEvents: true,
        upcomingLabel: "المواعيد القادمة",
        emptyLabel: "لا توجد مواعيد",
        isRTL: true
    )
}
