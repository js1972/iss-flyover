import SwiftUI
import Combine

struct SkyChartScreen: View {
    @EnvironmentObject var model: AppModel
    @State private var rotation = 0.0
    @State private var dragStart = 0.0
    @State private var offset = 0.0
    @State private var timeAnchor = Date()
    @State private var chartTask: Task<Void, Never>?
    let ticker = Timer.publish(every: 15, on: .main, in: .common).autoconnect()
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(model.selectedEvent?.title ?? (model.previewTime == nil ? "Your sky now" : "Sky preview")).font(.title2.bold())
                            Text("\(model.location.name) · \(model.location.day(model.previewTime ?? Date())) · \(model.location.time(model.previewTime ?? Date()))").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { model.toggleCompass() } label: { Image(systemName: model.compass ? "location.north.circle.fill" : "location.north.circle").font(.title) }.accessibilityLabel(model.compass ? "Turn compass off" : "Align with compass")
                    }
                    SkyPlot(objects: model.chart, path: model.selectedEvent?.points ?? [], rotation: model.compass ? -model.heading : rotation, selected: model.selectedEvent?.body)
                        .aspectRatio(1, contentMode: .fit)
                        .gesture(DragGesture().onChanged { value in if !model.compass { rotation = dragStart + Double(value.translation.width) * 0.5 } }.onEnded { _ in dragStart = rotation })
                        .accessibilityLabel("Sky chart. \(model.chart.map { "\($0.name), \(SkyEvent.direction($0.azimuth)), \(Int($0.elevation)) degrees" }.joined(separator: ". "))")
                    HStack { Label("Horizon at the edge", systemImage: "circle"); Spacer(); Text("Overhead at centre") }.font(.caption).foregroundStyle(.secondary)
                    if model.compass { Text("Compass aligned · heading \(Int(model.heading))°").font(.caption).foregroundStyle(Color.skyMint) }
                    else { Text("Drag to rotate. Use the compass outside, away from magnetic interference.").font(.caption).foregroundStyle(.secondary) }
                    VStack(alignment: .leading, spacing: 12) {
                        HStack { Text("Explore time").font(.headline); Spacer(); if model.previewTime != nil { Button("Return to Live") { timeAnchor = Date(); offset = 0; model.live() }.accessibilityIdentifier("returnLive") } }
                        Slider(value: Binding(get: { offset }, set: { value in
                            offset = value
                            chartTask?.cancel()
                            model.selectedEvent = nil; model.previewTime = timeAnchor.addingTimeInterval(value * 3600)
                            chartTask = Task { try? await Task.sleep(for: .milliseconds(100)); if !Task.isCancelled { await model.updateChart() } }
                        }), in: -6...24, step: 0.25) { Text("Hours from the selected viewing time") }.accessibilityIdentifier("skyTimeSlider")
                    }.skyPanel()
                    if let event = model.selectedEvent { EventRow(event: event) }
                    VStack(alignment: .leading, spacing: 14) {
                        Text("ABOVE THE HORIZON").font(.caption.weight(.bold)).tracking(1).foregroundStyle(Color.skyMint)
                        ForEach(model.chart.filter { $0.kind == "planet" || $0.kind == "moon" || $0.kind == "iss" }) { object in
                            HStack { Text(object.name); Spacer(); Text("\(SkyEvent.direction(object.azimuth)) · \(Int(object.elevation))°").foregroundStyle(.secondary) }.font(.subheadline)
                        }
                        Text("Above the horizon does not guarantee visibility: daylight, cloud and local obstructions matter.").font(.caption).foregroundStyle(.secondary)
                    }.skyPanel()
                }.padding(20).frame(maxWidth: 700)
            }.background(Color.skyBase).navigationTitle("Sky").navigationBarTitleDisplayMode(.inline)
                .task { timeAnchor = model.previewTime ?? Date(); offset = 0; await model.updateChart() }
                .onChange(of: model.selectedEvent?.id) { _, value in if value != nil { timeAnchor = model.previewTime ?? Date(); offset = 0 } }
                .onDisappear { if model.compass { model.toggleCompass() } }
                .onReceive(ticker) { _ in if model.previewTime == nil && model.selectedTab == 1 { Task { await model.updateChart() } } }
        }
    }
}
struct SkyPlot: View {
    var objects: [ChartObject]
    var path: [SkyPoint]
    var rotation: Double
    var selected: String?
    var body: some View {
        Canvas { context, size in
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 24
            func point(_ az: Double, _ elevation: Double) -> CGPoint {
                let r = radius * (90 - max(0, min(90, elevation))) / 90
                let a = (az + rotation) * .pi / 180
                return CGPoint(x: centre.x + sin(a) * r, y: centre.y - cos(a) * r)
            }
            for fraction in [1.0, 0.6667, 0.3333] {
                let r = radius * fraction
                context.stroke(Path(ellipseIn: CGRect(x: centre.x-r, y: centre.y-r, width: r*2, height: r*2)), with: .color(.white.opacity(fraction == 1 ? 0.3 : 0.1)), lineWidth: 1)
            }
            for (i, name) in ["N", "E", "S", "W"].enumerated() {
                let a = (Double(i) * 90 + rotation) * .pi / 180
                let p = CGPoint(x: centre.x + sin(a) * (radius+14), y: centre.y - cos(a) * (radius+14))
                context.draw(Text(name).font(.caption.bold()).foregroundStyle(.secondary), at: p)
            }
            if path.count > 1 {
                var line = Path()
                for (index, p) in path.enumerated() { let xy = point(p.azimuth,p.elevation); if index == 0 { line.move(to: xy) } else { line.addLine(to: xy) } }
                context.stroke(line, with: .color(.skyMint.opacity(0.8)), style: StrokeStyle(lineWidth: 2, dash: [5,3]))
            }
            var labels: [CGRect] = []
            let ordered = objects.sorted { a, b in
                func priority(_ x: ChartObject) -> Int { x.name == selected ? 0 : x.kind == "planet" || x.kind == "moon" || x.kind == "iss" ? 1 : 2 }
                return priority(a) < priority(b)
            }
            for object in ordered {
                let p = point(object.azimuth, object.elevation)
                let prominent = object.kind != "star" || object.name == selected
                let r: Double = object.kind == "moon" ? 6 : prominent ? 4 : 2
                let color: Color = object.kind == "iss" ? .skyMint : object.kind == "planet" ? .yellow : .white
                context.fill(Path(ellipseIn: CGRect(x: p.x-r,y:p.y-r,width:2*r,height:2*r)), with: .color(color.opacity(prominent ? 1 : 0.6)))
                if prominent {
                    let label = Text(object.name).font(.caption2.weight(object.name == selected ? .bold : .regular)).foregroundStyle(color)
                    let resolved = context.resolve(label)
                    let measured = resolved.measure(in: CGSize(width: size.width - 32, height: 40))
                    for dy in [16.0, -16.0, 30.0, -30.0] {
                        let x = min(size.width - measured.width/2 - 8, max(measured.width/2 + 8, p.x))
                        let y = min(size.height - measured.height/2 - 8, max(measured.height/2 + 8, p.y + dy))
                        let box = CGRect(x: x-measured.width/2-3, y: y-measured.height/2-2, width: measured.width+6, height: measured.height+4)
                        if !labels.contains(where: { $0.intersects(box) }) {
                            context.draw(resolved, at: CGPoint(x:x,y:y)); labels.append(box); break
                        }
                    }
                }
            }
        }.background(RadialGradient(colors: [Color(red:0.1,green:0.17,blue:0.28), .skyBase], center: .center, startRadius: 1, endRadius: 230), in: Circle())
    }
}
