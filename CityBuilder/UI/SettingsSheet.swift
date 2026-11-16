import CityCore
import SwiftUI

/// Settings sheet for adjusting tax rate, inspecting 24-month cashflow history, and resetting the city.
struct SettingsSheet: View {
    @ObservedObject var controller: GameController
    @Environment(\.dismiss) private var dismiss
    @State private var confirmNewCity = false

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.taxSectionTitle) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(L10n.taxSectionTitle)
                            Spacer()
                            Text("\(controller.taxRate)%")
                                .font(.headline.monospacedDigit())
                        }
                        Slider(
                            value: Binding(
                                get: { Double(controller.taxRate) },
                                set: { controller.taxRate = Int($0.rounded()) }
                            ),
                            in: Double(Balance.minTaxRate)...Double(Balance.maxTaxRate),
                            step: 1
                        )
                    }
                }

                Section(L10n.budgetSectionTitle) {
                    budgetRow(title: L10n.incomeLabel, amount: controller.monthlyBudget.income, color: .green)
                    budgetRow(title: L10n.expensesLabel, amount: -controller.monthlyBudget.expenses, color: .red)
                    budgetRow(
                        title: L10n.netLabel,
                        amount: controller.monthlyBudget.net,
                        color: controller.monthlyBudget.net >= 0 ? .primary : .red
                    )
                }

                Section(L10n.chartSectionTitle) {
                    if controller.history.isEmpty {
                        Text(L10n.noHistoryYet)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        BudgetHistoryChart(records: controller.history)
                            .frame(height: 150)
                            .padding(.vertical, 4)
                    }
                }

                Section(L10n.cityActionsTitle) {
                    Button {
                        controller.save(showFeedback: true)
                        dismiss()
                    } label: {
                        Label(L10n.saveNowLabel, systemImage: "square.and.arrow.down")
                    }

                    Button {
                        controller.returnToStartMenu()
                        dismiss()
                    } label: {
                        Label(L10n.backToStartLabel, systemImage: "house")
                    }

                    Button(role: .destructive) {
                        confirmNewCity = true
                    } label: {
                        Label(L10n.newCityConfirmAction, systemImage: "arrow.counterclockwise")
                    }
                }

                Section(L10n.aboutSectionTitle) {
                    Text(L10n.aboutDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(L10n.settingsTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.closeLabel) {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                L10n.newCityConfirmTitle,
                isPresented: $confirmNewCity,
                titleVisibility: .visible
            ) {
                Button(L10n.newCityConfirmAction, role: .destructive) {
                    controller.newCity(
                        name: L10n.defaultCityName,
                        seed: UInt64.random(in: 1...999_999)
                    )
                    dismiss()
                }
                Button(L10n.cancelLabel, role: .cancel) {}
            } message: {
                Text(L10n.newCityConfirmMessage)
            }
        }
    }

    private func budgetRow(title: String, amount: Int, color: Color) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(amount >= 0 ? "+$\(amount.formatted())" : "-$\(abs(amount).formatted())")
                .font(.body.monospacedDigit())
                .foregroundStyle(color)
        }
    }
}

/// Custom SwiftUI Path dual-line chart comparing monthly income and expenses over up to 24 months.
private struct BudgetHistoryChart: View {
    let records: [MonthRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                let maxVal = max(
                    100,
                    records.flatMap { [$0.income, $0.expenses] }.max() ?? 100
                )
                let width = geo.size.width
                let height = geo.size.height

                ZStack {
                    // Baseline grid lines
                    Path { path in
                        for fraction in [0.0, 0.5, 1.0] {
                            let y = height * CGFloat(fraction)
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: width, y: y))
                        }
                    }
                    .stroke(Color.primary.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [4]))

                    linePath(values: records.map(\.income), maxVal: maxVal, size: geo.size)
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))

                    linePath(values: records.map(\.expenses), maxVal: maxVal, size: geo.size)
                        .stroke(Color.red, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))

                    if records.count == 1, let first = records.first {
                        let yInc = height * (1 - CGFloat(first.income) / CGFloat(maxVal))
                        let yExp = height * (1 - CGFloat(first.expenses) / CGFloat(maxVal))
                        Circle().fill(Color.green).frame(width: 7, height: 7).position(x: width * 0.5, y: yInc)
                        Circle().fill(Color.red).frame(width: 7, height: 7).position(x: width * 0.5, y: yExp)
                    }
                }
            }

            HStack(spacing: 14) {
                legendDot(color: .green, label: L10n.incomeLabel)
                legendDot(color: .red, label: L10n.expensesLabel)
                Spacer()
                if let last = records.last {
                    Text("Th \(last.month)/N\(last.year)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func linePath(values: [Int], maxVal: Int, size: CGSize) -> Path {
        Path { path in
            guard values.count >= 2 else { return }
            let stepX = size.width / CGFloat(values.count - 1)
            for (idx, val) in values.enumerated() {
                let x = CGFloat(idx) * stepX
                let y = size.height * (1.0 - CGFloat(max(0, val)) / CGFloat(maxVal))
                if idx == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
