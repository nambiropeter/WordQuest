import SwiftUI
import UIKit

struct WordSearchGridView: View {
    @ObservedObject var vm: WordSearchViewModel

    var body: some View {
        GeometryReader { geo in
            let gridSize = vm.puzzle.gridSize
            let side = min(geo.size.width, geo.size.height)
            let cellSize = side / CGFloat(gridSize)
            let theme = vm.puzzle.theme

            ZStack(alignment: .topLeading) {
                ForEach(Array(vm.foundPaths.enumerated()), id: \.offset) { _, path in
                    lineShape(path: path, cellSize: cellSize, color: theme.primaryColor.opacity(0.4))
                        .accessibilityHidden(true)
                }

                if vm.currentSelection.count > 1 {
                    lineShape(path: vm.currentSelection, cellSize: cellSize, color: theme.secondaryColor.opacity(0.5))
                        .accessibilityHidden(true)
                }

                ForEach(0..<gridSize, id: \.self) { row in
                    ForEach(0..<gridSize, id: \.self) { col in
                        letterCell(row: row, col: col, cellSize: cellSize)
                    }
                }
            }
            .frame(width: side, height: side)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        let pos = gridPosition(for: value.location, cellSize: cellSize, gridSize: gridSize)
                        if vm.currentSelection.isEmpty {
                            vm.beginSelection(at: pos)
                        } else {
                            vm.updateSelection(to: pos)
                        }
                    }
                    .onEnded { _ in vm.endSelection() }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func letterCell(row: Int, col: Int, cellSize: CGFloat) -> some View {
        let pos = GridPosition(row: row, col: col)
        let letter: String = String(vm.puzzle.letters[row][col])
        let fontSize: CGFloat = cellSize * 0.46
        let highlightColor: Color = vm.hintedPosition == pos ? vm.puzzle.theme.primaryColor.opacity(0.55) : Color.clear
        let centerX: CGFloat = CGFloat(col) * cellSize + cellSize / 2
        let centerY: CGFloat = CGFloat(row) * cellSize + cellSize / 2

        let label = Text(letter)
            .font(.system(size: fontSize, weight: .bold, design: .rounded))
            .foregroundStyle(.primary)
            .frame(width: cellSize, height: cellSize)

        let withBackground = label.background(Circle().fill(highlightColor))

        return withBackground
            .position(x: centerX, y: centerY)
            .animation(.easeInOut(duration: 0.2), value: vm.hintedPosition)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Row \(row + 1), column \(col + 1): \(letter)")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                selectViaVoiceOver(pos)
            }
    }

    /// VoiceOver intercepts raw touches, so the drag gesture below is
    /// unreachable while it's running — this two-tap equivalent (accessible
    /// via double-tap on each focused cell) is how the grid stays playable
    /// for VoiceOver users: tap a starting letter, then tap the ending one.
    private func selectViaVoiceOver(_ position: GridPosition) {
        if vm.currentSelection.isEmpty {
            vm.beginSelection(at: position)
            UIAccessibility.post(notification: .announcement, argument: "Selection started")
        } else {
            vm.updateSelection(to: position)
            vm.endSelection()
            UIAccessibility.post(
                notification: .announcement,
                argument: vm.lastFoundWasCorrect == true ? "Word found" : "Not a match, try again"
            )
        }
    }

    private func gridPosition(for point: CGPoint, cellSize: CGFloat, gridSize: Int) -> GridPosition {
        let col = min(max(Int(point.x / cellSize), 0), gridSize - 1)
        let row = min(max(Int(point.y / cellSize), 0), gridSize - 1)
        return GridPosition(row: row, col: col)
    }

    private func lineShape(path: [GridPosition], cellSize: CGFloat, color: Color) -> some View {
        guard let first = path.first, let last = path.last else {
            return AnyView(EmptyView())
        }
        let x1 = CGFloat(first.col) * cellSize + cellSize / 2
        let y1 = CGFloat(first.row) * cellSize + cellSize / 2
        let x2 = CGFloat(last.col) * cellSize + cellSize / 2
        let y2 = CGFloat(last.row) * cellSize + cellSize / 2
        let length = hypot(x2 - x1, y2 - y1) + cellSize
        let angle = atan2(y2 - y1, x2 - x1)

        return AnyView(
            Capsule()
                .fill(color)
                .frame(width: length, height: cellSize * 0.78)
                .rotationEffect(.radians(angle))
                .position(x: (x1 + x2) / 2, y: (y1 + y2) / 2)
        )
    }
}
