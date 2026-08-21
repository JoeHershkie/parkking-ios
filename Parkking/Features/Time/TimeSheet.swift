import SwiftUI

struct TimeSheet: View {
    var query: TimeQuery
    var onApply: (TimeQuery) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draft: TimeQuery

    init(query: TimeQuery, onApply: @escaping (TimeQuery) -> Void) {
        self.query = query
        self.onApply = onApply
        _draft = State(initialValue: query)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Picker("Time mode", selection: $draft.mode) {
                        Text("Now").tag(TimeMode.now)
                        Text("Custom").tag(TimeMode.custom)
                    }
                    .pickerStyle(.segmented)
                    .frame(minHeight: 44)
                    .accessibilityLabel("Time mode")

                    if draft.mode == .custom {
                        DatePicker(
                            "Date",
                            selection: customDateBinding,
                            displayedComponents: .date
                        )
                        .environment(\.timeZone, ParkingTimeQuery.torontoTimeZone)
                        .frame(minHeight: 44)

                        DatePicker(
                            "Start",
                            selection: customDateBinding,
                            displayedComponents: .hourAndMinute
                        )
                        .environment(\.timeZone, ParkingTimeQuery.torontoTimeZone)
                        .frame(minHeight: 44)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Duration")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            ForEach(ParkingTimeQuery.durationPresets, id: \.self) { minutes in
                                durationChip(minutes)
                            }
                        }

                        if showsCustomDurationControl {
                            Stepper(value: customMinutesBinding, in: 1...720) {
                                Text("\(draft.requestedDurationMinutes) minutes")
                                    .font(.body.weight(.semibold))
                            }
                            .frame(minHeight: 44)
                            .accessibilityLabel("Custom duration")
                            .accessibilityValue("\(draft.requestedDurationMinutes) minutes")
                        } else {
                            Button("Custom duration…") {
                                draft.durationPreset = .custom
                            }
                            .frame(minHeight: 44)
                        }
                    }

                    if ParkingTimeQuery.draftCrossesMidnight(draft) {
                        Text(ParkingTimeQuery.midnightWarning)
                            .font(.footnote.weight(.semibold))
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    }

                    Button("Apply") {
                        var next = draft
                        next.requestedDurationMinutes = ParkingTimeQuery.clampDuration(
                            next.requestedDurationMinutes
                        )
                        if next.durationPreset != .custom {
                            next.durationPreset = ParkingTimeQuery.preset(
                                for: next.requestedDurationMinutes
                            )
                        }
                        onApply(next)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityLabel("Apply time query")
                }
                .padding()
            }
            .navigationTitle("Check time & duration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .frame(minHeight: 44)
                }
            }
            .onAppear { draft = query }
        }
    }

    private var showsCustomDurationControl: Bool {
        draft.durationPreset == .custom
            || !ParkingTimeQuery.durationPresets.contains(draft.requestedDurationMinutes)
    }

    private var customDateBinding: Binding<Date> {
        Binding(
            get: {
                ParkingTimeQuery.date(
                    fromTorontoDateString: draft.date,
                    minuteOfDay: draft.startMinute
                )
            },
            set: { newDate in
                draft.date = ParkingTimeQuery.torontoDateString(from: newDate)
                draft.startMinute = ParkingTimeQuery.minuteOfDay(from: newDate)
            }
        )
    }

    private var customMinutesBinding: Binding<Int> {
        Binding(
            get: { draft.requestedDurationMinutes },
            set: { value in
                draft.requestedDurationMinutes = ParkingTimeQuery.clampDuration(value)
                draft.durationPreset = .custom
            }
        )
    }

    private func durationChip(_ minutes: Int) -> some View {
        let selected = draft.durationPreset == .minutes(minutes)
            && draft.requestedDurationMinutes == minutes
        return Button {
            draft.durationPreset = .minutes(minutes)
            draft.requestedDurationMinutes = minutes
        } label: {
            Text(ParkingTimeQuery.formatDurationLabel(minutes))
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(selected ? .accentColor : .secondary)
        .accessibilityLabel(ParkingTimeQuery.formatDurationLabel(minutes))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityValue(selected ? "Selected" : "Not selected")
    }
}
