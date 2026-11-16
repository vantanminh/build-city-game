import CityCore
import SwiftUI

/// Horizontal scrollable build toolbar showing all city tools and their costs.
struct ToolbarView: View {
    @Binding var selectedTool: Tool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Tool.allCases, id: \.self) { tool in
                    toolButton(for: tool)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        )
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
    }

    private func toolButton(for tool: Tool) -> some View {
        let isSelected = selectedTool == tool
        let tint = tintColor(for: tool)

        return Button {
            selectedTool = tool
        } label: {
            VStack(spacing: 4) {
                Image(systemName: symbolName(for: tool))
                    .font(.system(size: 18, weight: .semibold))
                    .frame(height: 22)
                Text(L10n.toolName(tool))
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                Text(costLabel(for: tool))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(isSelected ? .white.opacity(0.92) : .secondary)
            }
            .foregroundStyle(isSelected ? Color.white : tint)
            .frame(minWidth: 64)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? tint : Color.primary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.white.opacity(0.55) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func costLabel(for tool: Tool) -> String {
        tool.cost > 0 ? "$\(tool.cost)" : L10n.freeLabel
    }

    private func symbolName(for tool: Tool) -> String {
        switch tool {
        case .inspect: return "hand.point.up"
        case .road: return "road.lanes"
        case .residential: return "house.fill"
        case .commercial: return "cart.fill"
        case .industrial: return "building.2.fill"
        case .park: return "tree.fill"
        case .powerPlant: return "bolt.fill"
        case .school: return "graduationcap.fill"
        case .hospital: return "cross.case.fill"
        case .bulldoze: return "hammer.fill"
        }
    }

    private func tintColor(for tool: Tool) -> Color {
        switch tool {
        case .inspect: return .blue
        case .road: return .gray
        case .residential: return .green
        case .commercial: return .indigo
        case .industrial: return .orange
        case .park: return .mint
        case .powerPlant: return Color(red: 0.84, green: 0.58, blue: 0.02)
        case .school: return .teal
        case .hospital: return .pink
        case .bulldoze: return .red
        }
    }
}
