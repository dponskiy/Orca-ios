//
//  CookingSessionView.swift
//  Orca
//
//  The recipe on the counter: ingredients at the top, steps below, timers along the
//  bottom, and a screen that stays lit.
//

import SwiftUI
import SwiftData
import UIKit

struct CookingSessionView: View {
    let memory: Memory
    let ingredients: [SubTask]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var timers = CookTimerStore.shared
    @State private var steps: [String] = []
    @State private var done: Set<Int> = []
    @State private var checkedIngredients: Set<UUID> = []
    @State private var showIngredients = true
    @State private var addingStep = false
    @State private var newStep = ""
    @FocusState private var newStepFocused: Bool
    @State private var showTimerPicker = false
    @State private var pickerMinutes = 10

    private var title: String { RecipeDocument.title(in: memory.text) }
    private var allDone: Bool { !steps.isEmpty && done.count == steps.count }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                cafeBg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ingredientsSection
                        stepsSection
                        sourceLink
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    // Room for the timer bar, so the last step isn't hidden behind it
                    .padding(.bottom, timers.timers.isEmpty ? 40 : 150)
                }

                if !timers.timers.isEmpty { timerBar }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { finish() }.foregroundColor(.oceanTeal)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if allDone || !done.isEmpty {
                        Button("Start over") {
                            withAnimation { done.removeAll(); checkedIngredients.removeAll() }
                            persist()
                        }
                        .font(.custom("DMSans-Regular", size: 14))
                        .foregroundColor(inkMuted)
                    }
                }
            }
        }
        .onAppear {
            steps = RecipeDocument.steps(in: memory.text)
            restore()
            Self.markCooked(memory.id)
            // The whole point: a recipe that blanks out mid-step is why this screen exists
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            // Released here *and* on backgrounding below. A phone that never sleeps again
            // would be a worse bug than the one this fixes.
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: scenePhase) { _, phase in
            UIApplication.shared.isIdleTimerDisabled = (phase == .active)
        }
        .sheet(isPresented: $showTimerPicker) { timerPicker }
    }

    // MARK: - Ingredients

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(duration: 0.25)) { showIngredients.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Text("INGREDIENTS")
                        .font(.custom("DMMono-Regular", size: 10)).tracking(1.4)
                        .foregroundColor(inkMuted)
                    Text("\(checkedIngredients.count)/\(ingredients.count)")
                        .font(.custom("DMMono-Regular", size: 10)).foregroundColor(inkMuted.opacity(0.7))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(inkMuted.opacity(0.7))
                        .rotationEffect(.degrees(showIngredients ? 0 : -90))
                }
            }
            .buttonStyle(.plain)

            if showIngredients {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(ingredients) { item in
                        let ticked = checkedIngredients.contains(item.id)
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(duration: 0.18)) {
                                if ticked { checkedIngredients.remove(item.id) }
                                else { checkedIngredients.insert(item.id) }
                            }
                            persist()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: ticked ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 17))
                                    .foregroundColor(ticked ? .oceanTeal : inkMuted.opacity(0.45))
                                Text(item.text)
                                    .font(.custom("DMSans-Regular", size: 16))
                                    .foregroundColor(ticked ? inkMuted : inkPrimary)
                                    .strikethrough(ticked, color: inkMuted)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Steps

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("STEPS")
                    .font(.custom("DMMono-Regular", size: 10)).tracking(1.4).foregroundColor(inkMuted)
                if !steps.isEmpty {
                    Text("\(done.count)/\(steps.count)")
                        .font(.custom("DMMono-Regular", size: 10)).foregroundColor(inkMuted.opacity(0.7))
                }
                Spacer()

                // A step with no time in its text still needs a timer sometimes —
                // "until the onions are soft" is a real instruction.
                Button { showTimerPicker = true } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "timer").font(.system(size: 11, weight: .medium))
                        Text("Set a timer").font(.custom("DMSans-Medium", size: 12))
                    }
                    .foregroundColor(.oceanTeal)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.oceanTeal.opacity(0.10))
                    .clipShape(Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            // Nothing said the numbers were buttons, so they read as decoration.
            if !steps.isEmpty && done.isEmpty {
                Text("Tap a number to check that step off")
                    .font(.custom("DMSans-Regular", size: 12))
                    .foregroundColor(inkMuted)
            }

            if steps.isEmpty && !addingStep {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No steps saved for this one")
                        .font(.custom("DMSans-Medium", size: 15)).foregroundColor(inkPrimary)
                    Text("Add them as you go and they'll be here next time.")
                        .font(.custom("DMSans-Regular", size: 13)).foregroundColor(inkMuted)
                }
                .padding(.bottom, 4)
            }

            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                stepRow(index: index, step: step)
            }

            addStepRow
        }
    }

    private func stepRow(index: Int, step: String) -> some View {
        let ticked = done.contains(index)

        return HStack(alignment: .top, spacing: 12) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(duration: 0.2)) {
                    if ticked { done.remove(index) } else { done.insert(index) }
                }
                persist()
            } label: {
                ZStack {
                    Circle()
                        .stroke(ticked ? Color.oceanTeal : inkMuted.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 26, height: 26)
                    if ticked {
                        Circle().fill(Color.oceanTeal).frame(width: 26, height: 26)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                    } else {
                        Text("\(index + 1)")
                            .font(.custom("DMMono-Regular", size: 12)).foregroundColor(inkMuted)
                    }
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 8) {
                Text(step)
                    .font(.custom("DMSans-Regular", size: 17))
                    .lineSpacing(3)
                    .foregroundColor(ticked ? inkMuted : inkPrimary)
                    .strikethrough(ticked, color: inkMuted.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Times in the step, offered where they were written
                let found = CookTimeParser.times(in: step)
                if !found.isEmpty && !ticked {
                    HStack(spacing: 8) {
                        ForEach(found) { time in timerChip(time, step: step) }
                    }
                }
            }
        }
        .padding(.bottom, 2)
    }

    private func timerChip(_ time: CookTime, step: String) -> some View {
        Button {
            Task {
                _ = await timers.ensurePermission()
                timers.start(label: shortLabel(for: step), seconds: time.seconds)
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "timer").font(.system(size: 11, weight: .medium))
                Text(time.text).font(.custom("DMSans-Medium", size: 12))
            }
            .foregroundColor(.oceanTeal)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color.oceanTeal.opacity(0.10))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.oceanTeal.opacity(0.28), lineWidth: 0.5))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    /// A timer's label should say what it's for when it goes off on the lock screen, so
    /// it's the start of the step rather than "Timer 2".
    private func shortLabel(for step: String) -> String {
        let words = step.split(separator: " ").prefix(6).joined(separator: " ")
        return words.count < step.count ? words + "…" : words
    }

    private var addStepRow: some View {
        Group {
            if addingStep {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 18)).foregroundColor(.oceanTeal.opacity(0.6))
                    TextField("What happens next?", text: $newStep, axis: .vertical)
                        .font(.custom("DMSans-Regular", size: 16))
                        .foregroundColor(inkPrimary)
                        .focused($newStepFocused)
                        .submitLabel(.next)
                        .onSubmit { commitStep() }
                    if !newStep.isEmpty {
                        Button("Add") { commitStep() }
                            .font(.custom("DMSans-Medium", size: 14))
                            .foregroundColor(.oceanTeal)
                            .buttonStyle(.plain)
                    }
                }
                .padding(.top, 4)
            } else {
                Button {
                    addingStep = true
                    newStepFocused = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle").font(.system(size: 16))
                        Text(steps.isEmpty ? "Add the first step" : "Add a step")
                            .font(.custom("DMSans-Regular", size: 15))
                    }
                    .foregroundColor(.oceanTeal)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
    }

    private func commitStep() {
        let trimmed = newStep.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        withAnimation { steps.append(trimmed) }
        newStep = ""
        // Keep the keyboard up: steps come in runs, the same as list items
        newStepFocused = true

        memory.text = RecipeDocument.settingSteps(steps, in: memory.text)
        memory.updatedAt = Date()
        try? modelContext.save()
    }

    // MARK: - Where it came from

    /// What's saved is the ingredients and the steps, which isn't the whole page: the
    /// notes about why it works, the picture of what it should look like, the comments
    /// saying to halve the salt. Worth being one tap away while you cook.
    @ViewBuilder
    private var sourceLink: some View {
        if let source = memory.url, !source.isEmpty, let url = URL(string: source) {
            Link(destination: url) {
                HStack(spacing: 8) {
                    Image(systemName: "safari").font(.system(size: 14))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Open the original recipe")
                            .font(.custom("DMSans-Medium", size: 14))
                        Text(url.host()?.replacingOccurrences(of: "www.", with: "") ?? source)
                            .font(.custom("DMMono-Regular", size: 11))
                            .foregroundColor(inkMuted)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .semibold)).foregroundColor(inkMuted.opacity(0.7))
                }
                .foregroundColor(.oceanTeal)
                .padding(14)
                .background(Color.white.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Your own timer

    /// Presets first, because most kitchen timers are a round number, and the wheel
    /// underneath for the ones that aren't.
    private var timerPicker: some View {
        NavigationStack {
            VStack(spacing: 24) {
                HStack(spacing: 10) {
                    ForEach([5, 10, 15, 30], id: \.self) { minutes in
                        Button {
                            startTimer(minutes: minutes)
                        } label: {
                            Text("\(minutes)m")
                                .font(.custom("DMSans-Medium", size: 15))
                                .foregroundColor(.oceanTeal)
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Color.oceanTeal.opacity(0.10))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Picker("Minutes", selection: $pickerMinutes) {
                    ForEach(1...180, id: \.self) { minute in
                        Text(minute < 60
                             ? "\(minute) min"
                             : (minute % 60 == 0 ? "\(minute / 60) hr" : "\(minute / 60) hr \(minute % 60) min"))
                            .tag(minute)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxHeight: 180)

                Button {
                    startTimer(minutes: pickerMinutes)
                } label: {
                    Text("Start")
                        .font(.custom("DMSans-Medium", size: 16)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color.oceanTeal)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)

                Spacer()
            }
            .background(cafeBg.ignoresSafeArea())
            .navigationTitle("Set a timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showTimerPicker = false }.foregroundColor(inkMuted)
                }
            }
        }
        .presentationDetents([.height(420)])
    }

    private func startTimer(minutes: Int) {
        showTimerPicker = false
        Task {
            _ = await timers.ensurePermission()
            timers.start(label: "\(minutes) min · \(title)", seconds: minutes * 60)
        }
    }

    // MARK: - Timer bar

    private var timerBar: some View {
        VStack(spacing: 8) {
            ForEach(timers.timers) { timer in
                HStack(spacing: 12) {
                    ZStack {
                        Circle().stroke(inkMuted.opacity(0.25), lineWidth: 3).frame(width: 30, height: 30)
                        Circle()
                            .trim(from: 0, to: timer.progress)
                            .stroke(timer.isDone ? Color.coral : Color.oceanTeal,
                                    style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 30, height: 30)
                            .rotationEffect(.degrees(-90))
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(timer.isDone ? "Time's up" : timer.clock)
                            .font(.custom("DMMono-Regular", size: 15))
                            .foregroundColor(timer.isDone ? .coral : inkPrimary)
                        Text(timer.label)
                            .font(.custom("DMSans-Regular", size: 12))
                            .foregroundColor(inkMuted).lineLimit(1)
                    }
                    Spacer()
                    Button {
                        timers.cancel(timer.id)
                    } label: {
                        Image(systemName: timer.isDone ? "checkmark" : "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(inkMuted)
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color.white.opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.10), radius: 8, y: 3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .animation(.spring(duration: 0.25), value: timers.timers)
        // Redrawn each second by the store's tick
        .id(timers.tick)
    }

    // MARK: - Persistence

    // Ticks are kept per recipe: put the phone down with something in the oven, come
    // back, and your place is still there.
    private func stepsKey() -> String { "cookDone-\(memory.id.uuidString)" }
    private func ingredientsKey() -> String { "cookIngredients-\(memory.id.uuidString)" }
    private static func cookedKey(_ id: UUID) -> String { "lastCooked-\(id.uuidString)" }

    private func restore() {
        let saved = UserDefaults.standard.array(forKey: stepsKey()) as? [Int] ?? []
        done = Set(saved.filter { $0 < steps.count })

        let ticked = UserDefaults.standard.array(forKey: ingredientsKey()) as? [String] ?? []
        checkedIngredients = Set(ticked.compactMap(UUID.init))
    }

    private func persist() {
        UserDefaults.standard.set(Array(done), forKey: stepsKey())
        UserDefaults.standard.set(checkedIngredients.map { $0.uuidString }, forKey: ingredientsKey())
    }

    private func finish() {
        // Timers outlive the screen on purpose — walking away from a recipe with
        // something still in the oven shouldn't cancel the thing telling you about it.
        dismiss()
    }

    static func markCooked(_ id: UUID) {
        UserDefaults.standard.set(Date(), forKey: cookedKey(id))
    }

    static func lastCooked(_ id: UUID) -> Date? {
        UserDefaults.standard.object(forKey: cookedKey(id)) as? Date
    }
}
