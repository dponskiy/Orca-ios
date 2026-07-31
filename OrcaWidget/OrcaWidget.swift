//
//  OrcaWidget.swift
//  OrcaWidget
//

import WidgetKit
import SwiftUI

// MARK: - Shared data types (mirrors OrcaApp.swift — no target dependency needed)

struct OrcaWidgetTask: Codable, Identifiable {
    let id: String
    let text: String
    let echoEmoji: String
    let isOverdue: Bool
    let dateLabel: String
}

struct OrcaWidgetData: Codable {
    let todayCount: Int
    let overdueCount: Int
    let tasks: [OrcaWidgetTask]
    let updatedAt: Date

    static let appGroupSuite = "group.com.dponskiy.Orca"
    static let defaultsKey   = "orcaWidgetData"

    static func read() -> OrcaWidgetData {
        guard let defaults = UserDefaults(suiteName: appGroupSuite),
              let raw = defaults.data(forKey: defaultsKey),
              let data = try? JSONDecoder().decode(OrcaWidgetData.self, from: raw) else {
            return OrcaWidgetData(todayCount: 0, overdueCount: 0, tasks: [], updatedAt: .distantPast)
        }
        return data
    }
}

// MARK: - Timeline Provider

struct OrcaProvider: TimelineProvider {
    func placeholder(in context: Context) -> OrcaEntry {
        OrcaEntry(date: Date(), data: OrcaWidgetData(
            todayCount: 3, overdueCount: 1,
            tasks: [
                OrcaWidgetTask(id: "1", text: "Pick up dry cleaning", echoEmoji: "🏠", isOverdue: false, dateLabel: "Today"),
                OrcaWidgetTask(id: "2", text: "Call dentist", echoEmoji: "🏥", isOverdue: true, dateLabel: "Overdue"),
                OrcaWidgetTask(id: "3", text: "Submit timesheet", echoEmoji: "💼", isOverdue: false, dateLabel: "Today"),
            ],
            updatedAt: Date()
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (OrcaEntry) -> Void) {
        completion(OrcaEntry(date: Date(), data: OrcaWidgetData.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<OrcaEntry>) -> Void) {
        let entry = OrcaEntry(date: Date(), data: OrcaWidgetData.read())
        let nextUpdate = Calendar.current.nextDate(
            after: Date(),
            matching: DateComponents(minute: 0),
            matchingPolicy: .nextTime
        ) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

struct OrcaEntry: TimelineEntry {
    let date: Date
    let data: OrcaWidgetData
}

// MARK: - Small Widget

struct OrcaSmallWidgetView: View {
    let data: OrcaWidgetData
    private let teal  = Color(red: 0.161, green: 0.714, blue: 0.663)
    private let navy  = Color(red: 0.043, green: 0.114, blue: 0.2)
    private let coral = Color(red: 0.941, green: 0.361, blue: 0.361)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [navy, Color(red: 0.102, green: 0.227, blue: 0.361)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 11, weight: .semibold)).foregroundColor(teal)
                    Text("Orca")
                        .font(.system(size: 11, weight: .semibold)).foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                let total = data.todayCount + data.overdueCount
                if total == 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("All clear 🎉")
                            .font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                        Text("Nothing due today")
                            .font(.system(size: 12)).foregroundColor(.white.opacity(0.5))
                    }
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(total)")
                            .font(.system(size: 40, weight: .bold)).foregroundColor(.white)
                        Text(total == 1 ? "task today" : "tasks today")
                            .font(.system(size: 12)).foregroundColor(.white.opacity(0.55))
                    }
                    if data.overdueCount > 0 {
                        HStack(spacing: 4) {
                            Circle().fill(coral).frame(width: 6, height: 6)
                            Text("\(data.overdueCount) overdue")
                                .font(.system(size: 11, weight: .medium)).foregroundColor(coral)
                        }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .containerBackground(navy, for: .widget)
    }
}

// MARK: - Medium Widget

struct OrcaMediumWidgetView: View {
    let data: OrcaWidgetData
    private let teal  = Color(red: 0.161, green: 0.714, blue: 0.663)
    private let navy  = Color(red: 0.067, green: 0.118, blue: 0.2)
    private let coral = Color(red: 0.941, green: 0.361, blue: 0.361)
    private let pearl = Color(red: 0.965, green: 0.969, blue: 0.976)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 11, weight: .semibold)).foregroundColor(teal)
                    Text("Today")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(navy)
                }
                Spacer()
                let total = data.todayCount + data.overdueCount
                if total > 0 {
                    Text("\(total) \(total == 1 ? "task" : "tasks")")
                        .font(.system(size: 11)).foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)

            if data.tasks.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Text("🎉").font(.system(size: 26))
                        Text("You're all caught up")
                            .font(.system(size: 13)).foregroundColor(.gray)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(data.tasks.prefix(4).enumerated()), id: \.element.id) { idx, task in
                        HStack(spacing: 10) {
                            Circle()
                                .stroke(task.isOverdue ? coral : teal, lineWidth: 1.5)
                                .frame(width: 16, height: 16)
                            Text(task.echoEmoji).font(.system(size: 13))
                            Text(task.text)
                                .font(.system(size: 13))
                                .foregroundColor(task.isOverdue ? coral : navy)
                                .lineLimit(1)
                            Spacer()
                            Text(task.dateLabel)
                                .font(.system(size: 10)).foregroundColor(.gray)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        if idx < min(data.tasks.count, 4) - 1 {
                            Divider().padding(.leading, 40)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .containerBackground(pearl, for: .widget)
    }
}

// MARK: - Entry view

struct OrcaWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: OrcaEntry

    var body: some View {
        switch family {
        case .systemSmall:  OrcaSmallWidgetView(data: entry.data)
        case .systemMedium: OrcaMediumWidgetView(data: entry.data)
        default:            OrcaSmallWidgetView(data: entry.data)
        }
    }
}

// MARK: - Widget

struct OrcaWidget: Widget {
    let kind: String = "OrcaWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OrcaProvider()) { entry in
            OrcaWidgetEntryView(entry: entry)
                .widgetURL(URL(string: "orca://today"))
        }
        .configurationDisplayName("Orca")
        .description("Your tasks for today at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    OrcaWidget()
} timeline: {
    OrcaEntry(date: .now, data: OrcaWidgetData(
        todayCount: 3, overdueCount: 1,
        tasks: [
            OrcaWidgetTask(id: "1", text: "Pick up dry cleaning", echoEmoji: "🏠", isOverdue: false, dateLabel: "Today"),
            OrcaWidgetTask(id: "2", text: "Call dentist", echoEmoji: "🏥", isOverdue: true, dateLabel: "Overdue"),
        ],
        updatedAt: .now
    ))
}

#Preview(as: .systemMedium) {
    OrcaWidget()
} timeline: {
    OrcaEntry(date: .now, data: OrcaWidgetData(
        todayCount: 3, overdueCount: 1,
        tasks: [
            OrcaWidgetTask(id: "1", text: "Pick up dry cleaning", echoEmoji: "🏠", isOverdue: false, dateLabel: "Today"),
            OrcaWidgetTask(id: "2", text: "Call dentist", echoEmoji: "🏥", isOverdue: true, dateLabel: "Overdue"),
            OrcaWidgetTask(id: "3", text: "Submit timesheet", echoEmoji: "💼", isOverdue: false, dateLabel: "Today"),
            OrcaWidgetTask(id: "4", text: "Walk the dog", echoEmoji: "🐾", isOverdue: false, dateLabel: "Today"),
        ],
        updatedAt: .now
    ))
}
