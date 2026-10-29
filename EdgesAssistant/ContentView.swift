import SwiftUI

struct ContentView: View {
    @StateObject private var model = AskModel()
    @FocusState private var questionFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    questionField
                    actions
                    status
                    result
                    serverSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 28)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Edges 小助手")
            .navigationBarTitleDisplayMode(.large)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("提问", action: submit)
                        .disabled(!model.canAsk)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("索引 VirusPC/edges 框架仓，公开可问")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("可直接向 Edges 小助手提问。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var questionField: some View {
        TextField("输入问题", text: $model.question, axis: .vertical)
            .lineLimit(3...8)
            .focused($questionFocused)
            .textFieldStyle(.plain)
            .padding(14)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
    }

    private var actions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                askButton
                sampleButton
            }
            VStack(spacing: 12) {
                askButton
                sampleButton
            }
        }
    }

    private var askButton: some View {
        Button(action: submit) {
            Text("提问")
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!model.canAsk)
    }

    private var sampleButton: some View {
        Button(action: showSample) {
            Text("看示例回答")
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    @ViewBuilder
    private var status: some View {
        if model.isLoading {
            HStack(spacing: 10) {
                ProgressView()
                Text("正在提问…")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        } else if let message = model.errorMessage {
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.red)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
        }
    }

    @ViewBuilder
    private var result: some View {
        if model.answer == nil && !model.isLoading && model.errorMessage == nil {
            Text("提问后，回答和引用会显示在这里。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if model.answer != nil {
            VStack(alignment: .leading, spacing: 16) {
                if model.isSample {
                    Text("本地示例，没有请求服务器。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("回答")
                        .font(.headline)
                    Text(displayAnswer)
                        .font(.body)
                        .lineSpacing(4)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(
                            Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(citationHeading)
                        .font(.headline)
                    if model.citations.isEmpty {
                        Text("这次回答没有引用。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.citations) { citation in
                            citationCard(citation)
                        }
                    }
                }
            }
        }
    }

    private var displayAnswer: String {
        let text = model.answer?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? "（没有文字回答）" : text
    }

    private var citationHeading: String {
        model.citations.isEmpty ? "引用" : "引用 · \(model.citations.count)"
    }

    private func citationCard(_ citation: Citation) -> some View {
        let score = citation.score.formatted(
            .number
                .precision(.fractionLength(3))
                .locale(Locale(identifier: "en_US_POSIX"))
        )
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(citation.path)
                    .font(.caption.monospaced())
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("相关度 \(score)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .layoutPriority(1)
            }
            Text(citation.snippet)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }

    private var serverSection: some View {
        DisclosureGroup("接口地址") {
            VStack(alignment: .leading, spacing: 8) {
                TextField(APIConfig.defaultBaseURL, text: baseBinding)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .font(.footnote.monospaced())
                    .padding(12)
                    .background(
                        Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                Text("将请求 \(AskClient.describeEndpoint(base: model.baseURL))")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("默认是公网 HTTPS。要改走 Tailscale，把这里换成当时的内网入口，不要带 /api/ask。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("恢复默认", action: model.restoreDefaultBaseURL)
                    .font(.subheadline)
                    .disabled(model.baseURL.trimmingCharacters(in: .whitespacesAndNewlines) == APIConfig.defaultBaseURL)
            }
            .padding(.top, 8)
        }
        .font(.subheadline)
        .padding(.top, 4)
    }

    private var baseBinding: Binding<String> {
        Binding(
            get: { model.baseURL },
            set: { model.updateBaseURL($0) }
        )
    }

    private func submit() {
        questionFocused = false
        model.ask()
    }

    private func showSample() {
        questionFocused = false
        model.showSample()
    }
}

#Preview {
    ContentView()
}
