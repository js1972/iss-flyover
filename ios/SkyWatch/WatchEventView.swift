import SwiftUI
import WatchKit

struct WatchEventView: View {
    @EnvironmentObject private var model: WatchModel
    @Environment(\.scenePhase) private var phase
    @Environment(\.isLuminanceReduced) private var dimmed
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var compass = WatchCompass()
    @State private var continuing = false
    @State private var lastLive = false
    @State private var hasObservedState = false
    @ScaledMetric(relativeTo: .largeTitle) private var largeType = 44.0
    var eventID: String
    var body: some View {
        GeometryReader { geometry in
            TimelineView(.periodic(from: .now, by: dimmed || phase != .active ? 60 : 1)) { context in
                ScrollView {
                    if let snapshot = model.snapshot(at: context.date), let event = snapshot.events.first(where: { $0.id == eventID }),
                       WatchObservation.event(event, usableIn: snapshot, at: context.date) {
                        eventContent(event, snapshot: snapshot, now: context.date, compact: geometry.size.width < 180)
                    } else {
                        WatchEmptyView(title: "Forecast unavailable", detail: "This event needs a refreshed forecast. Open Sky Tonight on iPhone.")
                        Button("Request forecast") { model.requestRefresh(force: true) }
                    }
                }
            }
        }.navigationTitle("")
            .onDisappear { compass.stop(); continuing = false }
            .onChange(of: phase) { _, value in if value != .active { compass.stop() } }
            .onChange(of: dimmed) { _, value in if value { compass.stop() } }
    }
    @ViewBuilder private func eventContent(_ event: SkyEvent, snapshot: SkySnapshot, now: Date, compact: Bool) -> some View {
        let isISS = event.kind == "iss"
        let ended = now >= event.end
        let livePoint = !ended ? WatchObservation.point(in: event, at: now) : nil
        let live = livePoint != nil && (!isISS || livePoint?.sunlit == true)
        let position = livePoint ?? WatchObservation.point(in: event, at: event.focus) ?? SkyPoint(timestamp: event.focus, azimuth: event.azimuth, elevation: event.elevation, sunlit: true)
        VStack(spacing: compact ? 3 : 5) {
            Text(ended ? "Event ended" : live ? (isISS ? "VISIBLE NOW" : "POSITION NOW") : "PREVIEW · \(snapshot.location.time(event.focus))")
                .font(.caption2).foregroundStyle(ended ? Color.secondary : Color.watchMint).accessibilityIdentifier("observationState")
            if isISS {
                Text("\(Int(position.elevation.rounded()))°")
                    .font(.system(size: largeType * (compact ? 0.73 : 1), weight: .bold, design: .rounded)).foregroundStyle(Color.watchMint)
                Text(ended ? "at peak" : "above horizon").font(.caption)
                WatchPassArc(event: event, date: live ? now : event.focus, dimmed: dimmed).frame(height: compact ? 40 : 50)
                Text(ended ? "Pass complete" : live ? "\(WatchObservation.countdown(to: event.end, now: now)) left" : "Starts \(snapshot.location.time(event.start))")
                    .font(.headline).monospacedDigit()
            } else {
                HStack { WatchArtwork(event: event).frame(width: 45, height: 28); Text(event.title).font(.headline) }
                if let heading = compass.heading, live {
                    Image(systemName: "location.north.fill").font(.system(size: 42)).foregroundStyle(Color.watchMint)
                        .rotationEffect(.degrees(position.azimuth - heading))
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: heading)
                        .accessibilityLabel("Target bearing \(Int(position.azimuth)) degrees, your heading \(Int(heading)) degrees")
                } else {
                    Text(SkyEvent.direction(position.azimuth)).font(.system(size: largeType, weight: .bold, design: .rounded)).foregroundStyle(Color.watchMint)
                }
                Text("\(Int(position.elevation.rounded()))° high").font(.title3.bold())
                Text("Bearing \(Int(position.azimuth.rounded()))°").font(.caption).foregroundStyle(.secondary)
                if live && !ended {
                    Button(compass.enabled ? "Stop compass" : "Use compass") {
                        if compass.enabled { compass.stop() } else { compass.start(at: snapshot.location) }
                    }
                    Text(compass.status).font(.caption2).foregroundStyle(.secondary)
                } else { Text("Direction at the preview time; it will change as the sky moves.").font(.caption).foregroundStyle(.secondary) }
            }
            Text(snapshot.location.name).font(.caption).foregroundStyle(.secondary)
            if isISS, let warning = snapshot.orbitMessage { Text(warning).font(.caption).foregroundStyle(.secondary) }
            Divider().padding(.vertical, 8)
            Text(event.detail).font(.caption).foregroundStyle(.secondary)
            if !ended {
                let key = "\(snapshot.location.id):\(event.id)"
                let pending = model.pending.contains { $0.reminderID == key }
                Button {
                    model.queueReminder(event)
                } label: {
                    Label(pending ? "Awaiting iPhone" : model.package?.reminders.contains(key) == true ? "Cancel reminder" : "Remind me", systemImage: pending ? "clock" : "bell")
                }.disabled(pending || event.start <= now.addingTimeInterval(60)).accessibilityIdentifier("watchReminder")
            }
            Button("Continue on iPhone") { continuing = true }.accessibilityIdentifier("continueOnPhone")
            if continuing { Text("Open the Sky Tonight Handoff suggestion in your iPhone's app switcher.").font(.caption) }
        }
        .padding(.horizontal, 4).padding(.bottom, 12)
        .onChange(of: live) { _, value in
            if hasObservedState && !lastLive && value && isISS && phase == .active && !dimmed { WKInterfaceDevice.current().play(.notification) }
            lastLive = value; hasObservedState = true
        }
        .onAppear { lastLive = live; hasObservedState = true }
        .userActivity(WatchObservation.activityType, isActive: continuing) { activity in
            activity.title = "Observe \(event.title)"
            var preview = event; preview.focus = live ? now : event.focus
            activity.userInfo = ["url": preview.link(location: snapshot.location).absoluteString]
            activity.isEligibleForHandoff = true
        }
    }
}

/// A factual altitude-over-time plot, drawn from the same sampled visible path as iPhone.
struct WatchPassArc: View {
    var event: SkyEvent
    var date: Date
    var dimmed: Bool
    private func position(_ point: SkyPoint, size: CGSize) -> CGPoint {
        let duration = max(1, event.end.timeIntervalSince(event.start))
        return CGPoint(x: 8 + (size.width - 16) * point.timestamp.timeIntervalSince(event.start) / duration,
                       y: 1 + max(1, size.height - 2) * (1 - max(0, min(90, point.elevation)) / 90))
    }
    var body: some View {
        VStack(spacing: 1) {
            GeometryReader { geometry in
                Path { path in
                    var drawing = false
                    for point in event.points {
                        guard point.sunlit && point.elevation >= 0 else { drawing = false; continue }
                        if drawing { path.addLine(to: position(point, size: geometry.size)) }
                        else { path.move(to: position(point, size: geometry.size)); drawing = true }
                    }
                }.stroke(Color.watchMint.opacity(dimmed ? 0.5 : 1), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                if let point = WatchObservation.point(in: event, at: date), point.sunlit {
                    Circle().fill(.white).frame(width: 8, height: 8).position(position(point, size: geometry.size))
                }
            }
            HStack {
                Text(SkyEvent.direction(event.points.first?.azimuth ?? event.azimuth))
                Spacer()
                Text(SkyEvent.direction(event.points.last?.azimuth ?? event.azimuth))
            }.font(.caption2).foregroundStyle(.secondary)
        }.accessibilityElement(children: .ignore).accessibilityLabel("ISS visible path from \(SkyEvent.direction(event.points.first?.azimuth ?? event.azimuth)) to \(SkyEvent.direction(event.points.last?.azimuth ?? event.azimuth))")
    }
}
