import ActivityKit
import WidgetKit
import SwiftUI

struct TriviaLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TriviaActivityAttributes.self) { context in
            LockScreenTriviaView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.82))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        ThemeBadge(attributes: context.attributes, size: 32)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(context.attributes.themeName)
                                .font(.caption.weight(.bold))
                                .lineLimit(1)
                            Text("Level \(context.attributes.level)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(context.state.score)")
                            .font(.title3.weight(.heavy))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                        Text("SCORE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 10) {
                        HStack {
                            Text("Question \(min(context.state.questionIndex + 1, context.state.totalQuestions)) of \(context.state.totalQuestions)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            if context.state.streak > 1 {
                                Label("\(context.state.streak)", systemImage: "flame.fill")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.orange)
                            }
                            CountdownBadge(state: context.state, themeColor: themeColor(context.attributes))
                        }
                        ProgressBar(state: context.state, themeColor: themeColor(context.attributes))
                    }
                }
            } compactLeading: {
                ThemeBadge(attributes: context.attributes, size: 20)
            } compactTrailing: {
                CompactCountdown(state: context.state, themeColor: themeColor(context.attributes))
            } minimal: {
                ThemeBadge(attributes: context.attributes, size: 18)
            }
            .widgetURL(URL(string: "wordquest://trivia"))
            .keylineTint(themeColor(context.attributes))
        }
    }

    private func themeColor(_ attrs: TriviaActivityAttributes) -> Color {
        Color(hex: attrs.themeColorPrimaryHex)
    }
}

private struct ThemeBadge: View {
    let attributes: TriviaActivityAttributes
    let size: CGFloat

    var body: some View {
        Image(systemName: attributes.themeIcon)
            .font(.system(size: size * 0.55))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(
                    colors: [Color(hex: attributes.themeColorPrimaryHex), Color(hex: attributes.themeColorSecondaryHex)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(Circle())
    }
}

/// The centerpiece: a system-rendered live countdown once the question is
/// live, swapping to a static result glyph the instant it's answered.
private struct CountdownBadge: View {
    let state: TriviaActivityAttributes.ContentState
    let themeColor: Color

    var body: some View {
        if state.isAnswered {
            Image(systemName: state.lastAnswerCorrect == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(state.lastAnswerCorrect == true ? .green : .red)
        } else {
            Label {
                Text(timerInterval: Date.now...state.questionDeadline, countsDown: true)
                    .monospacedDigit()
            } icon: {
                Image(systemName: "timer")
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(themeColor)
        }
    }
}

private struct CompactCountdown: View {
    let state: TriviaActivityAttributes.ContentState
    let themeColor: Color

    var body: some View {
        if state.isAnswered {
            Image(systemName: state.lastAnswerCorrect == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(state.lastAnswerCorrect == true ? .green : .red)
        } else {
            Text(timerInterval: Date.now...state.questionDeadline, countsDown: true)
                .font(.caption2.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(themeColor)
                .frame(width: 40)
        }
    }
}

private struct ProgressBar: View {
    let state: TriviaActivityAttributes.ContentState
    let themeColor: Color

    var body: some View {
        if state.isAnswered {
            ProgressView(value: 0)
                .tint(themeColor)
        } else {
            let start = state.questionDeadline.addingTimeInterval(-Double(state.timePerQuestion))
            ProgressView(timerInterval: start...state.questionDeadline, countsDown: true)
                .tint(themeColor)
        }
    }
}

private struct LockScreenTriviaView: View {
    let attributes: TriviaActivityAttributes
    let state: TriviaActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            ThemeBadge(attributes: attributes, size: 48)

            VStack(alignment: .leading, spacing: 6) {
                Text("\(attributes.themeName) · Level \(attributes.level)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)

                ProgressBar(state: state, themeColor: Color(hex: attributes.themeColorPrimaryHex))

                Text("Question \(min(state.questionIndex + 1, state.totalQuestions)) of \(state.totalQuestions)")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            VStack(spacing: 4) {
                Text("\(state.score)")
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                CountdownBadge(state: state, themeColor: Color(hex: attributes.themeColorPrimaryHex))
            }
        }
        .padding(16)
    }
}
