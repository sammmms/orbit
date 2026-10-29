import SwiftUI
import AppKit

public struct ClipboardHistoryView: View {
    @ObservedObject var manager: ClipboardHistoryManager = .shared
    public var onSelect: (ClipboardEntry) -> Void
    public var onClose: () -> Void

    @State private var search: String = ""
    @State private var hoveredIndex: Int? = nil
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool {
        if let match = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) {
            return match == .darkAqua
        }
        return colorScheme == .dark
    }

    private var filteredEntries: [ClipboardEntry] {
        if search.trimmingCharacters(in: .whitespaces).isEmpty {
            return manager.entries
        }
        return manager.entries.filter { $0.text.localizedCaseInsensitiveContains(search) }
    }

    public init(
        onSelect: @escaping (ClipboardEntry) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.onSelect = onSelect
        self.onClose = onClose
    }

    public var body: some View {
        ZStack {
            // Glass background
            VisualEffectBlur(
                material: .popover,
                blendingMode: .behindWindow,
                state: .active,
                appearance: NSAppearance(named: isDark ? .vibrantDark : .vibrantLight)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isDark ? Color.white.opacity(0.15) : Color.black.opacity(0.1), lineWidth: 1)

            VStack(spacing: 10) {
                // Header
                HStack {
                    Image(systemName: "list.clipboard.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.purple)

                    Text("Clipboard History")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(isDark ? .white : .primary)

                    Spacer()

                    Text("\(manager.entries.count) items")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)

                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)

                // Search field
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11))
                    TextField("Search copied snippets...", text: $search)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                .cornerRadius(8)
                .padding(.horizontal, 14)

                // List
                if filteredEntries.isEmpty {
                    VStack(spacing: 6) {
                        Spacer()
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("No clipboard history yet")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        Text("Copy text anywhere to populate history")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.7))
                        Spacer()
                    }
                } else {
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 4) {
                            ForEach(Array(filteredEntries.prefix(15).enumerated()), id: \.element.id) { index, entry in
                                clipboardRow(index: index, entry: entry)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, 10)
                    }
                }
            }
        }
        .frame(width: 380, height: 400)
        .shadow(color: Color.black.opacity(0.35), radius: 30, x: 0, y: 15)
    }

    @ViewBuilder
    private func clipboardRow(index: Int, entry: ClipboardEntry) -> some View {
        let isHovered = (hoveredIndex == index)
        let rowContent = Button(action: {
            onSelect(entry)
        }) {
            HStack(spacing: 8) {
                if index < 9 {
                    Text("\(index + 1)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(isHovered ? .white : .secondary)
                        .frame(width: 18, height: 18)
                        .background(isHovered ? Color.purple : (isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)))
                        .cornerRadius(4)
                } else {
                    Spacer().frame(width: 18)
                }

                Text(entry.preview)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(isDark ? .white.opacity(0.95) : .primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer()

                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(isHovered ? .purple : .secondary.opacity(0.35))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isHovered
                    ? (isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.08))
                    : Color.clear
            )
            .cornerRadius(8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { h in
            hoveredIndex = h ? index : (hoveredIndex == index ? nil : hoveredIndex)
        }

        if index < 9 {
            rowContent.keyboardShortcut(KeyEquivalent(Character(UnicodeScalar(49 + index)!)), modifiers: [])
        } else {
            rowContent
        }
    }
}
