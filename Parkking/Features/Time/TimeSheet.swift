import SwiftUI

struct TimeSheet: View {
    var query: TimeQuery
    var onApply: (TimeQuery) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draft: TimeQuery

    init(query: TimeQuery, onApply: @escaping (TimeQuery) -> Void) {
        self.query = query
        self.onApply = onApply
        var initial = query
        if initial.mode == .now {
            let slot = ParkingTimeQuery.slotFromDate(Date(), timeZone: ParkingTimeQuery.torontoTimeZone)
            initial.date = ParkingTimeQuery.slotToDateString(slot)
            initial.startMinute = slot.minuteOfDay
            initial.mode = .custom
        }
        _draft = State(initialValue: initial)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center) {
                    Text("Custom time / duration")
                        .font(.headline)

                    Spacer()

                    Button {
                        applyCustomQuery()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                            .background(Color(uiColor: .tertiarySystemFill), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Done")
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("From")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                        DatePicker(
                            "Start time",
                            selection: startTimeBinding,
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .environment(\.timeZone, ParkingTimeQuery.torontoTimeZone)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("To")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                        DatePicker(
                            "End time",
                            selection: endTimeBinding,
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .environment(\.timeZone, ParkingTimeQuery.torontoTimeZone)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Date")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                        DatePicker(
                            "Date",
                            selection: customDateBinding,
                            displayedComponents: .date
                        )
                        .labelsHidden()
                        .environment(\.timeZone, ParkingTimeQuery.torontoTimeZone)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
            }
        }
        .onAppear {
            var initial = query
            if initial.mode == .now {
                let slot = ParkingTimeQuery.slotFromDate(Date(), timeZone: ParkingTimeQuery.torontoTimeZone)
                initial.date = ParkingTimeQuery.slotToDateString(slot)
                initial.startMinute = slot.minuteOfDay
                initial.mode = .custom
            }
            draft = initial
        }
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
            }
        )
    }

    private var startTimeBinding: Binding<Date> {
        Binding(
            get: {
                ParkingTimeQuery.date(
                    fromTorontoDateString: draft.date,
                    minuteOfDay: draft.startMinute
                )
            },
            set: { newDate in
                draft.startMinute = ParkingTimeQuery.minuteOfDay(from: newDate)
            }
        )
    }

    private var endTimeBinding: Binding<Date> {
        Binding(
            get: {
                let endMinute = draft.startMinute + draft.requestedDurationMinutes
                return ParkingTimeQuery.date(
                    fromTorontoDateString: draft.date,
                    minuteOfDay: endMinute
                )
            },
            set: { newDate in
                let pickedMinute = ParkingTimeQuery.minuteOfDay(from: newDate)
                if pickedMinute > draft.startMinute {
                    let duration = pickedMinute - draft.startMinute
                    draft.requestedDurationMinutes = ParkingTimeQuery.clampDuration(duration)
                } else {
                    let overnightDuration = (1440 - draft.startMinute) + pickedMinute
                    if overnightDuration <= ParkingTimeQuery.maxDurationMinutes {
                        draft.requestedDurationMinutes = ParkingTimeQuery.clampDuration(overnightDuration)
                    } else {
                        draft.requestedDurationMinutes = ParkingTimeQuery.minDurationMinutes
                    }
                }
                draft.durationPreset = ParkingTimeQuery.preset(for: draft.requestedDurationMinutes)
            }
        )
    }

    private func applyCustomQuery() {
        var next = draft
        next.mode = .custom
        next.requestedDurationMinutes = ParkingTimeQuery.clampDuration(
            next.requestedDurationMinutes
        )
        next.durationPreset = ParkingTimeQuery.preset(
            for: next.requestedDurationMinutes
        )
        onApply(next)
        dismiss()
    }
}
