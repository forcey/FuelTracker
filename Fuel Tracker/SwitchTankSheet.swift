import SwiftUI

struct SwitchTankSheet: View {
    let toIndex: Int
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: FuelViewModel
    @State private var usedInput: String = ""
    @State private var selection: TextSelection? = nil
    @FocusState private var isInputFocused: Bool

    private var fromTank: Tank? {
        viewModel.lastActiveTankIndex.map { viewModel.tanks[$0] }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                if let from = fromTank {
                    Text("From \(from.name)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Text("Switch to")
                    Text(viewModel.tanks[toIndex].name)
                        .foregroundStyle(Color.accentColor)
                }
                .font(.title.weight(.semibold))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Total used on totalizer")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    TextField("Gallons", text: $usedInput, selection: $selection)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 40, weight: .light))
                        .monospacedDigit()
                        .focused($isInputFocused)
                    Text("gal")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 18)
                .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.accentColor, lineWidth: 2))
            }

            // Preview what the switch will subtract from the tank we're leaving.
            if let from = fromTank, let used = Double(usedInput) {
                let burned = used - (viewModel.totalUsedGallons ?? 0)
                HStack {
                    Text("\(from.name) burned \(String(format: "%.1f", burned)) gal")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(String(format: "%.1f", from.gallons)) → \(String(format: "%.1f", max(from.gallons - burned, 0))) left")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .monospacedDigit()
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            }

            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Text("Cancel").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    if let usedVal = Double(usedInput) {
                        viewModel.switchToTank(at: toIndex, newTotalUsed: usedVal)
                    }
                    dismiss()
                } label: {
                    Text("Switch").fontWeight(.semibold).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(Double(usedInput) == nil)
            }
            .controlSize(.large)
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(.secondarySystemGroupedBackground))
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            usedInput = String(format: "%.1f", (viewModel.totalUsedGallons ?? -5) + 5)
            isInputFocused = true
        }
        .onChange(of: isInputFocused) { _, focused in
            guard focused else { return }
            // Select the suggestion so typing replaces it. Wait for the field
            // to finish taking focus, or it puts the cursor at the end.
            DispatchQueue.main.async {
                selection = TextSelection(range: usedInput.startIndex..<usedInput.endIndex)
            }
        }
    }
}
