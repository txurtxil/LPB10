// LmBatteryWidget.swift - Widget de pantalla de inicio para iOS (v161).
//
// Espejo del BatteryWidgetProvider de Android: lee las mismas claves que la
// app escribe via home_widget (soc, range, realRange, cycleKm, locked,
// updated, charging, lastCharge, chartText) del UserDefaults del App Group
// compartido. Sin pods ni home_widget en la extension: UserDefaults puro.
//
// La app fuerza la recarga (HomeWidget.updateWidget -> WidgetCenter
// .reloadTimelines) cada vez que escribe datos nuevos, asi que la timeline
// es .never: no hay calendario propio ni sorpresas de bateria.
//
// Compatible iOS 14+: nada de containerBackground (iOS 17) ni AppIntents.
// El toque abre la app via widgetURL con el esquema lmb10:// declarado en
// Runner/Info.plist.

import WidgetKit
import SwiftUI

private let kAppGroup = "group.com.txurtxil.lpb10"

struct LmEntry: TimelineEntry {
    let date: Date
    let soc: String
    let quedan: String
    let recorrido: String
    let lock: String
    let charge: String?
    let updated: String
    let chart: String?
}

struct LmProvider: TimelineProvider {
    func placeholder(in context: Context) -> LmEntry {
        LmEntry(date: Date(), soc: "62%", quedan: "Quedan: 280 km",
                recorrido: "Recorrido: 45 km desde la carga", lock: "Cerrado",
                charge: nil, updated: "Actualizado 12:30", chart: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (LmEntry) -> Void) {
        completion(load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LmEntry>) -> Void) {
        completion(Timeline(entries: [load()], policy: .never))
    }

    private func load() -> LmEntry {
        let p = UserDefaults(suiteName: kAppGroup)
        func str(_ k: String) -> String? { p?.string(forKey: k) }

        // Linea 1: lo que QUEDA (autonomia). Linea 2: lo RECORRIDO (ciclo).
        // Mismo criterio que el widget de Android: mezclarlos parecia
        // contradictorio porque miden cosas distintas.
        var quedan = "Quedan: -- km"
        if let r = str("range"), !r.isEmpty {
            if let real = str("realRange"), !real.isEmpty {
                quedan = "Quedan: \(r) km (real ~\(real))"
            } else {
                quedan = "Quedan: \(r) km"
            }
        }
        var recorrido = "Recorrido: -- km"
        if str("cycleKm") == "pocos datos" {
            recorrido = "Recorrido: -- (pocos datos)"
        } else if let c = str("cycleKm"), !c.isEmpty {
            recorrido = "Recorrido: \(c) km desde la carga"
        }

        let lock: String
        switch str("locked") {
        case "1": lock = "Cerrado"
        case "0": lock = "Abierto"
        default: lock = "Estado desconocido"
        }

        var charge: String? = nil
        if str("charging") == "1" {
            charge = "\u{26A1} Cargando..."
        } else if let lc = str("lastCharge"), !lc.isEmpty {
            charge = "\u{26A1} \(lc)"
        }

        let chartRaw = str("chartText") ?? ""
        return LmEntry(
            date: Date(),
            soc: (str("soc") ?? "--") + "%",
            quedan: quedan,
            recorrido: recorrido,
            lock: lock,
            charge: charge,
            updated: str("updated") ?? "",
            chart: chartRaw.isEmpty ? nil : chartRaw)
    }
}

struct LmWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: LmEntry

    // Misma paleta que el widget de Android: fondo #BFE0FA, texto #0D3B66,
    // carga #1B7A4B.
    private let azul = Color(red: 13 / 255, green: 59 / 255, blue: 102 / 255)
    private let verde = Color(red: 27 / 255, green: 122 / 255, blue: 75 / 255)

    var body: some View {
        ZStack {
            Color(red: 191 / 255, green: 224 / 255, blue: 250 / 255)
            VStack(alignment: .leading, spacing: 2) {
                Text("Leapmotor")
                    .font(.system(size: 13, weight: .bold))
                Text(entry.soc)
                    .font(.system(size: 26, weight: .bold))
                Text(entry.quedan)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if family != .systemSmall {
                    Text(entry.recorrido)
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(entry.lock)
                        .font(.system(size: 12))
                    if let charge = entry.charge {
                        Text(charge)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(verde)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                if family == .systemLarge, let chart = entry.chart {
                    Text(chart)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(.top, 4)
                }
                Spacer(minLength: 0)
                if family != .systemSmall, !entry.updated.isEmpty {
                    Text(entry.updated)
                        .font(.system(size: 10))
                }
            }
            .foregroundColor(azul)
            .padding(12)
        }
        .widgetURL(URL(string: "lmb10://widget"))
    }
}

struct LmBatteryWidget: Widget {
    var body: some WidgetConfiguration {
        // El kind debe coincidir con _kIosWidgetName de widget_bridge.dart.
        StaticConfiguration(kind: "LmBatteryWidget", provider: LmProvider()) { entry in
            LmWidgetView(entry: entry)
        }
        .configurationDisplayName("LMB10 Bateria")
        .description("Bateria, autonomia y estado del coche.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct LmBatteryWidgetBundle: WidgetBundle {
    var body: some Widget {
        LmBatteryWidget()
    }
}
